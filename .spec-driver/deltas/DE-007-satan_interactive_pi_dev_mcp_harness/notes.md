# Notes for DE-007

## Phase 1 — COMPLETE (2026-05-31)

All five spike questions validated in live pi↔Emacs test. DEC-12 approach (TS
Extension over node-net UDS) confirmed working. No surprises. See §DEC-12 Spike
below for details. Uncommitted: `phases/spike/satan-extension-spike.ts` (new file).

## Phase 1 — Gating spike & transport contract freeze (history)

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
  `dl-satan-jsonl` line framing in the real module. *(Pi-side framing confirmed
  only once pi connects — task 1.3 remainder.)*
- **`tools/call.arguments` arrives as a keyword-plist** whose keys match the tool
  schema (`:msg` extracted directly). Confirms DR-007's claim: no
  JSON-object→plist normalization layer — parse via the shared plist parser and
  pass straight to `dl-satan-tool-dispatch`. (Resolves Codex #2.)
- MCP protocol version advertised: `2025-06-18` (adjust if pi negotiates a
  different one).

### DEC-12 Spike — `.pi/extensions/satan.ts` over node-net UDS (2026-05-31)

Spike artefact: `phases/spike/satan-extension-spike.ts` (~265 LOC, ~100 net-new
without comments/whitespace).

**Architecture:**

```
pi process (jail)
  .pi/extensions/satan.ts
    McpClient class — newline-delimited JSON-RPC 2.0 over node `net`
      connect() → request("initialize") → notify("notifications/initialized")
      request("tools/list") → dynamic pi.registerTool() per tool
      each tool's execute() → request("tools/call", {name, arguments})
    │
    ▼ UNIX-CONNECT:<bind-mounted mcp.sock>
  Emacs dl-satan-mcp (Phase 2)
    └─ dl-satan-tool-dispatch → handlers
```

**Key components:**

1. **`McpClient`** (~70 LOC): Promise-based MCP transport over `node:net`.
   Single-request (no multiplexing — pi serialises tool calls). Handles
   newline-delimited framing, partial-line accumulation, timeout (30s),
   connection-loss cleanup (rejects all pending).

2. **`jsonSchemaToTypeBox()`** (~30 LOC): Runtime JSON Schema → TypeBox
   converter. Handles the SATAN subset: string/enum/pattern, integer, boolean,
   number, object (nested properties with required/optional), array (items).
   Falls back to `Type.Any()` for unrecognised types. Broker-side validation is
   the real authority; TypeBox is for pi's tool UI + schema hints.

3. **Extension lifecycle**: `session_start` → connect + handshake + register
   tools. `session_shutdown` → disconnect. `/satan-ping` command for diagnostics.

**Spike answers:**

| Q | Answer |
|---|--------|
| Q1: `net.createConnection(UDS)` in bwrap? | ✅ **PROVEN.** Connected from jailed-pi to `/run/user/1000/satan-mcp-smoke.sock` via bind-mount. Sub-second connect. |
| Q2: Dynamic `pi.registerTool()` in `session_start`? | ✅ **PROVEN.** `satan_smoke_echo` registered at `session_start` and callable same session without `/reload`. |
| Q3: JSON Schema → TypeBox at runtime? | ✅ **PROVEN.** `{msg: {type: "string"}}` converted correctly — tool accepted `msg` arg. Enum support untested (mcp-smoke has no enums). |
| Q4: Newline-delimited JSON-RPC Node↔Emacs? | ✅ **PROVEN.** Identical framing — no framing issues in multi-message test. |
| Q5: `tools/call` round-trip in pi's timeout? | ✅ **PROVEN.** Sub-second round-trip for trivial handler. Real handlers TBD in Phase 3. |

**Live test transcript (2026-05-31):**

```
# Emacs side: mcp-smoke.el running on /run/user/1000/satan-mcp-smoke.sock
# Pi side: jailed-pi -e phases/spike/satan-extension-spike.ts
# Jail env: XDG_RUNTIME_DIR=/run/user/1000, UDS bind-mounted

> call satan_smoke_echo with msg "hello from pi extension"
→ echo: hello from pi extension — smoke test round-trip
```

**Surprises / adaptations:**

- **UDS bind-mount:** The UDS file must be explicitly bind-mounted into the
  jailed-pi sandbox. `XDG_RUNTIME_DIR` is already present; the socket path
  resolves fine once the file is visible. Phase 3 jail profile needs the
  `--bind` for the socket.

**Remaining to-verify (deferred to Phase 2/3):**

- `Type.Literal()` for string enums — mcp-smoke has no enum tools.
  Test with real SATAN tools that use `:enum` (e.g. `notify_send` urgency).
- `isError` mapping from MCP result → pi tool result — mcp-smoke always returns
  `ok`. Test with a failing call (unknown tool, validation error).
- Multi-tool registration — mcp-smoke has 1 tool. Real SATAN has ~30+.
  Verify all register and none collide with pi built-ins.
- Cold-start tool handler latency — real handlers (e.g. `memory_resonate`
  hitting postgres) may exceed 30s timeout. Tune `MCP_TIMEOUT_MS`.

**Pi integration notes:**

- `.pi/extensions/satan.ts` → auto-discovered by pi (project-local extension).
- Extension runs untrusted → holds no authority; Emacs UDS validates every call.
- The `// @earendil-works/pi-coding-agent` import is available in pi's runtime.
- `node:net` and `node:fs` built-ins are available.

### R6 RESOLVED — pi-side front-end = TS Extension over node-net UDS (DEC-12)

User intel on pi's integration seams:
- MCP-client package wraps `@modelcontextprotocol/sdk` → transports are
  Stdio / StreamableHTTP / SSE. **No native UDS.**
- **Extension API** (`@earendil-works/pi-coding-agent`): `defineTool` +
  `registerTool`, lifecycle hooks, commands. Extensions live in `.pi/extensions/*.ts`.
- Node `net` has UDS/IPC support → an extension can dial a unix socket directly.

**Decision (DEC-12):** write `.pi/extensions/satan.ts` — a small node-`net` UDS
client that speaks MCP to `dl-satan-mcp` and `registerTool`s each SATAN tool into
pi. **No socat, no stdio-command dependency, no HTTP server.** Fewest runtime
parts; the extension's lifecycle hooks seed Option C. The extension is
SATAN-agnostic (generic MCP-over-UDS→pi bridge) and runs in-jail/untrusted —
trust boundary unchanged (Emacs validates every call).

Wiring (Phase 3):
- Emacs hosts the real `dl-satan-mcp` UDS at a hardened path (DEC-10).
- Bind-mount that UDS file into the jail at in-jail path `Q`.
- `.pi/extensions/satan.ts`: `net.createConnection({path: Q})` → MCP
  `initialize`/`tools/list` → `registerTool` per tool; `execute` → `tools/call`.
- Alternatives kept in pocket: (i) socat+MCP-package; (iii) Emacs HTTP/SSE+package.

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

# user notes:

phases/spike/satan-extension-spike.ts - trivially written. needs
typebox types. wrapping each elisp tool with type-safe calls would be
easy as (deepseek has run ahead and is doing it now.)

took literally less time and effort than I've seen it take to balance
parentheses on a single elisp function :rolleyes:
