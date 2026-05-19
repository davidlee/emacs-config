"""SATAN gptel harness.

Drives a chat-completions loop against any OpenAI-compatible provider
(OpenRouter v1 by default). Speaks the SATAN JSONL protocol on
stdin/stdout: ready -> 0..N tool_calls (results back on stdin) -> final.

Termination signal from the model is a tool call to `satan_final`
(summary, actions[]). Adapter intercepts and emits the broker's `final`
record.

Env (set by the broker):
  SATAN_RUN_ID, SATAN_RUN_DIR    bind/mount paths inside the jail
  SATAN_PROVIDER                  default 'openrouter'
  SATAN_MODEL                     full provider/model id (e.g. anthropic/claude-haiku-4.5)
  SATAN_BUDGET_TOKENS             cumulative input+output ceiling (int)
  OPENROUTER_API_KEY (or matching var per provider)
"""

from __future__ import annotations

import json
import os
import re
import sys
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any


# === PROTOCOL ============================================================
# Validator for the JSONL membrane. Keep this section in sync with
# ../dl-satan-protocol.el and ../protocol/PROTOCOL.md. Shared fixtures at
# ../protocol/fixtures.json drive both this validator's tests and the
# elisp validator's tests.

TYPES_IN = frozenset({"ready", "log", "tool_call", "final", "error"})
TYPES_OUT = frozenset({"tool_result"})
TOOL_NAME_RE = re.compile(r"\A[a-zA-Z0-9_-]+\Z")


class ProtocolError(Exception):
    def __init__(self, type_: str | None, reason: str):
        self.type = type_
        self.reason = reason
        super().__init__(f"{type_}: {reason}" if type_ else reason)


def _require_string(obj: dict, key: str) -> str | None:
    if key not in obj:
        return f"missing required field: {key}"
    if not isinstance(obj[key], str):
        return f"field {key} must be string"
    return None


def _require_bool(obj: dict, key: str) -> str | None:
    if key not in obj:
        return f"missing required field: {key}"
    if not isinstance(obj[key], bool):
        return f"field {key} must be boolean"
    return None


def _validate_action(a: Any) -> str | None:
    if not isinstance(a, dict):
        return "action must be object"
    if "type" not in a:
        return "action missing type"
    if not isinstance(a["type"], str):
        return "action type must be string"
    return None


def _validate_ready(obj: dict) -> str | None:
    return _require_string(obj, "run_id")


def _validate_log(obj: dict) -> str | None:
    return _require_string(obj, "kind")


def _validate_tool_call(obj: dict) -> str | None:
    e = _require_string(obj, "id") or _require_string(obj, "name")
    if e:
        return e
    if not TOOL_NAME_RE.match(obj["name"]):
        return "field name must match ^[a-zA-Z0-9_-]+$"
    if "args" not in obj:
        return "missing required field: args"
    if not isinstance(obj["args"], dict):
        return "field args must be object"
    return None


def _validate_final(obj: dict) -> str | None:
    e = _require_string(obj, "summary")
    if e:
        return e
    if "actions" not in obj:
        return "missing required field: actions"
    if not isinstance(obj["actions"], list):
        return "field actions must be array"
    for a in obj["actions"]:
        e = _validate_action(a)
        if e:
            return e
    if "reason" in obj and not isinstance(obj["reason"], str):
        return "field reason must be string"
    return None


def _validate_error(obj: dict) -> str | None:
    return _require_string(obj, "error")


def _validate_tool_result(obj: dict) -> str | None:
    e = _require_string(obj, "id") or _require_bool(obj, "ok")
    if e:
        return e
    if obj["ok"] and "result" not in obj:
        return "ok=true requires result"
    if not obj["ok"] and "error" not in obj:
        return "ok=false requires error"
    return None


_DISPATCH = {
    "ready": _validate_ready,
    "log": _validate_log,
    "tool_call": _validate_tool_call,
    "final": _validate_final,
    "error": _validate_error,
    "tool_result": _validate_tool_result,
}


def check(direction: str, obj: dict) -> str | None:
    """Return None on valid, or a reason string on invalid."""
    if direction not in ("in", "out"):
        raise ValueError(f"bad direction: {direction!r}")
    allowed = TYPES_IN if direction == "in" else TYPES_OUT
    if not isinstance(obj, dict):
        return "message must be object"
    if "type" not in obj:
        return "missing required field: type"
    t = obj["type"]
    if not isinstance(t, str):
        return "field type must be string"
    if t not in allowed:
        if t in TYPES_IN or t in TYPES_OUT:
            return f"type {t} not valid for direction {direction}"
        return f"unknown message type: {t}"
    return _DISPATCH[t](obj)


