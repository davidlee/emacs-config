# Notes for DE-009

## Phase 01 — Schema + percept snapshot (2026-06-03)

### Completed
- `0007_patterns.sql` migration: ALTER satan_interventions + GIN, satan_patterns, satan_pattern_outcomes, satan_pattern_stats view
- `:percept-handles` threaded into both tool-ctx builders (dl-satan-broker--tool-ctx, dl-satan-run-tool-ctx)
- `percept_handles_json` stamped at intervention.created (payload, validator, insert SQL)
- VT-intervention-percept-snapshot: 3 tests (stamps from ctx, nil → [], migration backfills legacy)
- Regression: all 941 tests pass (0 failures, 9 skipped), `just check` green
- Test fixture updates: 6 test files updated to drop new pattern tables; migration test expects 1-7 versions
- Commit: `efb31da`

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

---

## Phase 02 — Definitions + pattern rebuild (2026-06-03)

### Completed
- `satan/patterns.eld`: 3 seed patterns (docs-after-error, terminal-coding, editor-commit)
- `satan/dl-satan-pattern.el`: full module — parse/sync, rebuild, read accessors
- `satan/test/dl-satan-pattern-test.el`: 15 ERT tests
- All 965 tests pass (0 failures, 9 skipped)
- Commits: `6efc731`, `f4ff2ca`, `b0de23d`

### Files changed
- `satan/patterns.eld` (new, force-added past *.eld gitignore) — 3 curated pattern definitions
- `satan/dl-satan-pattern.el` (new) — parse/sync (grammar-validated), containment-join rebuild, read accessors
- `satan/test/dl-satan-pattern-test.el` (new) — 4 containment + 6 sync + 5 rebuild tests

### API surface
- `(dl-satan-pattern-sync &optional PATTERNS-FILE DB)` → `(:upserted N :retired M)`
- `(dl-satan-pattern-rebuild &optional DB)` → `(:matched N)`
- `(dl-satan-pattern-stats &optional DB)` → list of plists from `satan_pattern_stats` view
- `(dl-satan-pattern-list &optional DB)` → list of pattern definition plists
- `(dl-satan-pattern-scars &optional PATTERN-ID DB)` → list of scar plists

### Gotchas
- `dl-satan-pattern--quote-jsonb` must use `dl-satan-jsonl-prepare` to convert elisp lists to vectors before `json-serialize`, otherwise lists like `("app:emacs")` fail serialization
- `dl-satan-pattern--query-with-cols` takes explicit column names as a list of strings, not derived from the first data row (since psql `-A -t` omits headers)
- `patterns.eld` is tracked via `git add -f` because `*.eld` is gitignored — consistent with DR-009 DEC-3 (curated, checked-in definitions)
- Rebuild uses `pg_advisory_xact_lock(900876543)` to serialize overlapping rebuilds
- Containment join: `i.percept_handles_json @> p.cue_handles_json` with `jsonb_path_ops` GIN index
- Sync validates handles via `dl-satan-memory-grammar-namespace-world` and `dl-satan-memory-grammar-valid-value-p`
- Rebuild excludes `maturity != 'mature'` OR `classification = 'unknown'` — re-verifies after every rebuild (head-only)
- Rebuild advisory lock key is a hardcoded bigint `900876543` — OK for single-observer, may need extraction if multiple observers exist

---

## Hand-off to Phase 03

### State
- DE-009: in-progress
- P01: completed (11/11)
- P02: completed (15/15 tests, all green)
- P03: not started — Observer wiring + guards + verification

### Phase 03 target
From IP-009:
- Guarded/isolated `satan-pattern-rebuild` at observer tick end
- `VT-rebuild-guard`, `VT-global-attr-regression`, `VA-pattern-attribution`
- Docs (CHANGELOG, epistemics-roadmap tracking)

Key files for Phase 03:
- `satan/dl-satan-observer.el` — add `satan-pattern-rebuild` call at tick end, inside a guard
- `satan/dl-satan-observer-classify.el` — may need no changes (rebuild runs AFTER classification)
- `satan/test/dl-satan-observer-test.el` — add guard/regression tests

Design references (DR-009):
- §3.2 — Structural non-regression: rebuild runs LAST, wrapped in guard, module require isolated
- §4 — Code impact summary: `satan/dl-satan-observer.el` gets guarded rebuild call

### What the rebuild needs
- Call `dl-satan-pattern-rebuild` after `dl-satan-observer-classify` and global attribute enqueue
- Wrap in `condition-case` that catches ALL errors (including `require` failure)
- Log failure without signalling — broken pattern subsystem → stale stats only
- `VT-rebuild-guard`: inject simulated failure → verify tick completes + classification + global attrs intact
- `VT-global-attr-regression`: verify `satan_attribute_events` unchanged by observer addition

### Outstanding
- P03 phase sheet not yet created — next agent should run `spec-driver create phase "Phase 03 — Observer wiring + guards" --plan IP-009`
  then populate the sheet following Phase 02 template
- `.spec-driver` changes committed alongside code (`b0de23d`)

---

## Phase 03 — Observer wiring + guards (2026-06-03)

### Completed
- Observer wiring: guarded `dl-satan-pattern-rebuild` call at end of `dl-satan-observer-process`
- Require is inside the guard (lazier-than-possible, load-time isolation per DR-009 §3.2)
- VT-rebuild-guard: 3 tests (rebuild error swallowed, require failure swallowed, classification intact)
- VT-global-attr-regression: 1 test (outcome rows correct with rebuild wired)
- VA-pattern-attribution: seeded mature contradicted outcome → rebuild → stats show contradicted_count=1, scar row present
- Docs: CHANGELOG.md entry, epistemics-roadmap.md step 1 marked complete
- All 969 tests pass (0 failures, 9 skipped), `just check` green

### Files changed
- `satan/dl-satan-observer.el` — +13 lines: guarded rebuild call after classification loop
- `satan/test/dl-satan-observer-test.el` — +180 lines: 4 new test functions
- `CHANGELOG.md` — DE-009 entry
- `docs/satan/epistemics-roadmap.md` — step 1 marked complete

### Gotchas
- `dl-satan-intervention-create` reads `:percept-handles` from ctx, not as a keyword arg — VA script needed this fix
- `dl-satan-intervention-classify` requires `:next-revisit-at` when called directly
- N attribute enqueue tries production DB (`satan_memory`) even in test — benign warning, global path unaffected
- Observer test fixture already had pattern tables in DROP list from P01

### Verification summary
- VT-rebuild-guard-swallows-rebuild-error ✓ — observer returns normal summary, classification intact, pattern_outcomes unchanged
- VT-rebuild-guard-swallows-require-failure ✓ — observer returns normally, classification intact
- VT-rebuild-guard-classification-intact ✓ — observer works correctly with real rebuild succeeding
- VT-global-attr-regression-outcome-rows ✓ — outcome projection correct with rebuild wired
- VA-pattern-attribution ✓ — seeded contradicted outcome → rebuild → contradicted_count=1, scar row exists
