---
id: IP-009-P01
slug: "009-satan_pattern_records_and_scars_outcome_linked_pattern_local_learning-phase-01"
name: IP-009 Phase 01
created: "2026-06-03"
updated: "2026-06-03"
status: draft  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-009
delta: DE-009
---

# Phase 01 — Schema + percept snapshot

## 1. Objective

Lay the audited data substrate: the `0007` migration (all DE-009 schema) and the
immutable percept-handle snapshot stamped onto every `intervention.created`. After this
phase, new interventions carry the audited cue surface that Phase 02's projection will
match against — with zero behavioural change to classification or the global path.

## 2. Links & References

- **Delta**: DE-009
- **Design Revision Sections**: DR-009 §3.1 (data flow), §3.2 (structural non-regression),
  §4.1 (schema), §4.4 (snapshot), DEC-4, DEC-6.
- **Prior art**: `satan/memory/migrations/0006_interventions.sql`;
  `satan/dl-satan-intervention.el` (`intervention-create`, audit validator, insert SQL);
  `satan/dl-satan-broker.el` + `dl-satan-run.el` (tool-ctx builders);
  `satan/dl-satan-percept.el` (`:handles`).

## 3. Entrance Criteria

- [x] DR-009 accepted; IP-009 phase plan written.
- [ ] Jailed test Postgres available (DE-004/DE-006 harness).

## 4. Exit Criteria / Done When

- [ ] `0007_patterns.sql` applies cleanly forward: `ALTER satan_interventions ADD
      percept_handles_json JSONB NOT NULL DEFAULT '[]'` + GIN; `satan_patterns`;
      `satan_pattern_outcomes` (no FK to interventions); `satan_pattern_stats` view.
- [ ] `intervention.created` stamps `percept_handles_json` from tool-ctx `:percept-handles`;
      nil/absent percept → `[]`. Audit validator accepts the new field; insert persists it.
- [ ] `:percept-handles` threaded into both tool-ctx builders (`dl-satan-broker--tool-ctx`,
      `dl-satan-run-tool-ctx`), nil-safe for interactive/MCP runs.
- [ ] `VT-intervention-percept-snapshot` green.
- [ ] Existing intervention/outcome projection tests + global-attribute tests still green
      (no regression). `bin/elisp-locate-paren-error` clean on every edited `.el`.

## 5. Verification

- ERT `VT-intervention-percept-snapshot`: create intervention with a ctx carrying percept
  handles → row + audit payload carry the JSONB array; create with nil percept → `[]`.
- Migration apply test against the jailed DB; assert columns/indexes/view exist; assert a
  pre-existing intervention row backfills to `[]`.
- Re-run existing intervention + observer/attribute suites → green (regression).
- `just check`.

## 6. Assumptions & STOP Conditions

- Assumption: `run_ctx`'s `:percept` slot (broker line ~766) is populated before any
  tool call that creates an intervention. **Verify early**: if a tool can create an
  intervention before percept-build, the snapshot would be `[]` for real ticks.
- Assumption: the audit validator (`dl-satan-audit-validate-intervention-event`) is the
  single chokepoint for the new field; no other producer of `intervention.created`.
- STOP if: threading `:percept-handles` requires changing the run struct (vs the prepare
  plist) or touches the global-attribute payload — surface before proceeding (R3).

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID | Description | Parallel? | Notes |
| --- | --- | --- | --- | --- |
| [ ] | 1.1 | Write `0007_patterns.sql` (all DE-009 schema) | [ ] | mirror 0006 style/CHECKs |
| [ ] | 1.2 | Thread `:percept-handles` into both tool-ctx builders | [P] | nil-safe |
| [ ] | 1.3 | Stamp `percept_handles_json` in `intervention-create` (payload + validator + insert SQL) | [ ] | depends on 1.1, 1.2 |
| [ ] | 1.4 | `VT-intervention-percept-snapshot` + migration-apply test | [ ] | depends on 1.3 |
| [ ] | 1.5 | Run regression suites + `just check` + paren-check | [ ] | gate |

### Task Details

- **1.1 Migration** — `satan/memory/migrations/0007_patterns.sql`. ALTER + GIN
  (`jsonb_path_ops`), three pattern objects per DR §4.1. CHECK on
  `satan_pattern_outcomes.classification` excludes `unknown`. No FK to `satan_interventions`.
- **1.2 tool-ctx threading** — add `:percept-handles (plist-get (… :percept) :handles)`
  to `dl-satan-broker--tool-ctx` and `dl-satan-run-tool-ctx`; `nil` → handled at stamp time.
- **1.3 Snapshot stamp** — extend `dl-satan-intervention-create` payload with
  `:percept_handles`, the audit validator to accept it, and the created-insert SQL to
  write `percept_handles_json` (JSONB; `[]` when nil).
- **1.4 Tests** — ERT; reuse DB harness; assert backfill default on a legacy row.
- **1.5 Gate** — `just check`, paren-check, regression.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| --- | --- | --- |
| Tool creates intervention before percept-build → `[]` snapshots in real ticks | Verify ordering early (1.2/1.3); STOP if so | open |
| Audit validator has multiple call sites | grep producers of `intervention.created` before editing | open |

## 9. Decisions & Outcomes

- `2026-06-03` — Single migration `0007` lands all schema (interventions ALTER + pattern
  tables) so Phase 02 is elisp-only. Rationale: avoids a second migration and a partial
  schema between phases.

## 10. Findings / Research Notes

- `percept.json` is NOT read at runtime for attribution (DR DEC-4) — the snapshot column
  is the audited source. Percept persistence stays as-is.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored (test run output in notes.md)
- [ ] DE/DR/IP updated if anything shifted
- [ ] Hand-off note to Phase 02 (rebuild can assume the snapshot column is populated)
