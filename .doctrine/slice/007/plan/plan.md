# Implementation Plan for SL-007

```yaml supekku:plan.overview@v1
schema: supekku.plan.overview
version: 1
plan: IP-007
delta: DE-007
revision_links:
  aligns_with: []
specs:
  primary: []
  collaborators: []
requirements:
  targets: []
  dependencies: []
phases:
- id: IP-007-P01
- id: IP-007-P02
- id: IP-007-P03
```

```yaml supekku:verification.coverage@v1
schema: supekku.verification.coverage
version: 1
subject: IP-007
entries:
  - artefact: VT-mcp-tools-list
    kind: VT
    status: planned
    notes: tools/list MCP defs match registry emitter; missing-description tool surfaced at start (fail-fast preserved).
  - artefact: VT-mcp-tools-call
    kind: VT
    status: planned
    notes: happy path + error mapping (unknown/not-allowed/capability-denied/arg-invalid → isError).
  - artefact: VT-mcp-jsonrpc
    kind: VT
    status: planned
    notes: initialize/ping shape; unknown method → -32601; malformed line → error, connection survives.
  - artefact: VT-mcp-session-lifecycle
    kind: VT
    status: planned
    notes: connect opens audit (synthetic bundle); calls append membrane records; disconnect closes with synthetic final status=completed.
  - artefact: VT-mcp-startup
    kind: VT
    status: planned
    notes: refuses on XDG_RUNTIME_DIR unset / non-0700 parent / symlink / live scheduled run / missing description.
  - artefact: VH-mcp-live-pi
    kind: VH
    status: planned
    notes: live pi session lists tools + executes one read + one owned-write; pi terminal stdio uninvolved; transcript shows calls.
  - artefact: VT-broker-spawn-integration
    kind: VT
    status: planned
    notes: (Phase 4 / R10) stubbed broker--spawn asserts call-order (observer → assemble-context → probes) + final prepare key set + bundle/percept/actions artifacts. Real regression net for the extraction.
  - artefact: VT-run-assemble-context
    kind: VT
    status: planned
    notes: (Phase 4 / R10) extracted dl-satan-run-assemble-context ≡ prior inline percept/resonance/motive/sensor_status threading.
  - artefact: VT-mcp-boot-context-render
    kind: VT
    status: planned
    notes: (Phase 4) satan_boot_context returns 7 dynamic blocks for stubs; persona scaffold absent (assembled="").
  - artefact: VT-mcp-boot-context-suppress
    kind: VT
    status: planned
    notes: (Phase 4) empty percept/resonance/motive → blocks self-suppress.
  - artefact: VT-mcp-boot-context-sideeffects
    kind: VT
    status: planned
    notes: (Phase 4) β skips observer/alerts/probes (assert not invoked); percept.json persisted; cache on re-call; refresh forces rebuild.
  - artefact: VT-mcp-boot-context-degraded
    kind: VT
    status: planned
    notes: (Phase 4 / F7) postgres-down → resonance block self-suppresses; capsule still renders; tool does not error.
  - artefact: VT-dec8-mutual-exclusion
    kind: VT
    status: planned
    notes: (Phase 4 / R11) session refuses while scheduled run live AND scheduler refuses while session open; flag cleared on unwind/error.
  - artefact: VH-mcp-boot-live
    kind: VH
    status: planned
    notes: (Phase 4) live pi calls satan_boot_context unprompted on first turn; orientation renders; no desktop notification on boot.
```

## 1. Summary

- **Delta**: DE-007 — SATAN interactive pi.dev MCP harness.
- **Design**: [DR-007](./DR-007.md) (verified; codex-reviewed).
- **Specs Impacted**: none registered as spec-driver entities; canon =
  `docs/satan/architecture.md`, `docs/satan/protocol.md`, `satan/dl-satan-tools.el`.
- **Desired Outcome**: a long-lived, human-supervised `pi.dev` session calls
  broker-owned SATAN tools over an Emacs-hosted MCP server on a unix-domain
  socket, with validation + audit enforced broker-side (Option A; C-seam intact).

## 2. Context & Constraints

- **Current Behaviour**: only reasoning path is the batch jailed-python harness
  whose stdio is the JSONL membrane (`docs/satan/protocol.md`).
- **Target Behaviour**: second path — `dl-satan-mcp` MCP server over UDS;
  `tools/call` → `dl-satan-tool-dispatch`; per-session audit run.
- **Dependencies**: none blocking. **R6 gating spike must complete before the
  jail/launcher work** (Phase 3); Phase 2 elisp may proceed once the MCP framing
  is frozen by the spike.
- **Constraints**: POL-001 (trust boundary in Emacs); DRY (reuse dispatch,
  schema emitter, jsonl, audit, tool-ctx); no batch-path regression; commit gate
  `just check` green (AGENTS.md).

## 3. Gate Check

- [x] Design complete + reviewed (DR-007, codex pass integrated).
- [x] Reuse targets confirmed against code (dispatch, schema emitter, jsonl, audit, mode-register).
- [x] Test strategy identified (ert unit suite + one VH live test).
- [x] Workspace/config changes assessed (new `.el` → flake parser + `home-manager switch`; jail profile in `~/flakes`).
- [x] R6 gating spike resolved (Phase 1 exit — DEC-12).

## 4. Phase Overview

