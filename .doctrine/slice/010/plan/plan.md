# Implementation Plan for SL-010

```yaml supekku:plan.overview@v1
schema: supekku.plan.overview
version: 1
plan: IP-010
delta: DE-010
revision_links:
  aligns_with:
    - DR-010
specs:
  primary: []
  collaborators: []
requirements:
  targets: []
  dependencies: []
phases:
  - id: IP-010-P01
  - id: IP-010-P02
```

```yaml supekku:verification.coverage@v1
schema: supekku.verification.coverage
version: 1
subject: IP-010
entries:
  - artefact: VT-budget-denied-perceives
    kind: VT
    requirement: ISSUE-001
    status: verified
    notes: "P01 (32c7dc9). dl-satan-broker/{budget-denied,session-blocked}-still-perceives: both write percept.json AND mirror :percept; session-blocked verify-clean (no .FAILED/announce)."
  - artefact: VT-perceive-pure
    kind: VT
    requirement: DEC-perceive-boundary
    status: verified
    notes: "P01 (32c7dc9). dl-satan-broker/perceive-is-pure: spies fail on make-process, dl-satan-tool-dispatch, attribute-enqueue, probe watermark writers; call-process (git/bough) allowed."
  - artefact: VT-probe-split
    kind: VT
    requirement: DEC-probes-read-commit-split
    status: verified
    notes: "P01 (32c7dc9). dl-satan-sensor-{curiosity,content}/{read-snapshot-charges-nothing,commit-advances-to-max-*-not-ts,read-without-commit-keeps-backlog}: out-of-order rows land on native high-water, not wall-clock ts. wpm writer covered by perceive-is-pure."
  - artefact: VT-percept-golden
    kind: VT
    requirement: DEC-perceive-boundary
    status: verified
    notes: "P01 regression (green @32c7dc9). dl-satan-percept/{byte-identical-rerun-on-frozen-inputs,determinism-on-rich-fixture,bundle-and-percept-share-identity} survive the assemble-context split."
  - artefact: VT-mcp-bundle
    kind: VT
    requirement: DEC-perceive-boundary
    status: verified
    notes: "P01 regression (32c7dc9). New dl-satan-context/interactive-bundle-byte-stable-on-frozen-inputs pins build-to-build identity; existing *-bundle-carries-now + interactive-* green."
  - artefact: VT-cursor-advance
    kind: VT
    requirement: DEC-cursor-per-source-intra-day
    status: verified
    notes: "P02. dl-satan-ingest-cursor/{advance-writes-head-per-source,advance-idempotent,advance-does-not-regress-on-older-row,advance-mixed-offset-focus-uses-parsed-instant,advance-missing-cursor-initialises-to-head,backlog-depth-known-cursor,backlog-depth-cursor-at-head-is-zero,backlog-depth-missing-cursor-full-count}. VT-perceive-pure spy extended with cursor-advance+--write. 990/999 green (just check 2026-06-10)."
```

## 1. Summary

- **Delta**: DE-010 - Decouple SATAN perception from agent run
- **Specs Impacted**: none — perception loop is doc-canon (`docs/satan/perceptual-design.md`); no SPEC graduation this delta (DEC-spec-authority-stays-doc).
- **Problems / Issues**: ISSUE-001 (budget-denied ticks skip percept).
- **Desired Outcome**: SATAN tick cut into **perceive** (deterministic, side-effect-free, runs before the budget gate) and **consume** (the gated LLM run carrying all effects + the consumption cursor). Perception becomes budget-independent and effect-separated. Replayability is **not** delivered here (→ IMPR-013).

## 2. Context & Constraints

- **Current Behaviour**: perceive runs inside `broker--spawn`, downstream of the budget gate, so a budget-denied tick writes no `percept.json` (ISSUE-001 root). `assemble-context` bundles percept+resonance+motive+sensor_status; probes charge inside `--spawn`.
- **Target Behaviour**: per DR-010 §3 — perceive = percept-build + persist + probe read-snapshot, lifted before the session/budget gates; consume = probe-commit + observer + resonance/motive enrichment + alerts + cursor advance + LLM. Both denial paths mirror `:percept` into `bundle.json`.
- **Dependencies**: structural cut depends on nothing cross-repo. Signal-model promotion (IMPR-013) and the arrival gate (IMPR-012) are **out of scope**.
- **Constraints**: exactly one percept builder (extraction, not parallel impl). No systemd perception timer re-enabled (D1=B). Cursors key on native source timestamps, git excluded, intra-day only. Segments immutable/append-only — consumption tracked by separate cursor.

## 3. Gate Check

- [x] Backlog items linked and prioritised — ISSUE-001 (fixed here), IMPR-012/IMPR-013 (deferred).
- [x] Spec(s) updated or delta specifies required changes — no SPEC; doc-canon stays (DEC-spec-authority-stays-doc).
- [x] Test strategy identified — VT suite enumerated in coverage block (5 new/regression P01, 1 P02).
- [x] Workspace/config changes assessed — waybar backlog-depth read fn `dl-satan-ingest-cursor-backlog-depth` (emacsclient-callable) built; widget wiring lives in `~/flakes` waybar config + needs `home-manager switch`; surface-only this delta (user), widget build deferred.

## 4. Phase Overview

