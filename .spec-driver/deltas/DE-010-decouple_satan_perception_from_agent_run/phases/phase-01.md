---
id: IP-010-P01
slug: "010-decouple_satan_perception_from_agent_run-phase-01"
name: IP-010 Phase 01
created: "2026-06-09"
updated: "2026-06-09"
status: draft  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-010
delta: DE-010
---

# Phase 1 - Perceive/consume seam

## 1. Objective

Cut the SATAN tick at the perceive/consume seam: lift perceive (percept-build +
persist + probe **read-snapshot**) out of `broker--spawn` to **before the
session/budget gates** in `broker-run`, fixing ISSUE-001 at the root. Split each
probe into a pure read (perceive) and a commit (consume). Mirror `:percept` into
`bundle.json` on both denial paths. Keep the MCP interactive-boot bundle
byte-stable. No cursor yet (Phase 2).

## 2. Links & References

- **Delta**: DE-010 §3 (Scope), §5 (Approach)
- **Design Revision Sections**: DR-010 §3 (Target control flow, perceive/consume
  boundary, side-effect definition), §4 (Code Impact), §5 (Verification
  Alignment), §7 (DEC-perceive-boundary, DEC-probes-read-commit-split,
  DEC-budget-denied-mirror-percept)
- **Specs / PRODs**: none — doc-canon (DEC-spec-authority-stays-doc)
- **Support Docs**: `docs/satan/perceptual-design.md` §S1 (`broker--prepare`
  sequence), `docs/satan/architecture.md` (Invocation/Broker/State layers)

## 3. Entrance Criteria

- [x] DR-010 accepted (2026-06-09)
- [x] Percept-build is already deterministic in `broker--prepare` (extraction target identified)

## 4. Exit Criteria / Done When

- [ ] perceive runs after run-dir creation, **before** the session/budget gates
- [ ] budget-denied AND session-blocked ticks write `percept.json`
- [ ] both denial paths mirror `:percept` into `bundle.json`
- [ ] each probe is split: read-snapshot at perceive (no mutation), charge +
      watermark-advance at consume
- [ ] `assemble-context` split into perceive (percept/sensor_status/probe-read)
      and consume-side resonance/motive enrichment; MCP interactive-boot calls
      both in order
- [ ] VT-budget-denied-perceives, VT-perceive-pure, VT-probe-split green
- [ ] VT-percept-golden, VT-mcp-bundle (regression) green
- [ ] exactly one percept builder remains (no parallel implementation)
- [ ] `just check` green

## 5. Verification

- `bin/elisp-locate-paren-error FILE` after each `.el` edit → `{"ok":true}`
  before byte-compile/tests.
- New: VT-budget-denied-perceives (budget-denied + session-blocked write
  percept.json + mirror `:percept`), VT-perceive-pure (perceive starts no
  LLM/harness process, dispatches no tool, enqueues no attr event, advances no
  probe/ingest cursor; read-only git/bough call-process probes allowed),
  VT-probe-split (read snapshots, commit charges + advances watermark,
  budget-denied loses no signal).
- Regression: VT-percept-golden (percept-build golden survives split),
  VT-mcp-bundle (interactive-boot bundle byte-stable).
- `just check` green (commit gate).

## 6. Assumptions & STOP Conditions

- Assumptions: percept-build in `--prepare` is the sole builder and is already
  side-effect-free apart from its `percept.json` write; consumers read
  `:percept` from `bundle.json`, not the sidecar.
- STOP when: a second percept builder is discovered (decide extract-vs-unify
  before proceeding); or the probe read/commit split cannot preserve ADR-002
  charge cadence without consume-side state (raise via `/consult`).

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description                                                        | Parallel? | Notes |
| ------ | --- | ----------------------------------------------------------------- | --------- | ----- |
| [ ]    | 1.1 | Lift perceive before the gates in `broker-run`; mkdir run-dir first | [ ]     | ISSUE-001 root |
| [ ]    | 1.2 | Mirror `:percept` into `bundle.json` on budget-denied + session-blocked | [ ] | DEC-budget-denied-mirror-percept |
| [ ]    | 1.3 | Split `assemble-context` → perceive + consume-side enrichment      | [P]       | feeds 1.4 |
| [ ]    | 1.4 | Probe read/commit split across sensor-{curiosity,content,wpm}      | [P]       | preserves ADR-002 cadence |
| [ ]    | 1.5 | MCP interactive-boot: call perceive + enrichment in order          | [ ]       | VT-mcp-bundle |
| [ ]    | 1.6 | Verification: author/run VTs; `just check`                        | [ ]       | exit gate |

### Task Details

- **1.1 Lift perceive before the gates**
  - **Design / Approach**: in `broker-run`, create the run-dir, then call
    perceive (percept-build + persist + probe read-snapshot) before the session
    and budget gates. perceive error → terminal status artifact.
  - **Files / Components**: `satan/dl-satan-broker.el` (`broker-run`,
    `broker--spawn`, `broker--prepare`).
  - **Testing**: VT-budget-denied-perceives, VT-perceive-pure.

- **1.2 Mirror `:percept` into denial bundles**
  - **Design / Approach**: `--write-budget-denied-run` + the session-blocked
    branch write the slim bundle with `:percept` mirrored from perceive.
  - **Files / Components**: `satan/dl-satan-broker.el`.
  - **Testing**: VT-budget-denied-perceives.

- **1.3 Split `assemble-context`**
  - **Design / Approach**: perceive = percept + sensor_status + probe-read;
    consume = resonance/motive enrichment. Single builder; no duplicate.
  - **Files / Components**: `satan/dl-satan-context.el` (`assemble-context`,
    `context-interactive`).
  - **Testing**: VT-percept-golden.

- **1.4 Probe read/commit split**
  - **Design / Approach**: each probe exposes a pure read-snapshot and a commit
    (charge + advance watermark). perceive reads; consume commits.
  - **Files / Components**: `satan/dl-satan-sensor-{curiosity,content,wpm}.el`.
  - **Testing**: VT-probe-split.

- **1.5 MCP recomposition**
  - **Design / Approach**: `context-interactive` calls perceive + enrichment in
    the same order so its bundle stays byte-stable.
  - **Files / Components**: `satan/dl-satan-context.el`.
  - **Testing**: VT-mcp-bundle.

- **1.6 Verification**
  - **Testing**: author the new VTs, run regressions, `just check`. Run
    `bin/elisp-locate-paren-error` after each edit.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| Second percept builder introduced | VT-percept-golden pins one builder; STOP condition | open |
| MCP bundle drifts | VT-mcp-bundle byte-stable assertion | open |
| Denial fix cosmetic (sidecar vs bundle) | mirror `:percept` into bundle (1.2) | open |
| Probe charge cadence shifts | read/commit split keeps charge at consume; VT-probe-split | open |

## 9. Decisions & Outcomes

- `2026-06-09` - Phase planned from accepted DR-010; structural cut only,
  cursor deferred to Phase 2.

## 10. Findings / Research Notes

- (populate during execution — `broker-run` gate ordering, probe call sites)

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored
- [ ] Spec/Delta/Plan updated with lessons
- [ ] Hand-off notes to Phase 2 (cursor)
