---
id: IP-007-P02
slug: "007-satan_interactive_pi_dev_mcp_harness-phase-02"
name: IP-007 Phase 3 — pi extension, jail, launcher, live VH
created: "2026-05-31"
updated: "2026-05-31"
status: completed
kind: phase
plan: IP-007
delta: DE-007
---

# Phase 3 — pi extension, jail bind-mount, launcher, live VH

## 1. Objective

Wire the real `dl-satan-mcp.el` server to a live `pi.dev` session via the
DEC-12 TS extension. End state: `M-x my/satan-mcp-pi-session` starts the
server, the user runs a jailed-pi (interactive profile) with the satan
extension and the UDS bind-mounted, pi lists and calls real SATAN tools.

## 2. Links & References

- **Delta**: DE-007
- **Design Revision Sections**: DR-007 §3 (C4 topology), DEC-12 (TS extension), DEC-5 (synthetic audit)
- **IP**: IP-007 §4 Phase 3 entry
- **Support Docs**:
  - `satan/dl-satan-mcp.el` — MCP server (defcustoms, start/stop, session lifecycle)
  - `phases/spike/satan-extension-spike.ts` — blueprint for `.pi/extensions/satan.ts`
  - `~/flakes` — Nix home-manager jail profile to modify
  - `satan/prompts/` — system prompt dir (interactive.txt to be created)

## 3. Entrance Criteria

- [x] Phase 2 green (`dl-satan-mcp.el` implemented, 15 ert tests passing, `just check` green)
- [x] `dl-satan-mcp` socket uses deterministic filename (`mcp.sock`) for flake bind-mount
- [x] Test tools excluded from interactive mode union (no spurious description-file check)

## 4. Exit Criteria / Done When

- [ ] `.pi/extensions/satan.ts` created and adapts the spike blueprint:
      socket path matches `dl-satan-mcp-runtime-dir/mcp.sock`; TypeBox conversion
      handles SATAN schema types; proper error handling/notifications
- [ ] `satan/prompts/interactive.txt` created — static system prompt for the
      interactive pi session (Option A, DEC-6: no satan_final)
- [ ] `~/flakes` interactive jailed-pi profile bind-mounts the MCP UDS
      (`$XDG_RUNTIME_DIR/satan/mcp/mcp.sock` → same in jail); no socat needed
- [ ] `home-manager switch` run to pick up the new profile + any new .el
- [ ] **VH-mcp-live-pi**: live pi session lists tools, executes one read tool +
      one owned-write tool; pi terminal stdio uninvolved in tool transport;
      `transcript.jsonl` shows the calls
- [ ] `just check` green
- [ ] CHANGELOG updated

## 5. Verification

- **VT**: existing `dl-satan-mcp-test.el` (15 tests) still green
- **VH**: VH-mcp-live-pi — live interactive session with pi
  - Start server: `M-x my/satan-mcp-pi-session`
  - Run jailed-pi with extension: `jailed-pi-satan -e ~/.pi/extensions/satan.ts`
  - pi lists ~30+ SATAN tools
  - Execute one read tool (e.g. `org_read_context`)
  - Execute one owned-write tool (e.g. `inbox_append`)
  - pi terminal stdio uninvolved (tools use MCP UDS, not terminal)
  - `transcript.jsonl` shows the tool calls
- **just check**: must stay green throughout

## 6. Assumptions & STOP Conditions

- **Assumptions**:
  - `XDG_RUNTIME_DIR` is `/run/user/1000` both on host and in jail (confirmed in Phase 1 spike)
  - `pi.dev` via `jailed-pi` accepts `-e` for extensions (confirmed in Phase 1 spike)
  - `@earendil-works/pi-coding-agent` ExtensionAPI exports match the spike blueprint
  - `typebox` is available in pi's runtime for runtime schema conversion
- **STOP and consult** when:
  - The TS extension fails to register tools dynamically (pi version drift)
  - The jail bind-mount doesn't make the socket visible (bwrap flag change)
  - `home-manager switch` fails or introduces regressions
  - pi's MCP client crashes or times out during the live test

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 3.1 | Fix test tool pollution in interactive union | [ ] | Done — filter `test.*` from tools/capabilities list |
| [x] | 3.2 | Deterministic socket filename | [ ] | Done — `dl-satan-mcp-socket-filename` defcustom, default `mcp.sock` |
| [ ] | 3.3 | Create `.pi/extensions/satan.ts` | [ ] | Adapt from `phases/spike/satan-extension-spike.ts`; match socket path |
| [ ] | 3.4 | Create `satan/prompts/interactive.txt` | [P] | Option A: static system prompt, no satan_final |
| [ ] | 3.5 | Nix: interactive jailed-pi profile with UDS bind-mount | [ ] | `~/flakes` — jail variant, no socat |
| [ ] | 3.6 | `home-manager switch` | [ ] | Picks up new .el + new jail profile |
| [ ] | 3.7 | Live VH test (VH-mcp-live-pi) | [ ] | pi lists tools, calls read + write, verify transcript |
| [ ] | 3.8 | Update CHANGELOG, final notes | [ ] | |

