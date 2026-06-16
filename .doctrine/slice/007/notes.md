# Notes for DE-007

## Phase 4 — IN PROGRESS (2026-06-03)

### Completed (tasks 4.1–4.6)

- **4.1 DEC-8 guard**: `dl-satan-broker--spawn-running` now set/cleared around
  `broker--spawn` (unwind-protect + sentinel).  `dl-satan-mcp--session-active`
  flag set on session mint / cleared on close.  `dl-satan-broker-run` refuses
  to spawn while session is active.  3 DEC-8 tests pass.
- **4.2 R10 extraction**: `dl-satan-run-assemble-context` extracted into
  `dl-satan-context.el` (DR-007 F4).  Builds percept/resonance/motive/
  sensor_status and threads into prepare.  Observer-independent subset.
  967 tests regression-proven.
- **4.3 context-fn**: `dl-satan-context-interactive` registered on interactive
  mode-spec.  Builds orientation capsule at build-depth β with assembled=""
  (persona already in SYSTEM.md).  Fresh current-time stamp (F3).
- **4.4 satan_boot_context tool**: globally registered read tool.  Handler
  `dl-satan-mcp-tool/boot-context` with per-session capsule cache + refresh
  arg + graceful degrade.  Loads dl-satan-context at runtime to avoid
  compile-time dependency.
- **4.5 description file**: `satan_boot_context.md` at
  `dl-satan-tools-descriptions-dir` (R7 fail-fast).
- **4.6 SYSTEM.md instruction**: `interactive.txt` updated with first-turn
  boot context instruction.

### Known issue — "unsupported arg type: nil" on connection

After Emacs restart, the MCP server starts successfully but `mint-session`
fails when a client connects, with:

    SATAN: unsupported arg type: nil

The accept-filter catches this, logs "rejecting connection", and deletes
the client process.  Pi sees an immediate connection close.

**Instrumentation added** (commit `2fff82f`): `mint-session` now wraps each
`dl-satan-tool-json-schema` call in `condition-case` and reports the failing
tool name.  But the new code needs to actually reach the live Emacs daemon —
the user must either restart Emacs or run `emacsclient --eval '(load-file …)'`
from the **host** (emacsclient is not available inside the pi jail).

**Diagnosis steps for next agent:**
1. Ensure Emacs daemon has picked up the new `.el` files (restart or delete
   stale `.elc` files and `eval-buffer`).
2. Start MCP server: `emacsclient --eval '(my/hello-satan)'`
3. Connect from pi — the error will now say which tool's schema generation
   is producing the nil type.
4. Possible root causes:
   - A tool with a dynamic `:args-schema` (e.g. `sway_border_set` uses
     `classes-shape`) evaluates to nil at runtime.
   - Stale `.elc` byte-compiled files from before the changes.
   - Description file not found on host (`~/notes/satan/tools/satan_boot_context.md`
     was copied from `/workspace/notes/` but verify it exists).

### Remaining tasks (4.7–4.9)

- **4.7 Tests**: boot-context ert tests require `dl-satan-context.el` which
  can't load in batch mode (needs `dl-denote-journal`).  Write as integration
  tests or test manually in live daemon.
- **4.8 VH-mcp-boot-live**: live pi session calling `satan_boot_context`
  unprompted.  Requires MCP connection working (blocked by nil-type bug).
- **4.9 CHANGELOG + commit**.

### Commits

- `66f3b07` — DEC-8 guard (task 4.1)
- `3ff23c8` — extract assemble-context (task 4.2)
- `c8c9f3d` — context-fn + boot_context tool (tasks 4.3–4.4)
- `5d4f7f4` — fix mode re-registration
- `2fff82f` — instrument mint-session for debugging
- Notes repo `0bd5733` — description file + interactive.txt

## Phase 1 — COMPLETE (2026-05-31)

All five spike questions validated in live pi↔Emacs test. DEC-12 approach (TS
Extension over node-net UDS) confirmed working.

## Phase 2 — COMPLETE (2026-05-31)

### Delivered

- **`satan/dl-satan-run.el`** — extracted shared run infrastructure (struct,
  mint-id, prepare, tool-ctx, run-dir resolution) with zero heavy deps.
  Required by both `dl-satan-broker.el` and `dl-satan-mcp.el`.
