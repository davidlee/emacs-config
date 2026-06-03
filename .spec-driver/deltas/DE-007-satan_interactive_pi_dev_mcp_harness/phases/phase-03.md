---
id: IP-007-P03
slug: "007-satan_interactive_pi_dev_mcp_harness-phase-03"
name: IP-007 Phase 4 — interactive boot context + DEC-8 guard
created: "2026-06-03"
updated: "2026-06-03"
status: in-progress  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-007
delta: DE-007
---

# Phase 4 — interactive boot context + DEC-8 guard

## 1. Objective

Fill the DEC-9 `:context-fn` seam: give the interactive pi session per-session
orientation (the seven dynamic blocks batch runs get via `bundle.json`) through a
`satan_boot_context` read tool at **build-depth β** (DEC-13). Two prerequisites
ride in front of it because DEC-13's reentrancy safety depends on them:

- **R11 / DEC-8** — actually implement the mutual-exclusion guard (currently
  vacuous: `dl-satan-broker--spawn-running` is read, never set).
- **R10** — extract `dl-satan-run-assemble-context` **behaviour-preservingly**
  from `broker--spawn`, pinned by a real call-order/key regression net.

## 2. Links & References

- **Delta**: DE-007 (O6; risks R9, R10, R11)
- **Design Revision Sections**: DR-007 §3a (interactive boot context), DEC-13
  (build-depth β + extraction), DEC-8 (mutual exclusion), DEC-9 (`:context-fn`
  seam), §5 (verification rows), §8 (open Qs — registration RESOLVED global),
  §9 (boot-context latency + graceful degrade)
- **Specs / PRODs**: none registered; canon = `docs/satan/architecture.md`,
  `docs/satan/protocol.md`, `satan/dl-satan-tools.el`
- **Support Docs / key code** (read before implementing):
  - `satan/dl-satan-broker.el` ~675–790 (`--spawn` prepare-sequence — extraction
    source; threads `:evidence`/`:percept`/`:resonance`/`:motive`/`:sensor_status`/
    `:pre_spawn` via nested `plist-put` 762–772)
  - `satan/dl-satan-context.el` ~300–420 (`--render-prompt` / context-fn pattern;
    **assembler lives here**, NOT in zero-dep `dl-satan-run.el` — DR-007 F4)
  - `satan/dl-satan-percept.el` ~45–101 (`percept-build` — reads only
    `:run_id`/`:time_now`; observer-independent)
  - `satan/dl-satan-resonance.el` (`-derive` — READ-ONLY, stub-injectable;
    `memory-unreachable` on postgres-down)
  - `satan/dl-satan-mcp.el` (interactive mode reg, `mint-session` `:time_now`
    freeze @149, dispatch path, `--spawn-running` reads @146,376)
  - `satan/dl-satan-memory-store.el:14` (`memory_resonate` read-only, no state
    mutation — boot records no activation write)
  - `~/notes/justfile` (`build-system-prompt`, `hello-satan`), `~/notes/.pi/SYSTEM.md`,
    `~/notes/satan/prompts/interactive.txt`
- **Doctrine**: POL-001 (trust boundary in Emacs — satisfied: assembly
  broker-side, tool returns text). CLAUDE.md DRY / no-parallel-implementation —
  drives the Option-1 extraction.
- **Memory**: `feedback_subagent_worktree_pinning` (pin absolute repo paths in any
  dispatch subagent prompt).

## 3. Entrance Criteria

- [x] Phase 3 green (`dl-satan-mcp.el` live; VH-mcp-live-pi passed; `just check` green).
- [x] DR-007 / DE-007 DEC-13 revision committed (`8eeffc6`, `eb0f044`); worktree
      clean for DE-007.
- [x] Registration-scope open Q resolved: **global** `dl-satan-tool-register`
      (user, 2026-06-03; DR-007 §8).
- [x] Assembler placement resolved: `dl-satan-context.el` (existing heavy-dep
      module), NOT `dl-satan-run.el` (DR-007 F4).

## 4. Exit Criteria / Done When

- [ ] **DEC-8 guard is real**: `dl-satan-broker--spawn-running` set/cleared around
      `broker--spawn`; a session-active flag the scheduler checks; exclusion proven
      **both** directions by test (session refuses while scheduled run live; scheduler
      refuses while session open). (R11)
- [ ] **`dl-satan-run-assemble-context` extracted** into `dl-satan-context.el`; the
      exact return contract pinned (keys it threads vs caller-threaded); batch ert
      stays green; `VT-broker-spawn-integration` (call-order + final prepare key set +
      artifacts) passes. (R10)