### Task Details

- **3.3 `.pi/extensions/satan.ts`**
  - **Design / Approach**: Copy the spike blueprint; change `SOCKET_PATH` default
    to `$XDG_RUNTIME_DIR/satan/mcp/mcp.sock` (matches `dl-satan-mcp-runtime-dir`
    + `dl-satan-mcp-socket-filename`). The extension is SATAN-agnostic — it
    connects, initializes, lists tools, registers each via `pi.registerTool()`,
    and proxies `execute` → `tools/call`. Runs untrusted in pi's jail.
  - **Files / Components**: `.pi/extensions/satan.ts` (new, ~80 LOC net-new after
    stripping spike scaffolding)
  - **Testing**: Live VH only — the extension talks to a real Emacs MCP server
  - **Commits / References**: `phases/spike/satan-extension-spike.ts`

- **3.4 `satan/prompts/interactive.txt`**
  - **Design / Approach**: Static system prompt for pi. Covers:
    - SATAN's role (knowledge management agent with Emacs tools)
    - Available tool categories (org, denote, inbox, memory, agenda, motive, …)
    - Interaction model (human supervises; pi calls tools over MCP)
    - Option A: no `satan_final` — pi's output is what the human reads
  - **Files / Components**: `satan/prompts/interactive.txt` (new)
  - **Testing**: Manual — does the prompt produce sensible pi behaviour?

- **3.5 Nix interactive jail profile**
  - **Design / Approach**: Add a `jailed-pi-satan` (or `jailed-pi` interactive
    variant) in `~/flakes` that bind-mounts the MCP socket from
    `$XDG_RUNTIME_DIR/satan/mcp/mcp.sock` into the same path inside the jail.
    `XDG_RUNTIME_DIR` is already in the jail env. No socat needed — the TS
    extension uses node `net.createConnection()` on the UDS directly.
  - **Files / Components**: `~/flakes/modules/home/…` (nix expression for the jail)
  - **Testing**: `jailed-pi-satan -e .pi/extensions/satan.ts` starts without errors

- **3.7 Live VH test**
  - **Design / Approach**:
    1. Emacs: `M-x my/satan-mcp-pi-session` → prints socket path
    2. Shell: `jailed-pi-satan -e ~/.pi/extensions/satan.ts`
    3. In pi: ask "list your tools" → should see 30+ SATAN tools
    4. In pi: ask "read my org agenda for today" → calls `org_read_context`
    5. In pi: ask "append a note to my inbox" → calls `inbox_append`
    6. Verify pi's terminal shows normal conversation (tool transport is UDS-only)
    7. Check `transcript.jsonl` in the session run dir for `tool_call`/`tool_result` records
  - **Files / Components**: Whole system integration
  - **Testing**: End-to-end VH

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| pi ExtensionAPI version drift from spike | Spike used the real pi; check for deprecation warnings | monitor |
| bwrap flags change, socket not visible | Phase 1 spike already proved bind-mount works | low |
| `home-manager switch` regression | Existing `jailed-pi` profile is unchanged; new variant is additive | low |
| `typebox` not available in pi runtime | Extension uses `import { Type } from "typebox"` — verify in pi env | check |

## 9. Decisions & Outcomes

- `2026-05-31` — **Socket determinism**: `dl-satan-mcp-socket-filename` defcustom
  with default `"mcp.sock"`. The parent dir hardening (0700, anti-symlink) is
  preserved; only the leaf name is fixed. Compromise between DEC-10 (randomize)
  and operational need (flake bind-mount needs a stable path).
- `2026-05-31` — **Test tool isolation**: `interactive` mode now excludes
  `test.*` tools from both tools list and capabilities union. Internal test
  fixtures shouldn't leak into the interactive session surface.

## 10. Findings / Research Notes

- See `notes.md` for Phase 1 & 2 history.
- Socket path after 3.2: `$XDG_RUNTIME_DIR/satan/mcp/mcp.sock`
- Interactive sessions don't get a percept/n (Option A avoids heavy deps). Option C should add this.

### Potential follow-ups (not blocking)

- **`Type.Any()` fallback for unknown schema types**: If a tool has a typo in
  its `:args-schema :type`, validation silently accepts anything instead of
  failing. Add warning log or strict mode.
- **Enum handling assumes string values** (`Type.Literal(v as string)`): If
  SATAN ever uses numeric enums on integer fields, the TypeBox conversion
  breaks. Extend the enum handler to check `schema.type`.
- **No MCP reconnection**: If the UDS connection drops mid-session, the
  session is dead (no auto-reconnect). Not worth for v0 — server lifetime =
  session lifetime.

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] VH-mcp-live-pi evidence captured (transcript excerpt in notes.md)
- [x] CHANGELOG updated
- [ ] Hand-off to `/audit-change`
