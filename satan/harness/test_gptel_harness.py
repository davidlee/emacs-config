"""Unit tests for the SATAN gptel harness.

No network. Stub Provider, stub stdin/stdout, verify protocol shape.
Run: cd satan/harness && python -m unittest test_gptel_harness
"""

from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from unittest import mock

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import bundle  # noqa: E402
import protocol  # noqa: E402
import runloop  # noqa: E402
from providers import build_provider  # noqa: E402
from providers.base import CompletionResult, Provider  # noqa: E402
from providers.deepseek import DeepSeekProvider  # noqa: E402
from providers.openrouter import OpenRouterProvider  # noqa: E402


def _stub_tool_schema(name: str, description: str = "") -> dict:
    return {
        "type": "function",
        "function": {
            "name": name,
            "description": description or f"stub {name}",
            "parameters": {"type": "object", "properties": {}, "required": []},
        },
    }


DEFAULT_MANIFEST_TOOLS = [
    _stub_tool_schema("org_read_context"),
    _stub_tool_schema("org_update_owned_block"),
    _stub_tool_schema("satan_final"),
]


def make_bundle(tmp: str, *, tools=None, **overrides) -> str:
    bundle_dict = {
        "prompt": "test prompt",
        "mode": "morning",
        "now": {
            "iso_date": "2026-05-19",
            "weekday": "Tuesday",
            "iso_week": "2026-W21",
            "time": "09:00",
            "tz_offset": "+1000",
            "tz_name": "AEST",
        },
        "today_path": "/satan/notes/today.org",
        "today_text": "",
    }
    bundle_dict.update(overrides)
    with open(os.path.join(tmp, "bundle.json"), "w", encoding="utf-8") as f:
        json.dump(bundle_dict, f)
    manifest = {
        "run_id": "test-run",
        "tools": list(tools) if tools is not None else DEFAULT_MANIFEST_TOOLS,
    }
    with open(os.path.join(tmp, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f)
    return tmp


def emitted_lines(buf: io.StringIO) -> list[dict]:
    return [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]


class StubProvider(Provider):
    def __init__(self, results: list[CompletionResult]):
        self._results = list(results)
        self.calls: list[dict] = []

    def complete(self, messages, tools, model):
        self.calls.append({"messages": list(messages), "tools": list(tools), "model": model})
        return self._results.pop(0)


class HarnessTests(unittest.TestCase):
    def _run_with(self, provider, *, stdin_lines: list[str] = (), budget: int = 0):
        buf = io.StringIO()
        env = {
            "SATAN_RUN_ID": "test-run",
            "SATAN_BUDGET_TOKENS": str(budget),
            "SATAN_PROVIDER": "openrouter",
            "SATAN_MODEL": "test-model",
            "OPENROUTER_API_KEY": "test-key",
        }
        with tempfile.TemporaryDirectory() as tmp:
            make_bundle(tmp)
            env["SATAN_RUN_DIR"] = tmp
            with mock.patch.dict(os.environ, env, clear=False), \
                 mock.patch.object(runloop, "build_provider",
                                   return_value=(provider, "test-model")), \
                 mock.patch.object(sys, "stdin", io.StringIO("".join(stdin_lines))), \
                 redirect_stdout(buf):
                rc = runloop.run()
        return rc, emitted_lines(buf)

    def test_satan_final_terminates(self):
        provider = StubProvider([
            CompletionResult(
                content="",
                tool_calls=[{"id": "c1", "name": "satan_final",
                             "args": {"summary": "ok", "actions": []}}],
                input_tokens=10, output_tokens=5,
            ),
        ])
        rc, lines = self._run_with(provider)
        self.assertEqual(rc, 0)
        kinds = [m.get("type") for m in lines]
        self.assertIn("ready", kinds)
        self.assertIn("log", kinds)
        self.assertEqual(kinds[-1], "final")
        final = lines[-1]
        self.assertEqual(final["summary"], "ok")
        self.assertEqual(final["actions"], [])

    def test_tool_call_then_final(self):
        provider = StubProvider([
            CompletionResult(
                content="",
                tool_calls=[{"id": "c1", "name": "org_read_context",
                             "args": {"scope": "today"}}],
                input_tokens=10, output_tokens=5,
            ),
            CompletionResult(
                content="",
                tool_calls=[{"id": "c2", "name": "satan_final",
                             "args": {"summary": "done", "actions": []}}],
                input_tokens=20, output_tokens=8,
            ),
        ])
        tool_result = json.dumps({"type": "tool_result", "id": "c1",
                                   "ok": True, "result": {"content": ""}}) + "\n"
        rc, lines = self._run_with(provider, stdin_lines=[tool_result])
        self.assertEqual(rc, 0)
        types = [m["type"] for m in lines]
        self.assertEqual(types[0], "ready")
        self.assertIn("tool_call", types)
        self.assertEqual(types[-1], "final")
        tc = next(m for m in lines if m["type"] == "tool_call")
        self.assertEqual(tc["name"], "org_read_context")
        self.assertEqual(tc["args"], {"scope": "today"})

    def test_no_tool_calls_coerces_final(self):
        provider = StubProvider([
            CompletionResult(
                content="just text",
                tool_calls=[],
                input_tokens=10, output_tokens=5,
            ),
        ])
        rc, lines = self._run_with(provider)
        self.assertEqual(rc, 0)
        final = lines[-1]
        self.assertEqual(final["type"], "final")
        self.assertEqual(final["summary"], "just text")
        self.assertEqual(final["reason"], "no_tool_calls")

    def test_budget_warning_then_model_finals(self):
        # Soft budget UX: harness warns once, model winds down with its
        # own satan_final on the next turn. No synthetic final.
        provider = StubProvider([
            CompletionResult(
                content="",
                tool_calls=[{"id": "c1", "name": "org_read_context",
                             "args": {"scope": "today"}}],
                input_tokens=900, output_tokens=200,  # over budget=1000
            ),
            CompletionResult(
                content="",
                tool_calls=[{"id": "c2", "name": "satan_final",
                             "args": {"summary": "winding down", "actions": []}}],
                input_tokens=50, output_tokens=10,
            ),
        ])
        tool_result = json.dumps({"type": "tool_result", "id": "c1",
                                   "ok": True, "result": {"content": ""}}) + "\n"
        rc, lines = self._run_with(provider, stdin_lines=[tool_result], budget=1000)
        self.assertEqual(rc, 0)
        warnings = [m for m in lines
                    if m.get("type") == "log" and m.get("kind") == "budget_warning"]
        self.assertEqual(len(warnings), 1)
        self.assertEqual(warnings[0]["budget_tokens"], 1000)
        final = lines[-1]
        self.assertEqual(final["type"], "final")
        self.assertEqual(final["summary"], "winding down")
        self.assertNotIn("reason", final)
        # Model saw the system warning on its second turn.
        self.assertEqual(len(provider.calls), 2)
        second_turn_systems = [m for m in provider.calls[1]["messages"]
                               if m["role"] == "system"]
        self.assertTrue(any("budget" in (m["content"] or "").lower()
                            for m in second_turn_systems))

    def test_budget_warning_then_model_persists_forces_final(self):
        # If the model ignores the warning and keeps emitting tool calls
        # (or text without satan_final), the harness force-terminates.
        provider = StubProvider([
            CompletionResult(
                content="",
                tool_calls=[{"id": "c1", "name": "org_read_context",
                             "args": {"scope": "today"}}],
                input_tokens=900, output_tokens=200,
            ),
            CompletionResult(
                content="still working",
                tool_calls=[{"id": "c2", "name": "org_read_context",
                             "args": {"scope": "today"}}],
                input_tokens=50, output_tokens=10,
            ),
        ])
        tool_result = json.dumps({"type": "tool_result", "id": "c1",
                                   "ok": True, "result": {"content": ""}}) + "\n"
        rc, lines = self._run_with(provider, stdin_lines=[tool_result], budget=1000)
        self.assertEqual(rc, 0)
        final = lines[-1]
        self.assertEqual(final["type"], "final")
        self.assertEqual(final["reason"], "budget_tokens")
        self.assertIn("did not finalise", final["summary"])

    def test_build_tools_returns_manifest_tools(self):
        manifest = {
            "tools": [
                _stub_tool_schema("a_tool"),
                _stub_tool_schema("satan_final"),
            ],
        }
        tools = bundle.build_tools(manifest)
        names = [t["function"]["name"] for t in tools]
        self.assertEqual(names, ["a_tool", "satan_final"])

    def test_build_tools_missing_raises(self):
        with self.assertRaises(RuntimeError):
            bundle.build_tools({})
        with self.assertRaises(RuntimeError):
            bundle.build_tools({"tools": []})

    def test_system_prompt_returns_bundle_prompt_verbatim(self):
        # The broker hands the harness a fully-rendered system prompt
        # (scaffold + mode + bundle-section framing). The harness must
        # not modify it — every section header lives mind-side.
        rendered = (
            "SCAFFOLD\n\nMODE PROMPT\n\n# Now\ndate: 2026-05-19\n\n"
            "# Today (raw)\nbody\n\n# Source files\n## a.el\n```\nx\n```"
        )
        self.assertEqual(bundle.build_system_prompt({"prompt": rendered}),
                         rendered)

    def test_system_prompt_missing_key_raises(self):
        # `bundle["prompt"]` is now a hard contract from the broker.
        with self.assertRaises(KeyError):
            bundle.build_system_prompt({})


class ProtocolFixtureTests(unittest.TestCase):
    """Drive the python validator from protocol/fixtures.json.

    Every valid fixture must validate clean; every invalid fixture must
    fail with exactly the reason recorded in the fixture, so the python
    and elisp validators stay in lockstep.
    """

    def test_fixtures_load(self):
        fixtures = protocol.load_fixtures()
        self.assertTrue(fixtures)

    def test_valid_fixtures_pass(self):
        for entry in protocol.load_fixtures():
            if entry["kind"] != "valid":
                continue
            with self.subTest(name=entry["name"]):
                reason = protocol.check(entry["direction"], entry["message"])
                self.assertIsNone(reason)

    def test_invalid_fixtures_fail_with_expected_reason(self):
        for entry in protocol.load_fixtures():
            if entry["kind"] != "invalid":
                continue
            with self.subTest(name=entry["name"]):
                reason = protocol.check(entry["direction"], entry["message"])
                self.assertIsNotNone(reason, f"{entry['name']} unexpectedly passed")
                self.assertEqual(reason, entry["reason"])

    def test_validate_raises_on_invalid(self):
        with self.assertRaises(protocol.ProtocolError):
            protocol.validate("in", {"type": "ready"})

    def test_validate_passes_on_valid(self):
        protocol.validate("in", {"type": "ready", "run_id": "x"})

    def test_bad_direction_raises(self):
        with self.assertRaises(ValueError):
            protocol.check("sideways", {"type": "ready", "run_id": "x"})


class FakeOpenAI:
    """Captures OpenAI(...) ctor kwargs so tests can assert wiring."""
    last_kwargs: dict = {}

    def __init__(self, **kwargs):
        type(self).last_kwargs = kwargs
        self.chat = mock.MagicMock()


def _fake_openai_module():
    import types
    mod = types.ModuleType("openai")
    mod.OpenAI = FakeOpenAI
    return mod


class ProviderFactoryTests(unittest.TestCase):
    """Verify build_provider dispatches to the right subclass + base_url.

    The real `openai` SDK is not in scope for these unit tests (and may
    be absent in the dev env). Inject a fake module into `sys.modules`
    so the `from openai import OpenAI` inside `OpenAICompatibleProvider`
    resolves to `FakeOpenAI`.
    """

    def _build(self, env: dict) -> tuple[Provider, str]:
        with mock.patch.dict(os.environ, env, clear=True), \
             mock.patch.dict(sys.modules, {"openai": _fake_openai_module()}):
            FakeOpenAI.last_kwargs = {}
            return build_provider()

    def test_openrouter_dispatch(self):
        provider, model = self._build({
            "SATAN_PROVIDER": "openrouter",
            "SATAN_MODEL": "x-ai/grok",
            "OPENROUTER_API_KEY": "or-key",
        })
        self.assertIsInstance(provider, OpenRouterProvider)
        self.assertEqual(model, "x-ai/grok")
        self.assertEqual(FakeOpenAI.last_kwargs["api_key"], "or-key")
        self.assertEqual(FakeOpenAI.last_kwargs["base_url"],
                         "https://openrouter.ai/api/v1")

    def test_deepseek_dispatch(self):
        provider, model = self._build({
            "SATAN_PROVIDER": "deepseek",
            "SATAN_MODEL": "deepseek-chat",
            "DEEPSEEK_API_KEY": "ds-key",
        })
        self.assertIsInstance(provider, DeepSeekProvider)
        self.assertEqual(model, "deepseek-chat")
        self.assertEqual(FakeOpenAI.last_kwargs["api_key"], "ds-key")
        self.assertEqual(FakeOpenAI.last_kwargs["base_url"],
                         "https://api.deepseek.com")

    def test_default_provider_is_openrouter(self):
        provider, _ = self._build({
            "SATAN_MODEL": "any",
            "OPENROUTER_API_KEY": "k",
        })
        self.assertIsInstance(provider, OpenRouterProvider)

    def test_unknown_provider_raises(self):
        with self.assertRaisesRegex(RuntimeError, "unknown SATAN_PROVIDER"):
            self._build({
                "SATAN_PROVIDER": "claude-native",
                "SATAN_MODEL": "x",
            })

    def test_missing_model_raises(self):
        with self.assertRaisesRegex(RuntimeError, "SATAN_MODEL not set"):
            self._build({"SATAN_PROVIDER": "deepseek",
                         "DEEPSEEK_API_KEY": "k"})

    def test_missing_key_raises(self):
        with self.assertRaisesRegex(RuntimeError, "DEEPSEEK_API_KEY not set"):
            self._build({"SATAN_PROVIDER": "deepseek",
                         "SATAN_MODEL": "deepseek-chat"})


if __name__ == "__main__":
    unittest.main()
