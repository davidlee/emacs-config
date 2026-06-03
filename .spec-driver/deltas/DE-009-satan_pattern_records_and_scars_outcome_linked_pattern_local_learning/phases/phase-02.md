---
id: IP-009-P02
slug: "009-satan_pattern_records_and_scars_outcome_linked_pattern_local_learning-phase-02"
name: IP-009 Phase 02
created: "2026-06-03"
updated: "2026-06-03"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-009
delta: DE-009
---

# Phase 02 — Definitions + pattern rebuild

## 1. Objective

Build the `dl-satan-pattern.el` module: parse + sync `patterns.eld` definitions,
rebuild the `satan_pattern_outcomes` projection via a containment-based SQL join
(TRUNCATE + INSERT in one tx, advisory-locked, mature/non-unknown only, head-only),
and expose read accessors. The tables from 0007 already exist; this phase populates
definitions and makes the rebuild work.

## 2. Links & References

- **Delta**: DE-009
- **Design Revision Sections**: DR-009 §4.1 (schema — done in P01), §4.2 (patterns.eld shape),
  §4.3 (matching — containment join), §4.4 (rebuild — TRUNCATE+INSERT, advisory lock,
  mature/non-unknown, head-only), DEC-3 (grammar-validated sync), DEC-4 (containment
  subset), DEC-6 (full SQL rebuild)
- **Prior art**: `satan/dl-satan-memory-grammar.el` (handle grammar validation, used for
  sync validation); `satan/dl-satan-intervention.el` (SQL patterns:
  `dl-satan-db-psql`, `json-serialize`, `quote-jsonb`, `quote-text`)
- **Phase 01**: `satan/memory/migrations/0007_patterns.sql` (schema exists, empty)

## 3. Entrance Criteria

- [x] Phase 01 complete: schema exists, percept_handles_json populated
- [x] No unresolved design questions in DR-009 (DR §8 open questions are follow-ups, not blocking)

## 4. Exit Criteria / Done When

- [x] `patterns.eld` committed with initial seed definitions (3 patterns; AUD-006 F-001
      fixed the multi-form parse so all three load)
- [x] `satan-pattern-sync` parses `patterns.eld`, validates cue_handles against canon grammar,
      upserts definitions idempotently, soft-retires absent patterns (enabled=false)
- [x] `satan-pattern-rebuild` runs the containment join (TRUNCATE+INSERT, advisory lock,
      mature/non-unknown only), idempotent, head-only
- [x] Read accessors: `satan-pattern-stats` returns the stats view
- [x] `VT-pattern-containment` green: JSONB @> subset, empty, superset, disjoint
- [x] `VT-pattern-sync` green: parse + sync + reject ungrammatical handle
- [x] `VT-pattern-rebuild` green: seeded data → expected projection + stats; disabled
      still attributed; immature/unknown excluded; revised-away drops
- [x] `just check` green; paren-check clean on every `.el`

## 5. Verification

- **VT-pattern-containment**: DB fixture — insert patterns + interventions with
  varying percept snapshots; verify @> match (empty cue-set matches all, superset
  doesn't, disjoint doesn't)
- **VT-pattern-sync**: parse patterns.eld; call sync; verify upsert + soft-retire;
  feed an invalid handle → error; call sync again → idempotent (no-op)
- **VT-pattern-rebuild**: seed interventions (via create API, which now stamps
  percept_handles) + outcomes (via classify API); run rebuild; assert
  satan_pattern_outcomes + stats view have expected rows; assert immature/unknown
  excluded; assert disabled pattern still gets rows; revise an outcome away from
  contradicted → assert rebuild removes the scar

## 6. Assumptions & STOP Conditions

- **Assumptions**: 
  - `patterns.eld` is loaded from a fixed path (e.g. `satan/patterns.eld`) relative
    to `user-emacs-directory`
  - Pattern definitions are few (≤20) — sync cost is trivial
  - Containment join is set-based SQL, GIN-indexed — no elisp loop needed
  - Read accessors are light wrappers over the `satan_pattern_stats` view
