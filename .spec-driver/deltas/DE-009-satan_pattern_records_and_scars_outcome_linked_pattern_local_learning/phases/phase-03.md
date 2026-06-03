---
id: IP-009-P03
slug: "009-satan_pattern_records_and_scars_outcome_linked_pattern_local_learning-phase-03"
name: IP-009 Phase 03
created: "2026-06-03"
updated: "2026-06-03"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-009
delta: DE-009
---

# Phase 03 — Observer wiring + guards

## 1. Objective

Wire the guarded, isolated `dl-satan-pattern-rebuild` call into the outcome observer at
tick end. Prove structural non-regression of the global-attribute path with injected
failure tests. Verify end-to-end attribution with a seeded mature outcome + real rebuild.

## 2. Links & References

- **Delta**: DE-009
- **Design Revision Sections**: DR-009 §3.2 (structural non-regression — three guarantees),
  §4 (code impact summary — observer row), §4.4 (rebuild semantics), DEC-6 (full SQL
  rebuild at tick end, guarded+isolated)
- **Prior art**: `satan/dl-satan-observer.el` (observer-process returns summary plist;
  broker calls observer in `dl-satan-broker.el` line ~724 inside condition-case);
  `satan/dl-satan-pattern.el` (exports `dl-satan-pattern-rebuild`, built in P02);
  `satan/test/dl-satan-observer-test.el` (DB fixture, DROP TABLE includes pattern tables
  from P01)
- **Phase 02**: pattern module built; all VT-pattern-* tests green

## 3. Entrance Criteria

- [x] Phase 02 complete: `dl-satan-pattern.el` module + all P02 VTs green
- [x] `satan/patterns.eld` committed with seed definitions
- [x] `satan-pattern-rebuild` callable and idempotent

## 4. Exit Criteria / Done When

- [x] `dl-satan-pattern-rebuild` called at the end of `dl-satan-observer-process`, AFTER
      classification + persistence + global attribute enqueue
- [x] Guard catches ALL errors (rebuild failure, require failure, migration failure) —
      logs, does not signal, does not abort the tick
- [x] `require 'dl-satan-pattern` is lazier-than-possible: loaded inside the guard so
      a load-time error never propagates into the classification path
- [x] `VT-rebuild-guard` green: simulated rebuild failure AND simulated pattern-module
      unavailability both swallowed; tick completes; classification + satan_attribute_events
      intact (i.e. `satan_outcome_inbox` rows written for all mature verdicts)
- [x] `VT-global-attr-regression` green: the same interventions classified in the same
      DB produce the same `satan_outcome_inbox` rows with and without the pattern rebuild
      wired in
- [x] `VA-pattern-attribution` green: seeded mature `contradicted` outcome + percept-stamped
      intervention → real `satan-pattern-rebuild` → inspect `satan_pattern_stats` view for
      a `contradicted_count > 0` + inspect `satan_pattern_outcomes` for the scar row
- [x] `just check` green; paren-check clean on every `.el`

## 5. Verification

- **VT-rebuild-guard** (ERT):
  1. Simulate `dl-satan-pattern-rebuild` signalling an error → observer-process returns
     a normal summary plist (not nil, not an error signal)
  2. Simulate `require 'dl-satan-pattern` failing → observer-process still returns a
     normal summary
  3. In both cases, verify `satan_intervention_outcomes` and `satan_outcome_inbox` have
     the expected rows (classification + global enqueue unaffected)
  4. Verify `satan_pattern_outcomes` is unchanged (rebuild never ran) or empty
- **VT-global-attr-regression** (ERT):
  1. Classify a set of interventions WITHOUT the pattern rebuild wired → capture
     `satan_outcome_inbox` rows
  2. Classify the same interventions WITH the rebuild wired → assert identical
     `satan_outcome_inbox` rows
  3. Also assert `satan_intervention_outcomes` rows are identical
- **VA-pattern-attribution** (VA — agent-run):
  1. Seed a pattern definition that matches a known percept shape
  2. Create an intervention carrying that percept snapshot
  3. Classify it as `contradicted` via the observer
  4. Run `dl-satan-pattern-rebuild`
  5. Assert `satan_pattern_stats.contradicted_count = 1`
  6. Assert a scar row exists in `satan_pattern_outcomes`

## 6. Assumptions & STOP Conditions

