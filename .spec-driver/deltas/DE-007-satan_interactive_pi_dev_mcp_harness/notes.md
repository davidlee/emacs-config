# Notes for DE-007

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

- `home-manager switch` to pick up new .el + flake change
- Live VH test (VH-mcp-live-pi): start server, run jailed-pi with extension,
  call read + write tools, verify transcript
- CHANGELOG update
- Commit + push
