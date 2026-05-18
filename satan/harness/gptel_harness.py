"""SATAN gptel harness.

Drives a chat-completions loop against any OpenAI-compatible provider
(OpenRouter v1 by default). Speaks the SATAN JSONL protocol on
stdin/stdout: ready -> 0..N tool_calls (results back on stdin) -> final.

Termination signal from the model is a tool call to `satan.final`
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
import sys
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import Any


# ---- protocol helpers ----

def emit(obj: dict) -> None:
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
    return json.loads(line)


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
# tool (plus the synthetic `satan.final`) into manifest.json["tools"].
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
    # bundle["prompt"] is the fully-assembled system prompt (scaffold +
    # mode prompt) the broker built from ~/notes/satan/. The harness
    # must not add canonical model-facing prose here.
    parts = [bundle.get("prompt", "").rstrip()]
    today = bundle.get("today_text")
    if today:
        parts.append("")
        parts.append("# Today (raw)")
        parts.append(today)
    sources = bundle.get("sources")
    if sources:
        parts.append("")
        parts.append("# Source files")
        for item in sources:
            path = item.get("path", "?")
            content = item.get("content", "")
            parts.append("")
            parts.append(f"## {path}")
            parts.append("```")
            parts.append(content)
            parts.append("```")
    return "\n".join(parts)


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

        # Process satan.final first if present — it's terminal.
        for tc in comp.tool_calls:
            if tc["name"] == "satan.final":
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
            # Ask model to wrap up via satan.final on next turn — but
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