def validate(direction: str, obj: dict) -> None:
    reason = check(direction, obj)
    if reason is not None:
        raise ProtocolError(obj.get("type") if isinstance(obj, dict) else None, reason)


def fixtures_path() -> str:
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.normpath(os.path.join(here, "..", "protocol", "fixtures.json"))


def load_fixtures(path: str | None = None) -> list[dict]:
    with open(path or fixtures_path(), encoding="utf-8") as f:
        return json.load(f)["fixtures"]


# ---- protocol helpers ----

def emit(obj: dict) -> None:
    validate("in", obj)
    print(json.dumps(obj), flush=True)


def emit_ready(run_id: str) -> None:
    emit({"type": "ready", "run_id": run_id})


def emit_log(payload: dict) -> None:
    emit({"type": "log", **payload})


def emit_error(msg: str) -> None:
    emit({"type": "error", "error": msg})


def emit_final(summary: str, actions: list[dict], reason: str | None = None) -> None:
    rec: dict = {"type": "final", "summary": summary, "actions": actions}
    if reason is not None:
        rec["reason"] = reason
    emit(rec)


def emit_tool_call(call_id: str, name: str, args: dict) -> None:
    emit({"type": "tool_call", "id": call_id, "name": name, "args": args})


def read_tool_result() -> dict:
    """Read one JSON line from stdin; broker sends tool_result here."""
    line = sys.stdin.readline()
    if not line:
        raise RuntimeError("stdin closed before tool_result")
    obj = json.loads(line)
    validate("out", obj)
    return obj

# === /PROTOCOL ===========================================================


# ---- provider abstraction ----

@dataclass
class CompletionResult:
    content: str
    tool_calls: list[dict]  # [{"id": str, "name": str, "args": dict}]
    input_tokens: int
    output_tokens: int


class Provider(ABC):
    @abstractmethod
    def complete(
        self,
        messages: list[dict],
        tools: list[dict],
        model: str,
    ) -> CompletionResult: ...


class OpenRouterProvider(Provider):
    """OpenAI v1 chat-completions, base_url=openrouter."""

    def __init__(self, api_key: str):
        try:
            from openai import OpenAI
        except ImportError as e:
            raise RuntimeError(f"openai SDK not installed: {e}") from e
        self._client = OpenAI(
            api_key=api_key,
            base_url="https://openrouter.ai/api/v1",
        )

    def complete(self, messages, tools, model):
        resp = self._client.chat.completions.create(
            model=model,
            messages=messages,
            tools=tools if tools else None,
        )
        choice = resp.choices[0]
        msg = choice.message
        content = msg.content or ""
        tool_calls = []
        for tc in (msg.tool_calls or []):
            try:
                args = json.loads(tc.function.arguments or "{}")
            except json.JSONDecodeError:
                args = {}
            tool_calls.append({
                "id": tc.id,
                "name": tc.function.name,
                "args": args,
            })
        usage = resp.usage
        return CompletionResult(
            content=content,
            tool_calls=tool_calls,
            input_tokens=getattr(usage, "prompt_tokens", 0) or 0,
            output_tokens=getattr(usage, "completion_tokens", 0) or 0,
        )


def build_provider() -> tuple[Provider, str]:
    provider_name = os.environ.get("SATAN_PROVIDER", "openrouter").lower()
    model = os.environ.get("SATAN_MODEL") or ""
    if not model:
        raise RuntimeError("SATAN_MODEL not set")
    if provider_name == "openrouter":
        key = os.environ.get("OPENROUTER_API_KEY")
        if not key:
            raise RuntimeError("OPENROUTER_API_KEY not set")
        return OpenRouterProvider(key), model
    raise RuntimeError(f"unknown SATAN_PROVIDER: {provider_name}")


# ---- tool schemas ----
#
# The broker writes the full OpenAI-tools JSON Schema for every allowed
# tool (plus the synthetic `satan_final`) into manifest.json["tools"].
# The harness consumes that list verbatim — descriptions, parameters,
# and all — so no canonical model-facing text lives in this file.


def build_tools(manifest: dict) -> list[dict]:
    """Return the manifest's tools list, validated minimally."""
    tools = manifest.get("tools")
    if not tools:
        raise RuntimeError("manifest missing 'tools' array")
    return list(tools)


