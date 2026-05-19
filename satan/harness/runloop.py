"""SATAN harness turn loop.

`run` drives one chat-completions session: assemble the system prompt
from the broker-supplied bundle, then loop until the model emits
`satan_final`, no tools, or the token budget is exhausted.
"""

from __future__ import annotations

import json
import os
from dataclasses import dataclass, field
from typing import Any

from bundle import build_system_prompt, build_tools, load_bundle, load_manifest
from protocol import (
    emit_error,
    emit_final,
    emit_log,
    emit_ready,
    emit_tool_call,
    read_tool_result,
)
from providers import build_provider


@dataclass
class RunState:
    messages: list[dict] = field(default_factory=list)
    tokens_in: int = 0
    tokens_out: int = 0

    @property
    def tokens_total(self) -> int:
        return self.tokens_in + self.tokens_out


def append_assistant_with_tools(
    state: RunState,
    content: str,
    tool_calls: list[dict],
    reasoning_content: str | None = None,
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
    if reasoning_content:
        # DeepSeek thinking-mode round-trip requirement: the reasoning
        # block returned with the assistant turn must be echoed back on
        # the next request or the provider rejects.
        msg["reasoning_content"] = reasoning_content
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

    # Soft budget UX: when state.tokens_total first crosses
    # `budget_tokens`, inject a system nudge asking the model to call
    # `satan_final` next turn and continue. If the next turn does not
    # finalise, force a synthetic final. `warned` carries the state.
    warned = False

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

        # Post-warning turn must finalise. Anything else forces synthetic.
        if warned:
            emit_final(
                f"(budget exhausted at {state.tokens_total} tokens; "
                f"model did not finalise after warning)",
                [],
                reason="budget_tokens",
            )
            return 0

        if comp.tool_calls:
            append_assistant_with_tools(
                state, comp.content, comp.tool_calls,
                reasoning_content=comp.reasoning_content,
            )
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

        # Budget guard: warn + nudge model to wind down on its own.
        if budget_tokens and state.tokens_total >= budget_tokens:
            emit_log({
                "kind": "budget_warning",
                "tokens_total": state.tokens_total,
                "budget_tokens": budget_tokens,
            })
            state.messages.append({
                "role": "system",
                "content": (
                    f"Token budget of {budget_tokens} reached "
                    f"(used {state.tokens_total}). Stop and call "
                    f"`satan_final` on your next turn to wind down."
                ),
            })
            warned = True


def main() -> int:
    try:
        return run()
    except Exception as e:
        emit_error(f"unhandled: {e}")
        return 1