- [ ] **`dl-satan-context-interactive`** context-fn registered as the interactive
      mode's `:context-fn`; renders via `dl-satan-context--render-prompt` with
      `assembled=""` (blocks only, no persona).
- [ ] **`satan_boot_context`** registered globally (read; `refresh` arg); handler
      resolves the interactive mode, calls `:context-fn` over the live session
      run-ctx, returns the seven dynamic blocks as text; per-session capsule cache +
      explicit `refresh`; build stamps a **fresh `current-time`** (not the frozen
      session `:time_now`).
- [ ] **`satan_boot_context.md`** description file present under
      `dl-satan-tools-descriptions-dir` (R7 fail-fast precondition; otherwise the
      server refuses to start).
- [ ] **β side-effect discipline**: build persists `percept.json` only; `observer-process`,
      `sensor-alerts-check`, and curiosity/content/wpm probes are NOT invoked on boot.
- [ ] **Graceful degrade**: backend outage (postgres-down) yields a partial capsule
      (resonance block self-suppresses), not an errored tool call. (F7)
- [ ] **SYSTEM.md instruction**: `~/notes/satan/prompts/interactive.txt` tells pi to
      call `satan_boot_context` on its first turn (cross-repo).
- [ ] ert suite green: VT-run-assemble-context, VT-broker-spawn-integration,
      VT-mcp-boot-context-{render,suppress,sideeffects,degraded}.
- [ ] **VH-mcp-boot-live**: live pi calls `satan_boot_context` unprompted on first
      turn, renders current orientation; no desktop notification fires on boot.
- [ ] `just check` green; CHANGELOG updated; commit.

## 5. Verification

| ID | Kind | Asserts |
| --- | --- | --- |
| (DEC-8 both-direction) | VT | session-open refuses scheduled spawn; live scheduled run refuses session open; flag cleared on unwind/sentinel error path |
| VT-run-assemble-context | VT | extracted core produces the same percept/resonance/motive/sensor_status threading the batch path produced inline |
| VT-broker-spawn-integration | VT | stubbed `broker--spawn`: **call order** (observer → assemble-context → probes/alerts) + **final `prepare` key set** (`:evidence`/`:percept`/`:resonance`/`:motive`/`:sensor_status`/`:pre_spawn`) + `bundle.json`/`percept.json`/`actions.json :pre_spawn` artifacts — the real net for R10 |
| VT-mcp-boot-context-render | VT | tool returns the 7 dynamic blocks for stub fixtures; persona scaffold **absent** (`assembled=""`) |
| VT-mcp-boot-context-suppress | VT | empty percept/resonance/motive → those blocks self-suppress (A4/A6/A8 parity) |
| VT-mcp-boot-context-sideeffects | VT | β skips observer-process / sensor-alerts-check / probes (assert NOT invoked); `percept.json` IS persisted; cache returned on re-call; `refresh` forces rebuild |
| VT-mcp-boot-context-degraded | VT | postgres-down → resonance `memory-unreachable` → block self-suppresses; rest renders; tool does NOT error the session |
| VH-mcp-boot-live | VH | live pi calls `satan_boot_context` unprompted on first turn; current orientation renders; no desktop notification on boot |
| (regression) batch harness ert + `dl-satan-protocol` | VT | still green — covers the assemble-context extraction |

- **Fixtures**: reuse `dl-satan-tools-test` stubs; stub-inject `resonance-derive`
  (read-only) for render/suppress/degraded; spy/counter on observer/alerts/probes
  for the sideeffects assertion.
- **Commands**: `bin/elisp-locate-paren-error FILE` after each `.el` edit →
  byte-compile → `just check`.

## 6. Assumptions & STOP Conditions

- **Assumptions**:
  - `percept-build` reads only `:run_id`/`:time_now` from prepare (notes.md handler
    audit; DR §3a) → the β-core is observer-independent.
  - `resonance-derive` is read-only v1 and stub-injectable; boot records no
    activation write (`memory-store.el:14`).
  - The assembler can live in `dl-satan-context.el` without dragging new heavy deps
    into `dl-satan-run.el`.
  - Edits land in EXISTING tracked `.el` files (no new `.el`) → live via
    `eval-buffer`/restart, NO `home-manager switch` needed for the parser. **If a new
    `dl-satan-context-assemble.el` is created instead, it must be `git add`-ed +
    `home-manager switch` (AGENTS.md trap 1).**
  - `satan_boot_context.md` description is read from disk at runtime (no nix wiring).
