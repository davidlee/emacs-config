---
id: IP-007-P01
slug: "007-satan_interactive_pi_dev_mcp_harness-phase-01"
name: IP-007 Phase 01
created: "2026-05-31"
updated: "2026-05-31"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-007
delta: DE-007
---

# Phase 1 — Gating spike & transport contract freeze

## 1. Objective

Resolve the load-bearing unknowns (R6) **before any Emacs-side code**: confirm
`pi.dev` can run an stdio MCP server whose command is an arbitrary bridge
(`socat`/`nc -U`), freeze the MCP wire framing the Emacs server must speak, and
locate pi's MCP config syntax. Also audit which tool handlers read run-state
globals beyond `current-run-id` (Codex #7), so Phase 2 knows what the session
ctx must set. Output is a frozen transport contract in `notes.md` — or a decision
to fall back to HTTP/SSE (which pulls Option-C scope forward).

## 2. Links & References

- **Delta**: DE-007
- **Design Revision Sections**: DR-007 §3 (C4 topology), DEC-1, DEC-2, DEC-7;
  §8 open questions (R6, framing, config syntax, handler-global audit).
- **Risks**: R6 (gating), R5/DEC-7 (globals).
- **Support Docs**: `docs/satan/protocol.md` (membrane framing precedent);
  `satan/dl-satan-jsonl.el` (line framing we intend to reuse);
  `satan/dl-satan-patch-adapter-pi.el` (how `jailed-pi` is invoked + `--system-prompt`).
- **External**: pi.dev MCP client docs (config file location + stdio-server schema).

## 3. Entrance Criteria

- [x] DE-007 + DR-007 accepted; codex review integrated.
- [x] Reuse targets confirmed against code.

## 4. Exit Criteria / Done When

- [x] **R6 answered**: pi has both an MCP-client and an Extension API; DEC-12
      selects a TS extension over node-`net` UDS (no socat, no stdio-command
      dependency). Recorded in `notes.md` + DR-007 DEC-12.
- [x] **Framing frozen**: newline-delimited JSON-RPC; proven on the Emacs side via
      batch self-test; the extension speaks the same. No Content-Length.
- [x] **Emacs UDS MCP server proven**: throwaway stub `phases/spike/mcp-smoke.el`
      answers initialize/tools/list/tools/call/ping; `arguments` arrives as a
      keyword-plist (confirms the dispatch reuse, Codex #2).
- [x] **Handler-global audit**: no run-state coupling beyond `current-run-id`
      (notes.md table).
- [x] Phase 1 produced one *throwaway* spike file only (not tracked config).

> Note: the live pi↔extension round-trip moves to **Phase 3** (where the
> extension is authored + the UDS bind-mounted into the jail). Phase 1's job —
> de-risk the topology + freeze the contract — is complete; Phase 2 (real
> `dl-satan-mcp.el`) is unblocked.

## 5. Verification

- **VA** (agent proof): a minimal end-to-end transport smoke test *without* SATAN —
  stand up a throwaway UDS echo/JSON-RPC stub (e.g. `socat
  UNIX-LISTEN:/tmp/x.sock,fork EXEC:'a tiny responder'`), point pi's MCP config at
  `socat STDIO UNIX-CONNECT:/tmp/x.sock`, and confirm pi lists/“calls” the stub
  tool. Capture the transcript. This proves the topology before broker work.
- Evidence: pi MCP config snippet + smoke-test transcript pasted into `notes.md`.
- No `just check` impact (no repo code changes).

## 6. Assumptions & STOP Conditions

- **Assumptions**: pi.dev exposes user-configurable MCP servers; `socat` (or
  `nc -U`) is installable into the jail; `--system-prompt` still accepted
  (proven in patch adapter).
- **STOP and consult** when:
  - pi.dev has **no** way to register a custom stdio MCP server command → the
    whole socat topology is dead; escalate to the user with the HTTP/SSE-in-Emacs
    fallback (which is larger and overlaps Option C).
  - pi requires `Content-Length` framing AND that materially complicates reuse of
    `dl-satan-jsonl` → note it; Phase 2 framing decision changes.
  - the handler-global audit finds a handler that *writes* run-state globals (not
    just reads), implying deeper reentrancy work than DEC-8's guard covers.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 1.1 | Identify pi integration seams | [ ] | DONE — MCP-client (sdk: stdio/http/sse), Extension API (registerTool), RPC, SDK. DEC-12 picks Extension. |
| [x] | 1.2 | MCP framing decision | [P] | DONE — newline-delimited JSON-RPC (Emacs side proven); extension speaks same |
| [x] | 1.3 | Prove UDS MCP server + pi↔extension round-trip | [ ] | DONE — batch self-test all 5 methods. Live pi↔extension leg PROVEN 2026-05-31 (jailed-pi + mcp-smoke UDS; satan_smoke_echo round-trip sub-second) |
| [x] | 1.4 | Handler-global audit | [P] | DONE — no run-state coupling beyond current-run-id (notes.md) |
| [x] | 1.5 | Freeze transport contract in `notes.md` | [ ] | DONE — DEC-12 recorded; framing + reuse confirmed |

### Task Details

- **1.1 pi MCP config**
  - **Approach**: locate pi's MCP server config (likely a TOML/JSON under
    `~/.config/pi*` or a project file); record the exact key shape for an stdio
    server with custom `command`+`args`.
  - **Observations & AI Notes**: pi is invoked as `jailed-pi` (bwrap) — confirm
    where the config is read from *inside* the jail.

- **1.2 Framing**
  - **Approach**: check the MCP spec version pi implements. Current MCP stdio =
    newline-delimited JSON-RPC (no `Content-Length`). Confirm; if LSP-style,
    Phase 2 must frame accordingly rather than reusing `dl-satan-jsonl` verbatim.

- **1.3 Smoke test**
  - **Approach**: no SATAN involved. Throwaway UDS responder answering
    `initialize`/`tools/list`/`tools/call`; pi config points at `socat STDIO
    UNIX-CONNECT:<sock>`. Confirms the byte-bridge topology end to end.
  - **Testing**: capture pi's tool listing + one call round-trip.

- **1.4 Handler-global audit**
  - **Approach**: `rg` SATAN tool handlers for reads of broker/run globals
    (`current-run-id`, `dl-satan-broker--*`, run-dir lookups). Classify each as
    benign-read vs run-state-dependent. Known so far: `atsatan` uses soft
    `dl-satan-broker-locate-run-dir` (benign historical lookup); `memory-store`
    keys writes off `current-run-id` (DEC-7, handled by bind-around-dispatch).
  - **Files**: `satan/dl-satan-tools-*.el`.

- **1.5 Contract freeze**
  - **Approach**: write the decided framing, pi config example, smoke-test
    evidence, and handler-audit results into `notes.md`; flip the IP-007 Phase 1
    progress box. This is the Phase 2 entrance gate.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| --- | --- | --- |
| R6 — pi reach to external tool channel | TS extension over node-net UDS (DEC-12); Emacs side proven | closed |
| Framing mismatch | newline JSON-RPC decided + proven; extension speaks same | closed |

## 9. Decisions & Outcomes

- `2026-05-31` — Phase ordering: spike leads; no Emacs code until contract frozen.
- `2026-05-31` — **DEC-12**: pi-side front-end = TS Extension over node-`net` UDS
  (no socat). pi's `@modelcontextprotocol/sdk` lacks a UDS transport; the Extension
  API + node-net give direct UDS. Seeds Option C.
- `2026-05-31` — R6 resolved; Emacs UDS MCP server proven by batch self-test.
- `2026-05-31` — Codex #2 (arg shape) resolved: plist parse → args land as the
  keyword-plist `:args-schema` expects; no normalization layer.

## 10. Findings / Research Notes

- Canonical sink: `DE-007/notes.md`.
- Spike artefacts: `phases/spike/mcp-smoke.el` (Emacs UDS MCP stub), `phases/spike/satan-extension-spike.ts` (pi TS extension).
- **Live test (2026-05-31):** jailed-pi with `XDG_RUNTIME_DIR=/run/user/1000` + UDS bind-mount; extension connected, registered `satan_smoke_echo`, round-trip `"echo: hello from pi extension"` sub-second. Full MCP lifecycle validated: connect → initialize → tools/list → registerTool → tools/call → result.

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Transport contract + evidence in `notes.md`
- [x] IP-007 Phase 1 done; Phase 2 entrance unblocked
- [x] Hand-off to Phase 2: build real `dl-satan-mcp.el` from the proven stub
      (newline framing, plist parse, synthetic bundle+final, DEC-8/10 guards);
      Phase 3 authors `.pi/extensions/satan.ts` + jail bind-mount.
