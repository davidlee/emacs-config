"""Provider abstraction: completion contract + result type.

Adapters implement `Provider.complete`. The runloop is provider-agnostic
once `build_provider` has handed it back an instance.
"""

from __future__ import annotations

from abc import ABC, abstractmethod
from dataclasses import dataclass


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