- **STOP and `/consult` when**:
  - Extraction cannot keep batch ert green without changing the `prepare` key
    contract (R10 turned out non-mechanical).
  - DEC-8 needs scheduler internals beyond a busy-flag + check (scope creep).
  - β "identical content" claim breaks for a block other than the documented motive
    gap (DR §3a parity caveat).
  - Boot-context build latency freezes the live editor unacceptably (R9 / §9) →
    revisit async-assembly follow-up appetite.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 4.1 | R11/DEC-8: make the mutual-exclusion guard real (both directions) | [ ] | prerequisite — DEC-13 reentrancy depends on it |
| [WIP] | 4.2 | R10: pin contract + `VT-broker-spawn-integration`, then extract `dl-satan-run-assemble-context` into `dl-satan-context.el` | [ ] | characterization test BEFORE extraction |
| [ ] | 4.3 | `dl-satan-context-interactive` context-fn + register `:context-fn` on interactive mode-spec | [ ] | depends on 4.2 |
| [ ] | 4.4 | `satan_boot_context` tool (global reg, `refresh` arg) + handler + capsule cache + fresh-timestamp build + graceful degrade | [ ] | depends on 4.3 |
| [ ] | 4.5 | `satan_boot_context.md` description file (R7) | [P] | independent of code once tool name fixed |
| [ ] | 4.6 | SYSTEM.md instruction in `~/notes/satan/prompts/interactive.txt` | [P] | cross-repo (`~/notes`) |
| [ ] | 4.7 | ert: VT-run-assemble-context + VT-mcp-boot-context-{render,suppress,sideeffects,degraded} | [ ] | DEC-8 + VT-broker-spawn-integration land in 4.1/4.2 |
| [ ] | 4.8 | VH-mcp-boot-live (live pi unprompted boot call) | [ ] | needs 4.4–4.6 + possibly `home-manager switch` if new file |
| [ ] | 4.9 | CHANGELOG + commit | [ ] | |

### Task Details

- **4.1 R11/DEC-8 — real mutual-exclusion guard**
  - **Design / Approach**: set `dl-satan-broker--spawn-running` truthy at the top of
    `broker--spawn` and clear it on completion via `unwind-protect` (synchronous
    portion) and/or the process sentinel (async portion) — match how `current-run-id`
    is already cleared. Add a session-active flag (e.g. `dl-satan-mcp--session-active`)
    set on connect / cleared on disconnect; the scheduler checks it before spawning,
    the MCP server checks `--spawn-running` before opening a session (the existing
    reads @146,376 become live). Both refusals must be graceful (logged, no crash).
  - **Files / Components**: `satan/dl-satan-broker.el` (set/clear), `satan/dl-satan-mcp.el`
    (session-active flag + existing guard reads), scheduler call-site.
  - **Testing**: both-direction VT + unwind/error-path clears the flag.
  - **Observations & AI Notes**: this is a pre-existing latent defect (notes.md F6);
    confirm with user it stays in-Phase-4 scope vs split to a backlog issue if boot
    context is wanted without it. Leaning: in-scope (DEC-13 depends on it).

- **4.2 R10 — extract assemble-context (contract-first)**
  - **Design / Approach**: FIRST write `VT-broker-spawn-integration` against the
    current inline `broker--spawn` (characterization: call-order + final `prepare`
    keys + artifacts) so it's green BEFORE refactor. THEN extract
    `dl-satan-run-assemble-context (prepare mode dir)` owning the observer-independent
    subset (`:percept`/`:resonance`/`:motive`/`:sensor_status` + persist + the
    `:evidence` derived from percept). `broker--spawn` keeps `observer-process`
    before and probes/`:pre_spawn` threading after. Pin which keys the function
    threads vs the caller threads in a docstring + the test. Place in
    `dl-satan-context.el` (DR F4).
  - **Files / Components**: `satan/dl-satan-context.el` (new fn), `satan/dl-satan-broker.el`
    (call the fn), test file.
  - **Testing**: VT-run-assemble-context (equivalence) + VT-broker-spawn-integration
    (sequence/keys/artifacts) + full batch ert regression.
  - **Observations & AI Notes**: riskiest mechanical step (DE-007 R10). Do not touch
    `dl-satan-run.el` (zero-dep invariant).