- **`satan/dl-satan-mcp.el`** — full MCP server: 5 methods (initialize, ping,
  tools/list, tools/call, notifications/initialized) on hardened UDS.
  Reuses `dl-satan-tool-dispatch`, `dl-satan-tool-json-schema`, `dl-satan-audit`.
  DEC-5: per-session audit with synthetic bundle + completed final.
  DEC-7: `current-run-id` binding around dispatch.
  DEC-8: mutual-exclusion guard (`bound-and-true-p`).
  DEC-9: interactive mode-spec registered via `dl-satan-mode-register`.
  DEC-10: 0700 parent dir, randomized socket name, no /tmp, anti-symlink.
  R7: fail-fast precondition for missing tool descriptions.
- **`satan/test/dl-satan-mcp-test.el`** — 15 ert tests, all green.

### Verification

- `just check`: 932/938 pass (6 skipped — unchanged integration tests)
- Commit: `7a6ee78`

### Surprises

- `file-attribute-modes` returns a string ("rwx------") on NixOS, not an
  integer. Handled with `set-file-modes` enforcement rather than comparison.
- `:log` callback on `make-network-process` gets 3 args in Emacs 30
  (server, client, connection-info), not 2.
- `dl-satan-broker` can't be required from batch mode due to transitive deps
  (→ context → denote-journal). Extracted `dl-satan-run.el` to avoid this.

### Remaining Phase 2 work (deferred)

- Backward-compat aliases in `dl-satan-broker.el` for the extracted functions.
  Currently `dl-satan-run.el` and `dl-satan-broker.el` both define
  `dl-satan-runs-dir`, `dl-satan-hippocampus-dir`, `cl-defstruct dl-satan-run`
  — Emacs tolerates the duplication but it's untidy.

## Next: Phase 3 — jail profile, launcher, live VH

### Objective

Wire the real `dl-satan-mcp.el` server to a live pi.dev session via the
DEC-12 TS extension. End state: `M-x my/satan-mcp-pi-session` starts the
server, user runs `jailed-pi` (interactive profile) with the satan extension
and the UDS bind-mounted, pi lists and calls real SATAN tools.

### Required steps

