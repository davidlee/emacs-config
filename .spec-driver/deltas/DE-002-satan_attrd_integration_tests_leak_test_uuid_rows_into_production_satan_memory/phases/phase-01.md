---
id: IP-002-P01
slug: "002-satan_attrd_integration_tests_leak_test_uuid_rows_into_production_satan_memory-phase-01"
name: IP-002 Phase 01
created: "2026-05-30"
updated: "2026-05-30"
status: draft  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-002
delta: DE-002
---

# Phase 01 — Harness engine

## 1. Objective

Build per-test disposable-database provisioning in `~/dev/satan-attrd/tests/common/mod.rs`:
URL rewriting, lock-free age-filtered sweep, `CREATE DATABASE … TEMPLATE template0`,
and the `current_database()` guard. Prove it with focused tests **before** touching
the 38 existing call sites (Phase 02). End state: `shared_pool()` returns a pool
bound to a fresh throwaway DB, and production can never be a write target.

## 2. Links & References

- **Delta**: DE-002
- **Design Revision Sections**: DR-002 §4.1 (harness), §4.2 (sweep), §4.3 (rejected alts), §5 (verification).
- **Specs / PRODs**: none; traces to ISSUE-003.
- **Support Docs**: `~/dev/satan-attrd/AGENTS.md` (clippy/test rules), `tests/common/mod.rs:35` (per-test pool rationale), `src/store.rs:497` (rebuild whole-table zero).

## 3. Entrance Criteria

- [x] DR-002 v2 accepted (review integrated)
- [x] IP-002 phase plan written
- [ ] Postgres reachable; admin role has CREATEDB (verify first task)

## 4. Exit Criteria / Done When

- [ ] `with_db()` rewrites both socket (`postgres:///x?host=/run/postgresql`) and tcp (`postgresql://u:p@h:5432/x`) forms — VT-with-db green.
- [ ] `shared_pool()` provisions `satan_attrd_test_<epoch_ms>_<uuid>`, asserts `current_database()` == that name before migrate — VT-no-prod green.
- [ ] `sweep_stale()` drops an old idle stray DB and skips a recent one — VT-sweep-gc green.
- [ ] At least one pre-existing test (e.g. `migration_seeds_eight_global_attributes`) passes unchanged on a throwaway DB.
- [ ] `cargo clippy --all-targets … -D unwrap_used -D expect_used` clean; `cargo fmt --check` clean.

## 5. Verification

- `DATABASE_URL=postgres:///satan_memory?host=/run/postgresql cargo test --test store migration_seeds_eight_global_attributes` — must run on a `satan_attrd_test_*` DB, **not** prod (proves VT-no-prod even when env names prod).
- `cargo test with_db` (unit) — VT-with-db.
- `cargo test sweep` (integration) — VT-sweep-gc.
- After a run: `psql satan_memory -c "SELECT count(*) FROM satan_attributes WHERE scope LIKE 'test:%'"` shows no increase.
- Evidence: capture command output in notes.md.

## 6. Assumptions & STOP Conditions

- Assumptions: admin role has CREATEDB; `template0` exists (default); the socket role can `CREATE DATABASE`.
- STOP when: admin role lacks CREATEDB and no alternative non-prod admin URL is available (raise with user — affects DEC-3); or `with_db` cannot faithfully round-trip the socket form via `PgConnectOptions` (reassess string approach).

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [ ] | 1.1 | Verify Postgres reachable + admin role has CREATEDB | [ ] | gate before coding |
| [ ] | 1.2 | TDD `with_db(url, db)` via `PgConnectOptions`; unit test both URL forms (VT-with-db) | [ ] | red→green→refactor |
| [ ] | 1.3 | Add `epoch_ms`/`epoch_of`, `PROC_START_MS`, `SWEPT` OnceCell, `SWEEP_MARGIN_MS` | [ ] | |
| [ ] | 1.4 | TDD `sweep_stale()` — drop old idle, skip recent/in-use (VT-sweep-gc) | [ ] | seed stray DBs in test |
| [ ] | 1.5 | `create_database()` — `TEMPLATE template0`; explicit CREATEDB-failure panic | [ ] | |
| [ ] | 1.6 | Rewrite `shared_pool()`: admin conn → sweep-once → create → connect → `current_database()` guard → migrate (VT-no-prod) | [ ] | depends 1.2–1.5 |
| [ ] | 1.7 | Smoke: one existing test green on throwaway DB; clippy + fmt clean | [ ] | exit gate |

### Task Details

- **1.2 `with_db`**
  - **Design / Approach**: parse `&str` → `PgConnectOptions` (sqlx `FromStr`), call `.database(db)`, re-encode to a URL string (or return the options directly and have callers connect from options — preferred: return `PgConnectOptions` to avoid a lossy re-encode round-trip). Decide return type during TDD; the unit test asserts the resulting options' `get_database()` and host/socket are preserved.
  - **Files / Components**: `tests/common/mod.rs`.
  - **Testing**: VT-with-db — both forms; assert db swapped, host/socket/creds preserved.
- **1.4 `sweep_stale`**
  - **Design / Approach**: `SELECT datname … LIKE 'satan_attrd_test_%'`; parse epoch from name; skip `epoch >= PROC_START_MS - SWEEP_MARGIN_MS`; `DROP DATABASE IF EXISTS` ignoring in-use (55006) errors.
  - **Testing**: VT-sweep-gc — pre-create `satan_attrd_test_<old>_x` (no conn) and `satan_attrd_test_<recent>_y`; run sweep; assert old gone, recent present. Optionally a third with an open connection asserts in-use skip.
- **1.6 `shared_pool`**
  - **Design / Approach**: per DR-002 §4.1 pseudocode. Hold the admin `PgConnection` for sweep+create. Guard `current_database()` before migrate.
  - **Testing**: VT-no-prod — run with `DATABASE_URL` pointing at prod name; assert the returned pool's `current_database()` matches `satan_attrd_test_%`.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| --- | --- | --- |
| CREATEDB missing on socket role | Task 1.1 gates; explicit panic message | open |
| `with_db` lossy URL re-encode | Prefer returning `PgConnectOptions` over a string round-trip | open |
| Sweep test pollutes other runs | Use clearly old/recent epochs and unique uuids; tests clean their own seeded DBs | open |

## 9. Decisions & Outcomes

- `2026-05-30` — Phase scoped to the harness engine only; call-site migration deferred to P02 so the engine is proven before fan-out.

## 10. Findings / Research Notes

- `shared_pool` is per-test (`tests/common/mod.rs:35`); 38 call sites → per-test DBs (DR-002 DEC-2).
- Migrations seed globals (`0007`) + settings (`0012`); fresh DB is test-ready.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored in `notes.md`
- [ ] DR/IP updated if the engine deviated from design
- [ ] Hand-off note to P02 (call-site migration)
