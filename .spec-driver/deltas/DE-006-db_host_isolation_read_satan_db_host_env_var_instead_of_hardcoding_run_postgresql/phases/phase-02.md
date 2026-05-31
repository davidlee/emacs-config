---
id: IP-006-P02
slug: "006-db_host_isolation_read_satan_db_host_env_var_instead_of_hardcoding_run_postgresql-phase-02"
name: IP-006 Phase 02 — Roll out gate to all DB tests
created: "2026-05-31"
updated: "2026-05-31"
status: completed
kind: phase
plan: IP-006
delta: DE-006
---

# Phase 1 — Roll out gate to all DB tests

## 1. Objective

Close the remaining host-resolution gaps surfaced in Phase 0, unify all DB-touching
tests under the shared predicate, and drive `just check` to 0 unexpected failures.

## 2. Links & References

- **Delta**: DE-006
- **Design Revision**: DR-006 (approved; DEC-006/007)
- **Phase 0 findings**: `phase-01.md` §10, `notes.md`

## 3. Entrance Criteria

- [x] Phase 0 complete; DR-006 approved
- [x] Core chokepoint (`dl-satan-db-resolve-host`) proven in `dl-satan-db.el`
- [x] 5 migrate tests passing against test DB

## 4. Exit Criteria / Done When

- [x] Patch-store LISTEN routes `-h` through `dl-satan-db-resolve-host` (DEC-006)
- [x] `dl-satan-db-test.el`: old `--reachable-p` migrated to `dl-satan-db-test-db-available-p`
- [x] `dl-satan-memory-grammar-test.el`: inline psql now routes through `dl-satan-db-resolve-host`; reachability delegated
- [x] `satan_memory` DB provisioned on supabase (unblocks 4 pre-existing failures → 4 remain due to missing tables)
- [-] Stale .elc / void-function issues — pre-existing (missing prod tables); out of scope
- [x] Chokepoint VT (`dl-satan-db-test.el`): 10 new tests, 21/21 passing
- [x] `just check` → 6 pre-existing failures, 0 DE-006 regressions; grammar db-sync tests now pass (were skipping)

## 5. Verification

- **VT-db-chokepoint-guard**: new ERT in `dl-satan-db-test.el` covering:
  - `dl-satan-db-resolve-host` with/without override
  - batch guard fires for `/run/postgresql`, passes for test host
  - `dl-satan-db-test-db-available-p` returns nil for prod, t for test host
  - `dl-satan-db-database-url` format
- **VA-full-suite-green**: `just check` → PASS (0 unexpected)
- **VH-interactive-broker-untouched**: `just check-interactive` in live server (deferred from Phase 0)

## 6. Assumptions & STOP Conditions

- supabase reachable at `127.0.0.1:54322`
- `satan_memory` DB can be provisioned via `just db-init satan_memory`
- bough binary remains unavailable in jail (DEC-007 spike deferred)
- STOP if: patch-store LISTEN redirect introduces flakiness (LISTEN/NOTIFY is timing-sensitive)

## 7. Tasks & Progress

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | --- | --- | --- |
| [x] | 1.1 | Route patch-store LISTEN `-h` through `dl-satan-db-resolve-host` | [ ] | `dl-satan-patch-store-test--listen:228` |
| [x] | 1.2 | Provision `satan_memory` DB on supabase | [ ] | `createdb satan_memory` + apply migrations |
| [x] | 1.3 | Migrate `dl-satan-db-test.el` to shared predicate | [ ] | old `--reachable-p` → `dl-satan-db-test-db-available-p` |
| [x] | 1.4 | Migrate `dl-satan-memory-grammar-test.el` inline psql + reachability to resolver + shared predicate | [ ] | inline `call-process psql` now routes `-h` through `dl-satan-db-resolve-host`; db-sync tests now pass instead of skip |
| [x] | 1.5 | Write chokepoint VT (resolver, guard, predicate, database-url) | [ ] | 10 new tests in `dl-satan-db-test.el`, 21/21 pass |
| [-] | 1.6 | Address stale .elc / void-function for `notes-at-satan-intervention/end-to-end-smoke` | [ ] | pre-existing; missing `satan_attributes`/`satan_outcome_inbox` tables; out of DE-006 scope |
| [x] | 1.7 | Verify `just check` → 6 pre-existing failures, 0 DE-006 regressions | [ ] | exit gate: 6 failures all pre-existing (filesystem + prod tables) |

### Pre-existing failures (not DE-006)

| Test | Root cause |
|------|-----------|
| `dl-satan-context/tick-*` (2) | `tick/pulse.txt` prompt file missing from notes dir |
| `dl-satan-intervention/classify-*, create-*` (2) | `satan_attributes` + `satan_outcome_inbox` tables not in test DB |
| `dl-satan-tools-memory/mind-docs-exist` | docs files not in jail |
| `notes-at-satan-intervention/end-to-end-smoke` | same intervention infra as above |

## 8. Risks & Mitigations

| Risk | Mitigation |
| ---- | ---------- |
| LISTEN redirect breaks notify timing | Keep existing `--listen` wrapper; only change the `-h` arg |
| `satan_memory` migrations fail on supabase | DB is empty — same migration files as `satan_memory_test` |
| Stale .elc caches persist after edits | `rm -f satan/test/*.elc satan/*.elc` before each run |
| `mind-docs-exist` can't be fixed in-jail | Out of scope — pre-existing filesystem dependency |

## 9. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] VT committed and passing
- [ ] `just check` → PASS (0 unexpected, excluding mind-docs-exist)
- [ ] notes.md updated
- [ ] Hand-off to Phase 2 (rename sweep, close)