| Phase | Objective | Entrance | Exit / Done When | Phase Sheet |
| --- | --- | --- | --- | --- |
| Phase 1 — Gating spike & contract freeze | Resolve R6; freeze MCP framing; audit handlers for run-state globals (Codex #7); prove Emacs UDS MCP server | DE/DR accepted | **DONE** — R6 resolved (DEC-12 extension), framing newline, handler audit clean, Emacs side proven by batch self-test (`notes.md`); contract frozen | `phases/phase-01.md` |
| Phase 2 — Emacs MCP server + tests | Promote the smoke stub to real `dl-satan-mcp.el` (defcustoms, interactive mode-spec, 5-method JSON-RPC over UDS, tools/list, tools/call, session lifecycle w/ synthetic bundle+final, mutual-exclusion guard, current-run-id binding, socket hardening) + ert suite | Phase 1 done | `dl-satan-mcp-start/-stop` work; ert VT-mcp-* green; `just check` green; no pi needed | `phases/phase-02.md` |
| Phase 3 — pi extension, jail bind-mount, launcher, live VH | `.pi/extensions/satan.ts` (node-net UDS → registerTool); `~/flakes` interactive jail variant bind-mounting the UDS (no socat); `interactive.txt` prompt; `my/satan-mcp-pi-session` launcher; `home-manager switch`; live integration | Phase 2 green | VH-mcp-live-pi passes; CHANGELOG updated | `phases/phase-02.md` |
| Phase 4 — interactive boot context + DEC-8 guard | R11/DEC-8 real mutual-exclusion guard (both directions); R10 extract `dl-satan-run-assemble-context` (contract-pinned, batch ert green); `dl-satan-context-interactive` `:context-fn`; `satan_boot_context` tool (global reg, cache/refresh, fresh-stamp, graceful degrade) + description file; SYSTEM.md instruction (`~/notes`) | Phase 3 green; DEC-13 committed | DEC-8 both-direction VT green; extraction batch ert green; boot-context VTs green; VH-mcp-boot-live passes; CHANGELOG updated | `phases/phase-03.md` |

## 5. Phase Detail Snapshot

- **Research Notes**: `DE-007/notes.md` (Phase 1 spike output).
- **Design Revision**: `DR-007.md`.
- **Active Phase Sheet**: `phases/phase-03.md` (Phase 4 — boot context + DEC-8 guard).
- **Parallelisable Work**: within Phase 2, tool-list and tool-call paths can be
  built/tested in parallel once the JSON-RPC scaffold lands. Flag `[P]` in sheet.

## 6. Testing & Verification Plan

- **New Suite**: `satan/test/dl-satan-mcp-test.el` — VT-mcp-tools-list,
  -tools-call, -jsonrpc, -session-lifecycle, -startup (reuse `dl-satan-tools-test`
  stub fixtures).
- **Regression**: existing batch-harness ert + `dl-satan-protocol` tests must
  still pass (no membrane/dispatch change).
- **Live (VH)**: VH-mcp-live-pi via `my/satan-mcp-pi-session`.
- **Tooling/Fixtures**: reuse stub tools; a fake MCP client (feed JSON-RPC lines
  to the process filter) for unit tests — no socat/pi in unit layer.
- **Rollback**: `dl-satan-mcp-enabled` off → no socket/listener; batch path
  unaffected.

## 7. Risks & Mitigations

(See DE-007 risk register R1–R8 for full text.) Phase-critical:

| Risk | Mitigation | Phase |
| --- | --- | --- |
| R6 — pi reach to external tool channel | RESOLVED: TS extension over node-net UDS (DEC-12); Emacs side proven | 1 ✓ |
| R5/DEC-7+8 — reentrancy / global run-id | Mutual-exclusion guard + bind-around-dispatch | 2 |
| R7 — missing tool description breaks tools/list | Preserve fail-fast; startup precondition refuses | 2 |
| R8/DEC-11 — unauth socket, full toolbox | Accepted (single-user); 0700/randomized/anti-symlink hardening | 2 |
| Codex #3 — nil final → "invalid" run | Synthetic bundle + synthetic final on close | 2 |
| R11 — DEC-8 guard vacuous (`--spawn-running` never set) | Phase-4 prereq: set/clear around `broker--spawn` + session-active flag; both-direction VT | 4 |
| R10 — assemble-context extraction regresses batch path | Characterization `VT-broker-spawn-integration` BEFORE refactor; pin return-key contract | 4 |
| R9 — boot build freezes live editor | β-core lean; graceful degrade (F7); async assembly = follow-up | 4 |

## 8. Open Questions & Decisions

- [x] R6 — RESOLVED (DEC-12): TS extension over node-net UDS; Emacs side proven.
- [x] Transport front-end (DEC-12) + framing (newline) decided.
- [x] Socket auth (DEC-11) — ACCEPT same-user risk on single-user box.
- [x] In-jail UDS bind-mount path + `XDG_RUNTIME_DIR` visibility in bwrap (Phase 3 — confirmed).
- [ ] pi negotiated MCP `protocolVersion` vs server advertise (observe at next live VH).
- [x] `satan_boot_context` registration scope — RESOLVED **global** (user, 2026-06-03; DR-007 §8).
- [x] Boot-context assembler placement — RESOLVED `dl-satan-context.el`, not zero-dep `dl-satan-run.el` (DR-007 F4).

## 9. Progress Tracking

- [x] Phase 1 complete (spike + contract freeze) — `phases/phase-01.md`
- [x] Phase 2 complete (MCP server + ert green) — `7a6ee78`
- [x] Phase 3 complete (extension/jail/launcher/live VH) — `phases/phase-02.md`, `8c4ab80`
- [ ] Phase 4 complete (boot context + DEC-8 guard) — `phases/phase-03.md`
- [ ] Verification gates passed

## 10. Notes / Links

- Audit reference: AUD-XXX (pending close).
- `satan/dl-satan-tools.el:153,202,291`; `dl-satan-broker.el:264`; `dl-satan-audit.el:109`; `dl-satan-mode.el:42`; `dl-satan-jsonl.el:82`.

```

```
