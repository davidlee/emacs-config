"""OpenRouter provider: OpenAI v1 chat-completions with base_url override."""

from __future__ import annotations

import json

from .base import CompletionResult, Provider


class OpenRouterProvider(Provider):
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