# ---- main loop ----

@dataclass
class RunState:
    messages: list[dict] = field(default_factory=list)
    tokens_in: int = 0
    tokens_out: int = 0

    @property
    def tokens_total(self) -> int:
        return self.tokens_in + self.tokens_out


def load_bundle(run_dir: str) -> dict:
    with open(os.path.join(run_dir, "bundle.json"), encoding="utf-8") as f:
        return json.load(f)


def load_manifest(run_dir: str) -> dict:
    with open(os.path.join(run_dir, "manifest.json"), encoding="utf-8") as f:
        return json.load(f)


def build_system_prompt(bundle: dict) -> str:
    # bundle["prompt"] is the fully-rendered system prompt — scaffold,
    # mode prompt, and every context-section (`# Now`, `# Today (raw)`,
    # `# Source files`) assembled by the broker. The harness consumes
    # it verbatim and adds no model-facing prose.
    return bundle["prompt"]


def append_assistant_with_tools(
    state: RunState,
    content: str,
    tool_calls: list[dict],
) -> None:
    msg: dict[str, Any] = {"role": "assistant", "content": content or None}
    if tool_calls:
        msg["tool_calls"] = [
            {
                "id": tc["id"],
                "type": "function",
                "function": {
                    "name": tc["name"],
                    "arguments": json.dumps(tc["args"]),
                },
            }
            for tc in tool_calls
        ]
    state.messages.append(msg)


def append_tool_result(state: RunState, call_id: str, result: dict) -> None:
    # Result echoed back to the model — pass the whole tool_result payload
    # JSON-serialized; OpenAI tool messages take a single string.
    state.messages.append({
        "role": "tool",
        "tool_call_id": call_id,
        "content": json.dumps(result),
    })


def run() -> int:
    run_id = os.environ.get("SATAN_RUN_ID", "")
    run_dir = os.environ.get("SATAN_RUN_DIR", "")
    budget_tokens = int(os.environ.get("SATAN_BUDGET_TOKENS", "0") or 0)
    if not run_dir:
        emit_error("SATAN_RUN_DIR not set")
        return 1

    try:
        bundle = load_bundle(run_dir)
        manifest = load_manifest(run_dir)
        provider, model = build_provider()
    except Exception as e:
        emit_error(f"init failed: {e}")
        return 1

    try:
        tools = build_tools(manifest)
    except RuntimeError as e:
        emit_error(str(e))
        return 1

    state = RunState()
    state.messages.append({"role": "system", "content": build_system_prompt(bundle)})

    emit_ready(run_id)

    while True:
        try:
            comp = provider.complete(state.messages, tools, model)
        except Exception as e:
            emit_error(f"provider call failed: {e}")
            return 1

        state.tokens_in += comp.input_tokens
        state.tokens_out += comp.output_tokens
        emit_log({
            "kind": "usage",
            "tokens_in": comp.input_tokens,
            "tokens_out": comp.output_tokens,
            "tokens_total": state.tokens_total,
        })

        # Process satan_final first if present — it's terminal.
        for tc in comp.tool_calls:
            if tc["name"] == "satan_final":
                args = tc["args"] or {}
                summary = args.get("summary") or comp.content or ""
                actions = args.get("actions") or []
                emit_final(summary, actions)
                return 0

        if comp.tool_calls:
            append_assistant_with_tools(state, comp.content, comp.tool_calls)
            # Emit each non-final tool_call, read the corresponding result.
            for tc in comp.tool_calls:
                emit_tool_call(tc["id"], tc["name"], tc["args"])
                result = read_tool_result()
                append_tool_result(state, tc["id"], result)
        else:
            # Model returned plain content with no tools — coerce to final.
            emit_final(
                comp.content or "(no summary)",
                [],
                reason="no_tool_calls",
            )
            return 0

        # Budget guard: graceful final after the current turn settles.
        if budget_tokens and state.tokens_total >= budget_tokens:
            # Ask model to wrap up via satan_final on next turn — but
            # since we'd risk another full turn over budget, terminate
            # ourselves with a synthetic final.
            emit_final(
                f"(budget exhausted at {state.tokens_total} tokens)",
                [],
                reason="budget_tokens",
            )
            return 0


def main() -> int:
    try:
        return run()
    except Exception as e:
        emit_error(f"unhandled: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
