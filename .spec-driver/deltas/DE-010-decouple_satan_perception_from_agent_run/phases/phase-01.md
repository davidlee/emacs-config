---
id: IP-010-P01
slug: "010-decouple_satan_perception_from_agent_run-phase-01"
name: IP-010 Phase 01
created: "2026-06-09"
updated: "2026-06-09"
status: in-progress  # one of: completed | deferred | draft | in-progress | pending
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

- [x] perceive runs after run-dir creation, **before** the session/budget gates
- [x] budget-denied AND session-blocked ticks write `percept.json`
- [x] both denial paths mirror `:percept` into `bundle.json`
- [x] each probe is split: read-snapshot at perceive (no mutation), charge +
      watermark-advance at consume
- [x] `assemble-context` split into perceive (percept/sensor_status/probe-read)
      and consume-side resonance/motive enrichment; MCP interactive-boot calls
      both in order
- [x] VT-budget-denied-perceives, VT-perceive-pure, VT-probe-split green
- [x] VT-percept-golden, VT-mcp-bundle (regression) green
- [x] exactly one percept builder remains (no parallel implementation)
- [x] `just check` green

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
| [x]    | 1.1 | Lift perceive before the gates in `broker-run`; mkdir run-dir first | [ ]     | done — `--write-no-child-run`; perceive-first; perceive-failed path |
| [x]    | 1.2 | Mirror `:percept` into `bundle.json` on budget-denied + session-blocked | [ ] | done — session-blocked now writes full bundle, no rename/announce |
| [x]    | 1.3 | Split `assemble-context` → perceive + consume-side enrichment      | [P]       | done — `run-perceive`/`run-enrich`; `assemble-context = enrich∘perceive` |
| [x]    | 1.4 | Probe read/commit split across sensor-{curiosity,content,wpm}      | [P]       | done — read∘commit wrappers; curiosity high-water bugfix; perceive threads :probe_snapshots |
| [x]    | 1.5 | MCP interactive-boot: call perceive + enrichment in order          | [ ]       | done — byte-stable; new VT-mcp-bundle pins interactive boot |
| [x]    | 1.6 | Verification: author/run VTs; `just check`                        | [ ]       | done — 982/991, +10 VTs, 0 unexpected |

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

- **Assumptions verified (preflight, 2026-06-09):**
  - A1 sole builder: `dl-satan-percept-build` (percept.el:45) has one prod
    caller — `dl-satan-run-assemble-context` (context.el:45). No parallel builder.
  - A2 consumers read bundle.json:percept: observer-classify.el:37,58 + broker.el:285.
    Zero `percept.json` reads ⇒ task 1.2 mirror is required, not cosmetic.
  - A3 percept ⊥ observer: percept-build reads evidence assembler (sensors/git/
    bough) + pure canon; never `:observer`. Lifting percept above observer is safe.
    (It is *motive*, consume-side, that needs observer-first — broker.el:733.)
  - A4 interactive: context-interactive (context.el:577) calls assemble-context,
    NOT observer-process; degrades to :percept nil on error.
- **Gate ordering:** broker-run:658 → session gate 678 → budget gate 687 →
  spawn 693. --spawn:695 builds percept at assemble (755); probes charge 770/776/782.
- **Probe shapes:** content already returns `(count . high-water)` + advances to
  high-water verbatim (DEC-5) — the target pattern. curiosity returns count only +
  advances to wall-clock `ts` (out-of-order end_ts rows skipped — DR §3 bug to fix:
  track max end_ts, advance to it). wpm snapshot = classified state + prev.
- **Audit verifier:** `dl-satan-audit-verify-run` (audit.el:694) requires
  has-bundle + status-terminal ∈ {done,failed,timed-out,invalid-protocol,
  budget-exceeded}. session-blocked NOT terminal ⇒ reuse `failed`.
- **DECISION (session-blocked, user 2026-06-09):** unify via shared
  `broker--write-no-child-run`; session-blocked → status `failed` reason
  `session_blocked`, bundle+percept.json+bundle.json:percept (verify-clean), but
  **NO .FAILED rename, NO failure notification** (intentional deferral, not a
  failure — avoids desktop-alert noise + failure-streak pollution). budget-denied
  + perceive-failed keep .FAILED+announce.
- **Caller census:** assemble-context prod = broker.el:755 + context.el:612; 3
  test stubs. probes prod = broker.el:770/776/782; content-test (9×) + broker-test
  stub. ⇒ keep `assemble-context = enrich∘perceive` + `-probe = commit∘read`
  wrappers for DRY + test continuity.
- **Build order (deps, not sheet numbering):** 1.3 → 1.1+1.2 → 1.4 → 1.5 → 1.6.
  dec8 test (broker-test.el:731) stubs assemble-context + -probe; restub when
  consume internals change.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored
- [ ] Spec/Delta/Plan updated with lessons
- [ ] Hand-off notes to Phase 2 (cursor)