- **Assumptions**:
  - The rebuild call goes inside `dl-satan-observer-process` (not the broker), AFTER the
    per-intervention loop and the `list :processed :positive :verdicts` return value is
    assembled — this keeps the guard local to one module
  - `require 'dl-satan-pattern` is deferred into the guard body itself (no top-level
    require in `dl-satan-observer.el`) to achieve load-time isolation per DR-009 §3.2
    point 3
  - `dl-satan-n-enqueue-outcome` (the global attribute enqueue inside
    `dl-satan-intervention-classify`) executes synchronously before the rebuild guard —
    so the guard only isolates rebuild failures, not classification/enqueue failures
  - `VT-global-attr-regression` uses `satan_outcome_inbox` as the observable signal of
    the global attribute path (the N daemon reads from this table)
  - Test DB uses the same `dl-satan-observer-test--db` fixture pattern as existing
    observer tests (P01 already added pattern tables to the DROP list)
- **STOP if**: the observer test fixture doesn't support late-seeded outcomes (may need
  to call `dl-satan-intervention-classify` directly rather than running the full
  observer-process)

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description                                           | Parallel? | Notes |
| ------ | --- | ----------------------------------------------------- | --------- | ----- |
| [x]    | 3.1 | Wire rebuild into observer with guard                  | [ ]       | condition-case, deferred require |
| [x]    | 3.2 | VT-rebuild-guard + VT-global-attr-regression           | [ ]       | ERT, 4 test cases, all pass |
| [x]    | 3.3 | VA-pattern-attribution                                 | [ ]       | seeded mature outcome → rebuild → contradicted=1, scar row |
| [x]    | 3.4 | Docs: CHANGELOG.md + epistemics-roadmap.md             | [ ]       | done |
| [x]    | 3.5 | Gate: `just check` + paren-check                       | [ ]       | 969 tests, 0 failures, 9 skipped |

### Task Details

- **3.1 Wire rebuild into observer**
  - **Design / Approach**:
    - In `dl-satan-observer-process`, AFTER the `dolist` loop that classifies+persists
      verdicts and AFTER the return plist is assembled, add:
      ```elisp
      (condition-case err
          (progn
            (require 'dl-satan-pattern)
            (dl-satan-pattern-rebuild db))
        (error
         (message "dl-satan-observer: pattern rebuild failed: %s"
                  (error-message-string err))))
      ```
    - DO NOT add a top-level `(require 'dl-satan-pattern)` — the require is inside the
      guard body, achieving load-time isolation (DR-009 §3.2 point 3)
    - The `db` variable is already in scope (bound in the `let*` of observer-process)
    - The rebuild runs AFTER the return plist is assembled but BEFORE the function
      returns it — the rebuild is a side-effect that doesn't change the summary
    - Reorder the observer-process body so the return plist is assembled first, then
      the guard runs, then the plist is returned
  - **Files / Components**: `satan/dl-satan-observer.el`
  - **Testing**: covered by tasks 3.2, 3.3
  - **Observations & AI Notes**: The guard is intentionally broad — catches EVERYTHING
    including require failures, psql connection failures, migration availability, etc.

- **3.2 VT-rebuild-guard + VT-global-attr-regression**
  - **Design / Approach**: Extend `satan/test/dl-satan-observer-test.el`
  - **VT-rebuild-guard** (3 test cases):
    1. `satan-rebuild-guard-swallows-rebuild-error` — flet `dl-satan-pattern-rebuild`
       to signal an error; call observer-process; assert normal summary plist returned
       (non-nil, carries :processed, :positive, :verdicts); assert satan_outcome_inbox
       has expected rows; assert satan_pattern_outcomes unchanged
    2. `satan-rebuild-guard-swallows-require-failure` — simulate `require` failure by
       temporarily breaking the load path or flet-ing `require`; assert same as above
    3. `satan-rebuild-guard-classification-intact` — normal observer-process call with
       rebuild guard active; assert satan_intervention_outcomes has expected verdict rows
  - **VT-global-attr-regression** (2 test cases):
    1. `satan-attr-regression-inbox-rows-identical` — run observer-process with and
       without rebuild wired (flet rebuild to no-op vs real); capture
       satan_outcome_inbox rows; assert identical
    2. `satan-attr-regression-outcome-rows-identical` — same comparison for
       satan_intervention_outcomes rows
  - **Files / Components**: `satan/test/dl-satan-observer-test.el`
  - **Testing**: ERT with DB fixture (reuse `dl-satan-observer-test--with-db`)
  - **Observations & AI Notes**: Need to create real interventions + classify them.
    Reuse existing observer test patterns (e.g. `dl-satan-observer-test--seed-*`
    helpers). The global-attr path is observable via `satan_outcome_inbox` rows.