1. **Nix:** `home-manager switch` to pick up new `.el` files (trap #1).
2. **Jail profile:** Create an interactive jailed-pi variant in `~/flakes` that
   bind-mounts the MCP UDS (path from `dl-satan-mcp-runtime-dir`) into the jail.
   No socat needed — the TS extension uses node `net`.
3. **Extension:** Create `.pi/extensions/satan.ts` (adapt from spike at
   `phases/spike/satan-extension-spike.ts`; change socket path to match
   `dl-satan-mcp-runtime-dir`, add proper error handling).
4. **System prompt:** Write `satan/prompts/interactive.txt` — the static system
   prompt pi gets for the interactive session (Option A, no satan_final).
5. **Live VH test:** Start server via `M-x my/satan-mcp-pi-session`, run
   jailed-pi with the extension, verify:
   - pi lists SATAN tools (30+ tools)
   - Execute one read tool (e.g. `org_read_context`)
   - Execute one owned-write tool (e.g. `inbox_append`)
   - pi terminal stdio uninvolved in tool transport
   - `transcript.jsonl` shows the calls

### Key files

- `satan/dl-satan-mcp.el` — MCP server (defcustoms, start/stop, session lifecycle)
- `.pi/extensions/satan.ts` — real extension (blueprint: `phases/spike/satan-extension-spike.ts`)
- `satan/prompts/interactive.txt` — to be created
- `~/flakes` — jail profile to be modified

### Open questions

- Confirm pi's negotiated MCP `protocolVersion` against the server
  (stub advertises `2025-06-18`).
- Reentrancy beyond DEC-8's coarse mutual-exclusion: replace the
  `current-run-id` global with a dynamic var now vs defer to C?

### Commit state

- `.spec-driver/**` changes committed with code in `7a6ee78`.
- Working tree clean.

---

## Phase 1 history (gating spike & transport contract freeze)

### Emacs-side UDS MCP responder: PROVEN (2026-05-31)

Throwaway stub: `phases/spike/mcp-smoke.el` (NOT tracked config; load-file in the
daemon, or `emacs --batch`). Batch self-test (client connects to the stub's own
UDS) passed all five cases:

| Request | Result |
| --- | --- |
| `initialize` | `result{protocolVersion, capabilities:{tools:{}}, serverInfo}` ✓ |
| `notifications/initialized` | no response (correct — notification) ✓ |
| `tools/list` | one tool with `inputSchema` ✓ |
| `tools/call` (echo) | `content:[{type:text,...}]` ✓ |
| `bogus/method` | `error{code:-32601}` ✓ |

**Confirmed contract decisions (feed Phase 2):**
- **Framing = newline-delimited JSON-RPC** works from the Emacs side
  (`json-serialize` + `"\n"`; `json-parse-string :object-type 'plist`). Reuse
  `dl-satan-jsonl` line framing in the real module.
- **`tools/call.arguments` arrives as a keyword-plist** whose keys match the tool
  schema (`:msg` extracted directly). Confirms DR-007's claim: no
  JSON-object→plist normalization layer — parse via the shared plist parser and
  pass straight to `dl-satan-tool-dispatch`. (Resolves Codex #2.)
- MCP protocol version advertised: `2025-06-18` (adjust if pi negotiates a
  different one).

### DEC-12 Spike — `.pi/extensions/satan.ts` over node-net UDS (2026-05-31)

Spike artefact: `phases/spike/satan-extension-spike.ts` (~265 LOC, ~100 net-new).

**Live test transcript (2026-05-31):**

```
# Emacs side: mcp-smoke.el running on /run/user/1000/satan-mcp-smoke.sock
# Pi side: jailed-pi -e phases/spike/satan-extension-spike.ts
# Jail env: XDG_RUNTIME_DIR=/run/user/1000, UDS bind-mounted

> call satan_smoke_echo with msg "hello from pi extension"
→ echo: hello from pi extension — smoke test round-trip
```

**Spike answers:**

| Q | Answer |
|---|--------|
| Q1: `net.createConnection(UDS)` in bwrap? | ✅ PROVEN. Sub-second connect. |
| Q2: Dynamic `pi.registerTool()` in `session_start`? | ✅ PROVEN. Tool callable same session. |
| Q3: JSON Schema → TypeBox at runtime? | ✅ PROVEN. `{msg: {type: "string"}}` converted correctly. |
| Q4: Newline-delimited JSON-RPC Node↔Emacs? | ✅ PROVEN. Identical framing. |
| Q5: `tools/call` round-trip in pi's timeout? | ✅ PROVEN. Sub-second round-trip. |

**Surprises / adaptations:**
- **UDS bind-mount:** The UDS file must be explicitly bind-mounted into the
  jailed-pi sandbox. `XDG_RUNTIME_DIR` is already present; the socket path
  resolves fine once the file is visible.

### Handler-global audit (task 1.4) — DONE (2026-05-31)

Swept `satan/dl-satan-tools*.el` for reads of run-state / broker globals. Result:
**no handler depends on `--spawn`/`--prepare` run-state.**

| Site | What | Verdict |
| --- | --- | --- |
| `tools.el:149` | `(plist-get run-ctx :capabilities)` | in tool-ctx ✓ |
| `tools-agenda.el:51` | `(getenv cal-env)` | daemon env, not run-state — benign |
| `tools-content.el:25` | `(getenv "XDG_STATE_HOME")` | daemon env — benign |
| `tools-motive.el:36,39` | `(plist-get parsed :motives)` | local parse, not run-ctx — benign |
| `tools-atsatan.el:535` | soft `dl-satan-broker-locate-run-dir` | read-only historical lookup, fboundp-guarded — benign |

No handler reads `:percept`/`:prepare`/`:resonance`/`:motive` from run-ctx; none
write run-state globals. The only run-state coupling is `current-run-id`
(memory-store, a global) → covered by DEC-7 (bind-around-dispatch) + DEC-8
(mutual exclusion). **Conclusion:** the 8-key synthetic session tool-ctx is
sufficient; the reuse claim holds. Codex #7 resolved.

## Phase 3 — IN PROGRESS (2026-05-31)

### Fix: test tool pollution & socket determinism

**Problem 1:** R7 fail-fast rejected startup because `dl-satan-mcp--interactive-tools`
(union of ALL registered tools) included `test.*` stubs from `dl-satan-tools-test.el`
(`test.allowed-check`, `test.no-cap`, `test.cap-required`, `test.cap-ok`). These have
no description files because they're internal test fixtures.
**Fix:** Filter `string-prefix-p "test."` in `dl-satan-mcp--interactive-tools`.

**Problem 2:** The randomized socket filename (`%06x.sock`) can't be predicted
for the Nix flake bwrap bind-mount.
**Fix:** Added `dl-satan-mcp-socket-filename` defcustom (default `"mcp.sock"`)
and changed `dl-satan-mcp--socket-path` to use it. The parent dir is still
0700 + anti-symlink (DEC-10); the filename alone is deterministic.

**Result:** Socket path is `$XDG_RUNTIME_DIR/satan/mcp/mcp.sock`.

### Commits

- Both fixes in `satan/dl-satan-mcp.el`.

### .pi/extensions/satan.ts — created (2026-05-31)

Adapted from `phases/spike/satan-extension-spike.ts`. Changes from spike:
- Socket path: `$XDG_RUNTIME_DIR/satan/mcp/mcp.sock` (matches
  `dl-satan-mcp-runtime-dir` + `dl-satan-mcp-socket-filename`)
- Removed spike scaffolding comments; production-ready error handling
- Registration counter replaces per-tool notifications (less noise)

### satan/prompts/interactive.txt — created (2026-05-31)

Location: `~/notes/satan/prompts/interactive.txt` (resolves to
`/workspace/notes/satan/prompts/interactive.txt` inside the jail).
Option A static system prompt: no satan_final, pi drives its own loop.

### Flake update (2026-05-31)

`flake.nix` mcpJailOptions: socket path changed from
`/run/user/1000/satan-mcp-smoke.sock` (spike) to
`/run/user/1000/satan/mcp/mcp.sock` (real).

### Fix: JSON schema regex dialect mismatch in sway_border_set (2026-05-31)

**Problem:** `dl-satan-sway-hex-pattern` (`\`#[0-9a-fA-F]\{6\}\'`) is
valid Elisp regex but was serialized verbatim into the JSON schema for the pi
harness. JavaScript's regex engine rejects `\{` as an invalid escape — JS uses
bare `{6}` for quantifiers.

**Fix:** Added `dl-satan-tool--pattern-to-jsonschema` in `dl-satan-tools.el`
that translates Elisp regex dialect → JS-compatible form at the JSON schema
emission boundary:

| Elisp | JS |
|---|---|
| `` \` `` (start anchor) | `^` |
| `\'` (end anchor) | `$` |
| `\{` `\}` (quant braces) | `{` `}` |

Runtime Elisp validator (`string-match-p`) still uses the original Elisp
pattern — only the schema emission path translates.

**Files changed:**
- `satan/dl-satan-tools.el` — translation function + wiring into
  `dl-satan-tool--args-schema-to-jsonschema`
- `satan/test/test-sway-border.el` — updated expected pattern in
  `jsonschema-nests-properties` test

**Verification:** `just check` — 932/938 pass, 0 unexpected.

### Remaining for Phase 3

- [x] `home-manager switch` to pick up new .el + flake change
- [x] Live VH test (VH-mcp-live-pi): start server, run jailed-pi with extension,
  call read + write tools, verify transcript
- [x] CHANGELOG update
- [x] Commit + push

## Adversarial review — 2026-06-01

Review of 8c4ab80 ("end to end viable"). Architecture solid: dispatch reuse
correct, audit integration thorough, POL-001 trust boundary respected.

### Resolved during review

| # | Finding | Resolution |
|---|---------|------------|
| F1 | `custom-vars.el` enabled MCP by default (O5 conflict) | Intentional — defcustom gates *auto-start*, not manual start; `enabled` semantics clarified |
| F2 | `interactive.txt` not tracked in repo | Committed |
| F3 | Phase sheet exit criteria stale | home-manager switch + VH done; phase sheet updated |
| F4 | Dead require `dl-satan-jsonl` in `dl-satan-mcp.el` | Removed |
| F5 | No test for `test.` tool name filtering | Test added |

### Follow-ups (low severity, not blocking)

- **F6 `prin1-to-string` for tool results** — produces Elisp repr, not JSON.
  Fine for text display in Option A; Option C should emit structured JSON.
- **F7 `tools/list` re-reads description files from disk** every call.
  Would benefit from caching (manifest already built in mint-session).
- **F8 TypeBox enum cast assumes string values** — `v as string` breaks
  on numeric enums. Documented limitation; fix when needed.
- **F9 No automated launcher** — `my/satan-mcp-pi-session` prints a message
  but doesn't start pi. Intentional for Option A; consider a
  `my/satan-mcp-pi-launch` helper that prints the exact jailed-pi command.
- **F10 Sentinel `broken` event** — matched in regex but `make-network-process`
  doesn't emit it (pipe-only). Harmless dead code; the `deleted` branch covers
  network disconnection.

---

## Phase 4 — DESIGNED, not yet planned (2026-06-03)

### What this phase is

Interactive **boot context**: feed pi the per-session orientation capsule
(now / attributes / percept / attention / resonance / motive / sensors) that
batch runs get via `bundle.json`, which the interactive session currently
lacks. `.pi/SYSTEM.md` is static persona only (built by the `~/notes` justfile
`build-system-prompt`: `cat scaffold.txt + interactive.txt`).

### Design decisions (DR-007 §3a + DEC-13) — locked with user

- **Delivery**: MCP read tool `satan_boot_context`; SYSTEM.md instructs pi to
  call it on first turn. Rejected: cat-ing live percept into SYSTEM.md at launch
  (freezes orientation, couples justfile to Emacs state).
- **Content**: full rendered parity — all 7 blocks.
- **Build-depth β**: build the 7 rendered blocks fresh, but SKIP autonomous
  telemetry (`observer-process`, `sensor-alerts-check` notifications,
  curiosity/content/wpm probes). A human boot fires no desktop notifications.
- **Assembly (Option 1 — DRY)**: extract `dl-satan-run-assemble-context`
  (percept-build+persist, resonance-derive, motive-read, sensor_status) shared
  by `broker--spawn` and a new `dl-satan-context-interactive` context-fn.
  Renders via existing `dl-satan-context--render-prompt` with `assembled=""`.

### Codex (gpt-5.5) external review — 8 findings, ALL integrated into DR/DE

- **F1** (was a real DR error): `memory_resonate` is **read-only v1** (no state
  mutation — `dl-satan-memory-store.el:14`, design §6.4). Boot records NO
  activation write. The earlier "accepted write / pure-derive split" framing is
  deleted/moot.
- **F4**: assembler must NOT go in `dl-satan-run.el` — that module is
  deliberately zero-heavy-deps (`cl-lib`/`subr-x` only). Put it in
  `dl-satan-context.el` or new `dl-satan-context-assemble.el`.
- **F3**: `mint-session` freezes `:time_now` at connect (`dl-satan-mcp.el:149`);
  boot build must stamp a **fresh `current-time`**, not reuse session time_now.
- **F2**: instruction-only delivery is fail-open → per-session capsule **cache**
  + explicit `refresh` arg; re-call must not silently rebuild/overwrite
  `percept.json`.
- **F5**: add `VT-broker-spawn-integration` (call-order + final prepare keys +
  artifacts) — the real regression net for the extraction.
- **F7**: build runs in the USER'S live Emacs → graceful-degrade (postgres-down
  → resonance block self-suppresses, capsule still renders, no errored call).
- **F8**: fixed §5 doc contradiction (missing-description = fatal, not skipped).
- **F6 — LATENT DEFECT surfaced**: the DEC-8 mutual-exclusion guard is
  **vacuous**. `dl-satan-broker--spawn-running` is only ever READ
  (`dl-satan-mcp.el:146,376`), **never set** by `broker--spawn`. So the session
  never actually refuses while a scheduled run is live, and nothing stops the
  scheduler spawning mid-session. **Phase 4 must actually implement DEC-8**
  (R11) — DEC-13 reentrancy safety depends on it.

### Phase 4 scope (carry into plan-phases)

1. **R11 / DEC-8 (prerequisite)**: set/clear `dl-satan-broker--spawn-running`
   around `broker--spawn` (unwind-protect/sentinel) + a session-active flag the
   scheduler checks; test exclusion both directions.
2. **R10**: extract `assemble-context` behaviour-preservingly; pin the exact
   return contract (which keys it threads vs the caller threads).
3. `dl-satan-context-interactive` context-fn + register on interactive mode-spec.
4. `satan_boot_context` tool (read) + handler + capsule cache/refresh +
   fresh-timestamp build + `satan_boot_context.md` description file (R7).
5. SYSTEM.md instruction (`~/notes/satan/prompts/interactive.txt`) to call it.
6. Tests: VT-run-assemble-context, VT-broker-spawn-integration,
   VT-mcp-boot-context-{render,suppress,sideeffects,degraded}, VH-mcp-boot-live.

### Open questions (DR-007 §8)

- Register `satan_boot_context` globally (inert in batch — leaning yes) vs
  interactive-only.
- pi MCP `protocolVersion` negotiation (carried from Phase 3).

### Commit state

- DR-007 + DE-007 revision committed: `8eeffc6`. Worktree clean for DE-007.
- (Unrelated untracked file present: DE-005 phase-04.md — not this delta.)

---

## New Agent Instructions

- **Task card**: DE-007 (`.spec-driver/deltas/DE-007-satan_interactive_pi_dev_mcp_harness/`).
  Parent delta + this `notes.md` are the onboarding pair.
- **Required reading** (in order):
  - This `notes.md` "Phase 4" + "New Agent Instructions" sections.
  - `DR-007.md` §3a + DEC-13 + DEC-8/DEC-9 + §5 (verification) + §8 (open Qs)
    + §9 (rollout: boot latency).
  - `DE-007.md` O6, risks R9/R10/R11.
- **Key files** (code, to read before implementing):
  - `satan/dl-satan-broker.el` ~675–790 (`--spawn` prepare-sequence — extraction source)
  - `satan/dl-satan-context.el` ~300–420 (`--render-prompt` / context-fn pattern)
  - `satan/dl-satan-percept.el` ~45–101 (`percept-build` — reads only run_id/time_now)
  - `satan/dl-satan-resonance.el` (derive — READ-ONLY, stub-injectable)
  - `satan/dl-satan-mcp.el` (interactive mode reg, `mint-session` :time_now freeze, dispatch)
  - `satan/dl-satan-run.el` (zero-dep — do NOT put the assembler here)
  - `~/notes/justfile` (`build-system-prompt`, `hello-satan`), `~/notes/.pi/SYSTEM.md`
- **Relevant doctrine**: POL-001 (trust boundary stays in Emacs — satisfied:
  assembly broker-side, tool returns text). DRY / no-parallel-implementation
  (CLAUDE.md) — drives the Option-1 extraction.
- **Relevant memory**: `feedback_subagent_worktree_pinning` (pin absolute repo
  paths in any dispatch subagent prompt).
- **User decisions (do not relitigate)**: tool-delivery (not SYSTEM.md compose);
  full-parity content; build-depth β; Option-1 shared extraction; external
  review via codex MCP (separate billing — ask before re-tapping).
- **Cross-repo note**: elisp lives in `~/.emacs.d`; prompts/justfile/extension
  live in `~/notes` (separate repo). Phase 3 already spans both. New `.el` files
  are invisible to the Nix flake parser until `git add` + `home-manager switch`
  (AGENTS.md trap 1).
- **Loose ends / tensions for the next agent to assess (don't skip)**:
  - R11 (vacuous DEC-8 guard) is a real pre-existing bug, now a Phase-4
    prerequisite — confirm scope appetite before coding (it may warrant its own
    backlog issue if the user wants boot-context shipped without it).
  - R10 extraction contract is the riskiest mechanical step — pin keys first.
  - Global-vs-interactive-only tool registration still open.

### Next step

Invoke `/using-spec-driver` → route to `/plan-phases` for DE-007 to create the
Phase 4 IP objectives/gates + `phases/phase-04.md` (note: there is currently no
phase-03.md; Phase 3 was tracked inline in this notes file). Carry R10/R11 as
explicit phase gates, not afterthoughts.