- **STOP if**: grammar validation requires importing heavy memory machinery that
  creates unwanted coupling; OR if the containment join performance on real data is
  unexpectedly bad (test with seeded rows first)

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description                                     | Parallel? | Notes |
| ------ | --- | ----------------------------------------------- | --------- | ----- |
| [x]    | 2.1 | Create `patterns.eld` with seed definitions     | [P]       | 3 patterns; data file, no elisp |
| [x]    | 2.2 | `dl-satan-pattern.el` — parse + sync            | [ ]       | grammar-validated, idempotent upsert |
| [x]    | 2.3 | `dl-satan-pattern.el` — rebuild projection      | [ ]       | depends on 2.2; containment join |
| [x]    | 2.4 | `dl-satan-pattern.el` — read accessors          | [ ]       | stats view, pattern listing |
| [x]    | 2.5 | `VT-pattern-containment` + `VT-pattern-sync`    | [ ]       | depends on 2.2 |
| [x]    | 2.6 | `VT-pattern-rebuild`                            | [ ]       | depends on 2.3 |
| [x]    | 2.7 | Gate: `just check` + paren-check                | [ ]       | depends on 2.5, 2.6 |

### Task Details

- **2.1 `patterns.eld`** — `satan/patterns.eld`, read-form list of plists per DR §4.2.
  Each entry: `:id`, `:label`, `:cue_handles` (vector of grammatically-valid handle strings),
  `:default_intervention`, `:intrusion_ceiling`, `:priority`, `:enabled`, `:notes`.
  Minimum 2 seed patterns derived from known SATAN behaviours (e.g. "docs after error",
  "terminal coding session"). This is a data file — no use-package form, Nix doesn't
  need to parse it.

- **2.2 Pattern sync** — `dl-satan-pattern.el`:
  - `satan-pattern-sync` reads patterns.eld, validates each cue_handle against
    `dl-satan-memory-grammar-validate-handle` (reject unknown handles per DEC-3),
    upserts `satan_patterns` rows, soft-retires absent patterns (`enabled=false`)
  - Idempotent: second call is a no-op if patterns.eld unchanged
  - Single writer: patterns.eld is the sole source of pattern definitions

- **2.3 Rebuild projection** — `satan-pattern-rebuild`:
  - `TRUNCATE satan_pattern_outcomes;`
  - `INSERT INTO satan_pattern_outcomes SELECT …`
  - Containment join: `i.percept_handles_json @> p.cue_handles_json`
  - Joins: `satan_patterns p JOIN satan_interventions i ON @> JOIN satan_intervention_outcomes o ON …`
  - Filters: `o.maturity = 'mature'`, `o.classification <> 'unknown'`
  - Advisory lock: `pg_advisory_xact_lock(…pattern_rebuild_key…)`
  - Single transaction: `--single-transaction` psql flag
  - Head-only: reads current outcome head verdict (revised-away drops on next rebuild)

- **2.4 Read accessors** — thin wrappers:
  - `satan-pattern-stats` → query `satan_pattern_stats` view
  - `satan-pattern-list` → query `satan_patterns` (optional: filter by enabled)
  - `satan-pattern-scars` → query `satan_pattern_outcomes WHERE classification IN ('contradicted','harmful')`

- **2.5–2.6 Tests** — ERT, using the same DB harness as Phase 01:
  - Containment: create patterns with varying cue_handles, seed interventions with
    varying percept_handles_json, run rebuild, assert matches
  - Sync: call sync with valid + invalid patterns.eld content, verify DB state
  - Rebuild: create interventions + outcomes via existing API, run rebuild,
    assert projection + stats

- **2.7 Gate** — `just check` = clean, all tests green including Phase 01 tests

## 8. Risks & Mitigations

| Risk                                              | Mitigation                                                  | Status |
| ------------------------------------------------- | ----------------------------------------------------------- | ------ |
| Grammar validation creates unwanted coupling      | `dl-satan-memory-grammar-validate-handle` is a pure function; import is cheap | open |
| Containment join cost at higher volume            | Set-based SQL + GIN; test with seeded rows; defer incremental rebuild | open |
| `jsonb_path_ops` GIN index not used for `@>`      | Verify Query Plan shows GIN index usage in tests            | open |
| Cross-DB-patterns test pollution (same DB)        | Re-use `reset-and-migrate` pattern; create seed fixtures per test | open |

## 9. Decisions & Outcomes

- `2026-06-03` — Phase 02 is elisp-only (schema from P01); no migration changes needed
- `2026-06-03` — Seed patterns derived from known SATAN behaviour; no auto-mining

## 10. Findings / Research Notes

- `dl-satan-memory-grammar.el` exports `dl-satan-memory-grammar-validate-handle` (returns
  a result plist: `(:valid t|nil :reason nil|STRING)`) — use this for sync validation per DEC-3
- `dl-satan-db-psql` accepts `--single-transaction` flag; advisory lock via `-c "SELECT pg_advisory_xact_lock(N)"` prepended to the script

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Verification evidence stored (test run output in notes.md)
- [x] DE/DR/IP updated if anything shifted
- [x] Hand-off note to Phase 03 (observer wiring + guards)
