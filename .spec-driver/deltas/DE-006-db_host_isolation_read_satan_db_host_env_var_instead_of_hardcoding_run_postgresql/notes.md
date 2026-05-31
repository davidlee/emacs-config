# Notes for DE-006

## Phase 0 — 2026-05-31

### Files Changed
- `satan/dl-satan-db.el` — added `dl-satan-db-host-override`, `dl-satan-db-resolve-host`, `dl-satan-db-database-url`, `dl-satan-db-test-db-available-p`; chokepoint resolution in `dl-satan-db-psql`/`dl-satan-db-query`
- `satan/test/dl-satan-db-test.el` — fixed `psql-single-transaction-passthrough` (add `-A -t` flags, was latent bug masked by skip) and `query-connection-failure` (let-bind override nil so test can exercise error path)
- `satan/test/dl-satan-memory-migrate-test.el` — added `dl-satan-memory-migrate-test--db-available-p` delegating to `dl-satan-db-test-db-available-p`; 5 integration tests gated
- `Justfile` — `check` = batch (was `check-batch`), `check-interactive` = emacsclient with host-carrier let-binding
- `dev/dl-test.el` — updated header comments for new recipe names

### Key Design Decisions
- DR-006 re-approved with DEC-006 (centralized `dl-satan-db-resolve-host`) and DEC-007 (bough via DATABASE_URL)
- `dl-satan-db-test-db-available-p` routes through `dl-satan-db-resolve-host` so batch-prod guard fires inside the predicate
- Claim (b): guard fires correctly but ERT `skip-unless` swallows the error → silent skip. No prod connections, but not "loud." Pre-flight check in `dl-test-run-suite` candidate for Phase 1.

## Phase 1 — 2026-05-31

### Files Changed
- `satan/test/dl-satan-patch-store-test.el` — LISTEN `-h` now routes through `dl-satan-db-resolve-host` (DEC-006 fix)
- `satan/test/dl-satan-db-test.el` — `--reachable-p` delegates to `dl-satan-db-test-db-available-p`; 10 new chokepoint VT tests
- `satan/test/dl-satan-memory-grammar-test.el` — inline `call-process psql` now routes `-h` through `dl-satan-db-resolve-host`; reachability delegates to shared predicate

### Results
- Patch-store `insert-fires-notify`: was connecting to `/run/postgresql` → now redirects via resolver → passes
- Grammar `db-sync-*` (3 tests): were skipping → now pass against test DB
- VT: 21/21 passing (resolver, guard, predicate, database-url)
- Pre-existing failures (6): tick/pulse.txt missing, satan_attributes/outcome_inbox tables, mind-docs-exist, end-to-end-smoke

### Remaining for Phase 2
- Rename sweep: CHANGELOG, AGENTS/docs, CI references
- Remove `--host` defconsts (cosmetic; values overridden by resolver)
- `dl-satan-db-default-host` disposition (zero callers, vestigial)
- Claim (b) pre-flight check added to `dl-test-run-suite` — batch without SATAN_DB_HOST errors before loading any test files

## Phase 3 — 2026-05-31 (reopened: suite not actually green at premature close)

Closing `just check` exposed 5 failures + 2 LOADERR. Root cause for all was
DE-006's own `check` → batch (noninteractive) rename, plus one latent DE-003
regression the rename un-masked.

### Fix 1 — LOADERR double-load (`dev/dl-test.el`)
- `ert-deftest`'s "redefined (or loaded twice)" guard only fires under
  `noninteractive`. The old emacsclient `check` (interactive) tolerated it
  silently; batch `check` makes it a hard error.
- Mechanism: sibling suite files `(require 'dl-satan-intervention-test)` /
  `(require 'dl-satan-tools-content-test)` for fixture macros. The sibling
  sorts earlier in `directory-files`, so it `require`s (loads + defines tests +
  `provide`s) the target before the loop reaches it; the loop then `load`s it
  again → first `ert-deftest` redefines → error aborts that file's load.
- Fix: suite loop skips files whose feature is already `provide`d
  (`featurep` on basename). Idempotent; tests defined exactly once.
- Collateral: this also resolved 4 "flaky" failures
  (intervention/rebuild-refuses, memory-migrate/applies-real,
  renormalize/idempotent, renormalize/no-op) — they were running against a
  half-loaded file from the aborted second load.

### Fix 2 — DE-003 regression (`satan/dl-satan-patch-store.el`)
- `dl-satan-tools-patch/status-and-result-round-trip` asserts a queued job has
  empty `:review_commands`. It was previously skip-gated (DB unreachable);
  DE-006's DB-host isolation un-skipped the DB suite and surfaced the failure.
- DE-003 (655b71e) unified `--build-review-commands` and dropped the
  `(consp commits)` precondition from the tool path, so queued jobs emitted
  diff/log. Tool docstring still claimed "empty until commits" → drift.
- Fix: restored `(consp commits)` to the guard in
  `dl-satan-patch--build-review-commands`. Runner path unaffected (it only
  calls during assemble-result, where commits exist); zero-commit runs now
  correctly yield empty review_commands.

### Results
- `just check`: PASS 920/923, 0 unexpected, 3 skipped (real-PG/real-pi
  integration — expected), no LOADERR.
- Both touched files byte-compile with zero warnings.