| Phase                                   | Objective                                                                 | Entrance Criteria                          | Exit Criteria / Done When                                                                 | Phase Sheet          |
| --------------------------------------- | ------------------------------------------------------------------------- | ------------------------------------------ | ----------------------------------------------------------------------------------------- | -------------------- |
| Phase 1 - Perceive/consume seam         | Lift perceive before the budget gate; split probes read/commit; fix ISSUE-001 | DR-010 accepted                            | perceive runs pre-gate; budget-denied + blocked write percept.json + mirror `:percept`; probe read/commit split; MCP bundle byte-stable; VT-budget-denied-perceives, VT-perceive-pure, VT-probe-split, VT-percept-golden, VT-mcp-bundle green; `just check` green | `phases/phase-01.md` |
| Phase 2 - Per-source intra-day cursor   | Add the per-source ingest cursor; surface backlog depth                   | Phase 1 complete, seam landed              | per-source intra-day cursor advanced consume-side only; `head − cursor` backlog depth exposed; waybar widget assessed; VT-cursor-advance green; `just check` green | `phases/phase-02.md` |

_Phase 1 is the high-value structural cut (ISSUE-001 at root). Phase 2 is additive (missing/zero cursor = "consume from head"), so it carries low rollback risk._

## 5. Phase Detail Snapshot

- **Research Notes**: `DE-010/notes.md` (D1/D2 resolution, time-locality, intervention-latency classes).
- **Design Revision**: `DE-010/DR-010.md` (accepted 2026-06-09).
- **Active Phase Sheet**: `phases/phase-01.md` (created with this plan).
- **Parallelisable Work**: flag `[P]` inside phase sheets; the probe read/commit split and the budget-denied mirror are independent sub-tasks within P01.
- **Plan Updates**: revise on phase outcomes (new risks, scope adjustments).

## 6. Testing & Verification Plan

- **Updated Suites**: `dl-satan-broker` (run-dir/gate ordering), `dl-satan-context` (assemble-context split), `dl-satan-sensor-{curiosity,content,wpm}` (probe read/commit).
- **New Cases**: VT-budget-denied-perceives, VT-perceive-pure, VT-probe-split (P01); VT-cursor-advance (P02).
- **Regression**: VT-percept-golden (percept-build golden survives split), VT-mcp-bundle (interactive-boot bundle byte-stable).
- **Tooling/Fixtures**: percept golden fixtures, a budget-denied broker harness, an MCP bundle byte-diff helper.
- **Rollback Plan**: P01 — restore perceive into `--spawn` + the budget-denied early return. P02 — cursor store is additive; removing it falls back to consume-from-head.
- **Verification Coverage**: cross-check `supekku:verification.coverage@v1` entries against phase exits.

## 7. Risks & Mitigations

| Risk                                                              | Mitigation                                                                 | Owner |
| ---------------------------------------------------------------- | -------------------------------------------------------------------------- | ----- |
| Accidental second percept builder (parallel implementation)      | Extraction discipline; VT-percept-golden pins one builder's output         | Dev   |
| MCP interactive-boot bundle drifts after recomposition           | VT-mcp-bundle byte-stable assertion; call perceive + enrichment in order   | Dev   |
| Budget-denied fix cosmetic (consumers read sidecar, not bundle)  | Mirror `:percept` into `bundle.json` on both denial paths (DEC-budget-denied-mirror-percept) | Dev |
| Probe charge cadence shifts under ADR-002                        | Read/commit split preserves charge at consume; VT-probe-split guards       | Dev   |
| Cross-day backlog silently dropped                               | Intra-day scope is explicit/documented; negative guarantee only (P02)      | Dev   |

## 8. Open Questions & Decisions

- [ ] **Cross-midnight backlog** — `(cursor, head]` cannot span day-files; deferred while consumer cadence is sub-daily (DR-010 §8).
- [x] **Waybar wiring** — assessed (P02). Read fn built; widget = `emacsclient --eval '(dl-satan-ingest-cursor-backlog-depth)'` in `~/flakes` waybar config + `home-manager switch`; build deferred (surface-only, user 2026-06-10).
- [x] **Spec authority** — stays doc-canon, no SPEC graduation (DEC-spec-authority-stays-doc).
- [x] **Replayability** — out of scope; deferred to IMPR-013.

## 9. Progress Tracking

- [x] Phase 1 complete (2026-06-09; commits 4c4df41,3c8e333,71f8f68,32c7dc9; `just check` 982/991)
- [x] Phase 2 complete (2026-06-10; commits 13127cc + B2; `just check` 990/999)
- [x] Verification gates passed (AUD-009 completed; `complete delta` coverage gate green; 6/6 coverage entries verified)

## 10. Notes / Links

- Audit reference: AUD-009 (completed 2026-06-10; F-001 §S1 doc patch, F-002/F-003 aligned).
- Supporting docs: `docs/satan/perceptual-design.md` §S1, `docs/satan/architecture.md`, `docs/satan/data-collection.md`.
- Decisions: DR-010 §7 (DEC-perceive-boundary, DEC-probes-read-commit-split, DEC-cursor-per-source-intra-day, DEC-budget-denied-mirror-percept, DEC-defer-signal-promotion, DEC-spec-authority-stays-doc).