- **4.3 `dl-satan-context-interactive` context-fn**
  - **Design / Approach**: new context-fn that builds a fresh `current-time`,
    constructs a minimal prepare, calls `dl-satan-run-assemble-context` over the live
    session run-ctx, renders via `dl-satan-context--render-prompt` with
    `assembled=""` (persona already in SYSTEM.md → blocks only). Register it on the
    interactive mode-spec's `:context-fn` slot (DEC-9).
  - **Files / Components**: `satan/dl-satan-context.el` (or where context-fns live),
    `satan/dl-satan-mcp.el` (mode-spec registration).
  - **Testing**: exercised by VT-mcp-boot-context-render/suppress.

- **4.4 `satan_boot_context` tool + handler + cache**
  - **Design / Approach**: global `dl-satan-tool-register` (`:risk 'read`,
    `:args-schema` with optional `refresh`). Handler resolves the interactive
    mode-spec, calls its `:context-fn`, returns `(ok (:text MARKDOWN))`. Per-session
    capsule cache in session state; `refresh` forces rebuild; a re-call without
    `refresh` returns the cache and does NOT re-persist `percept.json` (F2). Wrap the
    build so a backend outage degrades to a partial capsule (F7). Stamp fresh
    `current-time`, not frozen `:time_now` (F3).
  - **Files / Components**: `satan/dl-satan-mcp.el` (handler + session cache),
    tool registration.
  - **Testing**: VT-mcp-boot-context-{render,suppress,sideeffects,degraded}.

- **4.5 `satan_boot_context.md` description**
  - **Design / Approach**: model-facing description under
    `dl-satan-tools-descriptions-dir`; satisfies R7 fail-fast precondition. Describe:
    returns per-session orientation (now/attributes/percept/attention/resonance/
    motive/sensors); call on first turn; `refresh` to force rebuild.
  - **Testing**: VT-mcp-startup precondition already covers presence; absence → refuse.

- **4.6 SYSTEM.md instruction (`~/notes`)**
  - **Design / Approach**: edit `~/notes/satan/prompts/interactive.txt` to instruct pi
    to call `satan_boot_context` on its first turn (and `refresh` only when
    re-orienting). Cross-repo; the `~/notes` justfile `build-system-prompt` cats it
    into `.pi/SYSTEM.md`.
  - **Testing**: VH-mcp-boot-live confirms pi calls it unprompted.

- **4.8 VH-mcp-boot-live**
  - **Design / Approach**: if any new `.el` file was created → `home-manager switch`
    first (trap 1). Start server; run jailed-pi; observe pi calls `satan_boot_context`
    on first turn; capsule renders current orientation; confirm NO desktop
    notification fired on boot; check `transcript.jsonl`.
  - **Testing**: end-to-end VH; capture transcript excerpt in notes.md.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| R11 — DEC-8 guard vacuous (pre-existing) | 4.1 set/clear + both-direction VT; confirm scope appetite with user | open |
| R10 — extraction regresses batch path | characterization VT-broker-spawn-integration BEFORE refactor; pin key contract | open |
| R9 — boot build freezes live editor | keep β-core lean; graceful degrade (F7); async assembly is a noted follow-up | accepted |
| F2 — fail-open re-call overwrites percept.json | session cache + explicit `refresh`; no silent rebuild | planned |
| F3 — stale frozen `:time_now` | build stamps fresh `current-time` | planned |
| F4 — assembler in zero-dep module | place in `dl-satan-context.el`, not `dl-satan-run.el` | planned |
| Cross-repo drift (`~/notes`) | 4.6 edits tracked; VH proves the wired SYSTEM.md | monitor |

## 9. Decisions & Outcomes

- `2026-06-03` — **Registration scope**: `satan_boot_context` registered **globally**
  (`dl-satan-tool-register`). Batch modes expose tools by explicit `:tools` list →
  inert in batch; only the interactive mode lists it. Keeps the uniform registration
  pattern. (User; DR-007 §8.)
- `2026-06-03` — **Assembler placement**: `dl-satan-context.el` (existing heavy-dep
  module), preserving `dl-satan-run.el`'s zero-heavy-dep invariant. (DR-007 F4.)

## 10. Findings / Research Notes

- See `notes.md` "Phase 4 — DESIGNED" + DR-007 §3a/DEC-13 for the full design rationale
  and the codex (gpt-5.5) 8-finding integration.
- Parity caveat (DR §3a): motive block is built without the in-tick `observer-process`
  pass batch runs first — shows last-persisted motive state. Deliberate, documented; not
  byte-parity.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored (ert output + VH transcript excerpt in notes.md)
- [ ] Spec/Delta/Plan updated with lessons (IP coverage statuses → done)
- [ ] Hand-off to `/audit-change` (delta close path)
