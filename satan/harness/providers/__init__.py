"""Provider registry: dispatch on SATAN_PROVIDER env to a concrete adapter.

Phase-3B ships one adapter (OpenRouter). Phase-3C-lite adds a shared
`OpenAICompatibleProvider` base + DeepSeek as a thin config row.
"""

from __future__ import annotations

import os

from .base import CompletionResult, Provider
from .openrouter import OpenRouterProvider


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


__all__ = [
    "CompletionResult",
    "OpenRouterProvider",
    "Provider",
    "build_provider",
]