- **3.3 VA-pattern-attribution**
  - **Design / Approach**: Agent-run verification (VA) — not an ERT test.
    1. Ensure patterns.eld has a pattern whose cue_handles matches the percept shape
       that will be used
    2. Create an intervention via `dl-satan-intervention-create` with a percept-handle
       snapshot that contains the pattern's cue_handles
    3. Use `dl-satan-intervention-classify` to classify it as `contradicted`, mature
    4. Run `(dl-satan-pattern-rebuild)` directly
    5. Query `satan_pattern_stats` — assert `contradicted_count >= 1` for that pattern
    6. Query `satan_pattern_outcomes` — assert a row with `classification = 'contradicted'`
    7. Record findings in notes.md
  - **Files / Components**: `satan/patterns.eld`, `satan/dl-satan-pattern.el`
  - **Testing**: Manual / agent-driven; record output in notes.md
  - **Observations & AI Notes**: If DB is not reachable, skip and note in notes.md.
    This is the end-to-end proof that the whole chain works.

- **3.4 Docs**
  - **CHANGELOG.md**: add entry for DE-009 — "SATAN pattern records and scars: outcome-linked
    pattern-local learning. Observer now rebuilds pattern projection at tick end (guarded,
    isolated from classification path). Percept snapshots stamped on interventions.
    Curated patterns.eld with grammar-validated sync."
  - **epistemics-roadmap.md**: mark step 1 (patterns/scars) as complete; note the
    completion date and which phase delivered it
  - **Files / Components**: `CHANGELOG.md`, `docs/satan/epistemics-roadmap.md`

- **3.5 Gate**
  - `just check` green — all tests pass (0 failures, expected skips only)
  - `bin/elisp-locate-paren-error satan/dl-satan-observer.el` → `{"ok":true}`
  - `bin/elisp-locate-paren-error satan/test/dl-satan-observer-test.el` → `{"ok":true}`

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| Rebuild inside observer-process blocks the tick if guard fails | The guard is a condition-case that catches `error` — never signals | open |
| Require of dl-satan-pattern triggers unwanted side-effects | dl-satan-pattern.el has no top-level side-effects beyond `provide`; verify before wiring | open |
| Test fixture DROP TABLE order cascades wrongly | P01 already added pattern tables; verify test reset works as-is | open |
| satan_outcome_inbox may not exist or be emptied by test reset | Check existing observer tests that verify inbox; mirror their setup | open |

## 9. Decisions & Outcomes

- `2026-06-03` — Rebuild guard goes INSIDE observer-process (not broker) per DR-009 §3.2.
  The broker already wraps observer-process in condition-case for observer errors; the
  rebuild guard is a second, finer-grained guard that isolates rebuild failures from
  classification failures. This keeps the classification summary accurate (it reports
  what was classified, not whether the rebuild succeeded).

## 10. Findings / Research Notes

- Observer is called at `satan/dl-satan-broker.el` line ~723: `(dl-satan-observer-process prepare)`.
  The broker wraps this in `condition-case _err ... (error nil)` — so even if the
  observer signals, the tick proceeds. But the rebuild guard inside observer-process
  prevents the observer from signalling at all (it logs, then returns a normal summary).
- Global attribute enqueue: `dl-satan-intervention-classify` calls
  `dl-satan-intervention--enqueue-n-outcome` which writes to `satan_outcome_inbox`.
  This happens synchronously during observer-process's `dolist` loop.
- The pattern rebuild uses `db` which is already bound in observer-process's `let*`
  (defaults to `dl-satan-memory-migrate-database` via `dl-satan-intervention-pending`).
- Test DB: `dl-satan-observer-test--db` = `"satan_memory_test"`. DROP TABLE in
  `dl-satan-observer-test--reset-and-migrate` includes `satan_pattern_outcomes, satan_patterns`
  (added in P01).

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Verification evidence stored (test run output in notes.md)
- [x] DE/DR/IP updated with lessons
- [x] Hand-off note to next phase: `audit-change` → AUD-006 (completed)
