# Notes for DE-009

## Phase 01 — Schema + percept snapshot (2026-06-03)

### Completed
- `0007_patterns.sql` migration: ALTER satan_interventions + GIN, satan_patterns, satan_pattern_outcomes, satan_pattern_stats view
- `:percept-handles` threaded into both tool-ctx builders (dl-satan-broker--tool-ctx, dl-satan-run-tool-ctx)
- `percept_handles_json` stamped at intervention.created (payload, validator, insert SQL)
- VT-intervention-percept-snapshot: 3 tests (stamps from ctx, nil → [], migration backfills legacy)
- Regression: all 941 tests pass (0 failures, 9 skipped), `just check` green
- Test fixture updates: 6 test files updated to drop new pattern tables; migration test expects 1-7 versions

### Files changed
- `satan/memory/migrations/0007_patterns.sql` (new)
- `satan/dl-satan-broker.el` — add :percept-handles to tool-ctx
- `satan/dl-satan-run.el` — add :percept-handles to tool-ctx
- `satan/dl-satan-intervention.el` — stamp percept_handles_json in create (payload, SQL, quote-jsonb)
- `satan/dl-satan-audit.el` — validate :percept_handles array on intervention.created
- `satan/test/dl-satan-intervention-test.el` — new percept tests + fixture updates
- `satan/test/dl-satan-audit-intervention-test.el` — add :percept_handles to fixture
- `satan/test/dl-satan-*-test.el` (5 files) — add satan_pattern* to DROP TABLE lists
- `satan/test/dl-satan-memory-migrate-test.el` — expect 1-7 versions

### Gotchas
- `dl-satan-intervention--quote-jsonb` replaced `(or obj :null)` with `(or obj (vector))` for array fields only (cue_handles, percept_handles) to serialize empty arrays as `[]` not `null`. The generic `quote-jsonb` still uses `:null` as default for non-array fields like evidence.
- `just check` requires `--init-directory=...` so emacs can find workspace migrations.
- `user-emacs-directory` resolution issue in batch: migrations dir is at `/workspace/.emacs.d/satan/memory/migrations/`, not `~/.emacs.d/`.
- The `'()` = nil = `null` in JSON round-trip: tests must handle both nil and empty-vector representations.

### Hand-off to Phase 02
- The `percept_handles_json` column is populated on all new interventions.
- Legacy interventions backfill to `'[]'::jsonb`.
- Phase 02 can assume the snapshot column exists and is populated; the rebuild SQL (containment join) is ready to implement.
- The `dl-satan-pattern.el` module + `patterns.eld` + `satan-pattern-rebuild` are the Phase 02 targets.
