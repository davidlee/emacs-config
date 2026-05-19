"""Unit tests for the SATAN gptel harness.

No network. Stub Provider, stub stdin/stdout, verify protocol shape.
Run: python -m unittest satan.harness.test_gptel_harness
or:  python -m unittest discover -s ~/.emacs.d/satan/harness -p 'test_*.py'
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

import gptel_harness as h  # noqa: E402


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
    bundle = {
        "prompt": "test prompt",
        "mode": "morning",
        "date": "2026-05-19",
        "today_path": "/satan/notes/today.org",
        "today_text": "",
    }
    bundle.update(overrides)
    with open(os.path.join(tmp, "bundle.json"), "w", encoding="utf-8") as f:
        json.dump(bundle, f)
    manifest = {
        "run_id": "test-run",
        "tools": list(tools) if tools is not None else DEFAULT_MANIFEST_TOOLS,
    }
    with open(os.path.join(tmp, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f)
    return tmp


def emitted_lines(buf: io.StringIO) -> list[dict]:
    return [json.loads(line) for line in buf.getvalue().splitlines() if line.strip()]


class StubProvider(h.Provider):
    def __init__(self, results: list[h.CompletionResult]):
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
                 mock.patch.object(h, "build_provider", return_value=(provider, "test-model")), \
                 mock.patch.object(sys, "stdin", io.StringIO("".join(stdin_lines))), \
                 redirect_stdout(buf):
                rc = h.run()
        return rc, emitted_lines(buf)

    def test_satan_final_terminates(self):
        provider = StubProvider([
            h.CompletionResult(
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
            h.CompletionResult(
                content="",
                tool_calls=[{"id": "c1", "name": "org_read_context",
                             "args": {"scope": "today"}}],
                input_tokens=10, output_tokens=5,
            ),
            h.CompletionResult(
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
            h.CompletionResult(
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

    def test_budget_exhaustion_emits_final(self):
        provider = StubProvider([
            h.CompletionResult(
                content="",
                tool_calls=[{"id": "c1", "name": "org_read_context",
                             "args": {"scope": "today"}}],
                input_tokens=900, output_tokens=200,  # over budget=1000
            ),
        ])
        tool_result = json.dumps({"type": "tool_result", "id": "c1",
                                   "ok": True, "result": {"content": ""}}) + "\n"
        rc, lines = self._run_with(provider, stdin_lines=[tool_result], budget=1000)
        self.assertEqual(rc, 0)
        final = lines[-1]
        self.assertEqual(final["type"], "final")
        self.assertEqual(final["reason"], "budget_tokens")

    def test_build_tools_returns_manifest_tools(self):
        manifest = {
            "tools": [
                _stub_tool_schema("a_tool"),
                _stub_tool_schema("satan_final"),
            ],
        }
        tools = h.build_tools(manifest)
        names = [t["function"]["name"] for t in tools]
        self.assertEqual(names, ["a_tool", "satan_final"])

    def test_build_tools_missing_raises(self):
        with self.assertRaises(RuntimeError):
            h.build_tools({})
        with self.assertRaises(RuntimeError):
            h.build_tools({"tools": []})

    def test_system_prompt_passes_bundle_prompt_through(self):
        bundle = {"prompt": "SCAFFOLD\n\nMODE PROMPT"}
        prompt = h.build_system_prompt(bundle)
        self.assertTrue(prompt.startswith("SCAFFOLD"))
        self.assertIn("MODE PROMPT", prompt)
        # Harness must not append any canonical termination prose.
        self.assertNotIn("satan_final", prompt)

    def test_system_prompt_renders_sources(self):
        bundle = {
            "prompt": "P",
            "sources": [
                {"path": "satan/x.el", "content": "(provide 'x)"},
                {"path": "satan/y.py", "content": "x = 1"},
            ],
        }
        prompt = h.build_system_prompt(bundle)
        self.assertIn("## satan/x.el", prompt)
        self.assertIn("(provide 'x)", prompt)
        self.assertIn("## satan/y.py", prompt)
        self.assertIn("x = 1", prompt)


if __name__ == "__main__":
    unittest.main()
