---
id: DR-002
slug: satan_attrd_integration_tests_leak_test_uuid_rows_into_production_satan_memory
name: "Design Revision - satan-attrd integration tests leak test:<uuid> rows into production satan_memory"
created: "2026-05-30"
updated: "2026-05-30"
status: draft
kind: design_revision  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
aliases: []
owners: []
relations:
  - type: implements
    target: DE-002
delta_ref: DE-002
source_context:
  - type: issue
    id: ISSUE-003
code_impacts:
  - path: tests/common/mod.rs
    current_state: shared_pool connects $DATABASE_URL (maybe prod) and migrates; cleanup_* helpers delete rows
    target_state: shared_pool self-provisions a per-test disposable DB (epoch-named), age-filtered sweep, current_database guard; cleanup_* removed
  - path: tests/store.rs
    current_state: cleanup_scope/cleanup_run at test tails; REBUILD_LOCK + unique_scope
    target_state: cleanup tails removed; REBUILD_LOCK + unique_scope kept (redundant)
  - path: tests/decay.rs
    current_state: cleanup_scope at test tails; DECAY_TEST_LOCK + snapshot/restore
    target_state: cleanup tails removed; lock + snapshot/restore kept (redundant)
  - path: tests/dispatcher.rs
    current_state: cleanup_run at test tails
    target_state: cleanup tails removed
  - path: tests/run_loop.rs
    current_state: cleanup_run at test tails
    target_state: cleanup tails removed
  - path: Justfile
    current_state: exports DATABASE_URL to supabase-local
    target_state: same value; comment that DATABASE_URL is a server pointer (db component ignored by tests)
design_decisions:
  - id: DEC-1
    summary: strategy C disposable test DB over A tx-rollback / B RAII guard
  - id: DEC-2
    summary: per-test DB (matches shared_pool's per-test contract); dissolves the rebuild-zeroes-table cross-test race
  - id: DEC-3
    summary: admin connection derived from DATABASE_URL by swapping db to postgres
  - id: DEC-4
    summary: GC via epoch-named, age-filtered sweep-on-init; lock-free; in-use DROP failure as backstop
  - id: DEC-5
    summary: keep redundant intra-test isolation (unique_scope/REBUILD_LOCK/DECAY_TEST_LOCK/snapshot); delete only cleanup_* (smallest correct diff)
  - id: DEC-6
    summary: reject sqlx::test — it writes _sqlx_test metadata into the DATABASE_URL db (prod)
verification_alignment:
  - verification: VT-no-prod
    impact: new
    note: headline — shared_pool asserts current_database() == generated test DB before migrate; never satan_memory
  - verification: VT-sweep-gc
    impact: new
    note: sweep reclaims an old epoch-named stray DB and skips a recent / in-use one
  - verification: VT-with-db
    impact: new
    note: unit test with_db() rewrites both socket (?host=) and tcp DATABASE_URL forms correctly
open_questions: []
---

# DR-002 – satan-attrd integration tests leak test:<uuid> rows into production satan_memory

> Revision history: v2 integrates an external hostile review (codex/gpt-5.5).
> Two blockers fixed — the design is now explicitly **per-test** (matching
> `shared_pool`'s actual contract) and adds a hard `current_database()` guard.
> The advisory lock was removed in favour of a lock-free epoch-filtered sweep.

## 1. Executive Summary

- **Delta**: [DE-002](./DE-002.md)
- **Status**: draft (update when approved)
- **Repo**: code in `~/dev/satan-attrd/` (separate git repo); artefacts here in `~/.emacs.d/`.
- **Last Updated**: 2026-05-30
- **Synopsis**: Each integration **test** self-provisions a throwaway database
  `satan_attrd_test_<epoch_ms>_<uuid>` from an admin connection derived from
  `DATABASE_URL`, asserts it is connected to that database (never `satan_memory`),
  migrates+seeds it, and runs against it. Production ceases to be a write target by
  construction; per-test `cleanup_*` bookkeeping is deleted because a disposable
  database makes panic-leaks impossible. A lock-free, age-filtered sweep reclaims
  databases left by prior runs.

## 2. Problem & Constraints

- **Current Behaviour**: Tests connect to `$DATABASE_URL` (`common::shared_pool`,
  `tests/common/mod.rs:35`). In the dev shell `.envrc` sets that to
  `postgres:///satan_memory?host=/run/postgresql` — **production**. Per-test
  isolation is `unique_scope()`/`unique_run_id()` plus a **best-effort inline
  `cleanup_*` call at each test tail**. Any panic/assert-fail before that line
  orphans rows. Observed 2026-05-30: 3 leaked `test:<uuid>` scopes / 12 rows from
  one failed run, polluting drift/observability reads of `satan_attributes`.
- **Two distinct defects** (the issue named only the second):
  1. **Targeting** — bare `cargo test` can write production at all (env/config).
  2. **Panic-leak** — even in the correct DB, a failing test orphans rows (isolation).
- **A third, latent defect surfaced during review**: `store::rebuild_projection`
  (`src/store.rs:497`) zeroes **every row in `satan_attributes` across all scopes**
  in step 1 of its transaction. The test suite only serialises rebuild-vs-rebuild
  (`REBUILD_LOCK`, `tests/store.rs:23`; `DECAY_TEST_LOCK`, `tests/decay.rs:23`); a
  `check_due_*` test at a unique scope (which deliberately skips the lock) can have
  its rows zeroed by a parallel rebuild test. On a **shared** database this is a
  real cross-test race — present today against prod. Only **per-test databases**
  remove it.
- **Drivers / Inputs**: ISSUE-003. Three conflicting `DATABASE_URL` notions found:
  `.envrc` → `satan_memory` (prod); `Justfile` → `…@127.0.0.1:54322/postgres`
  (supabase-local); `HANDOVER.md` → `satan_memory_test` (intended). The active
  `.envrc` prod URL is how the leak reached production.
- **Constraints / Guardrails**:
  - clippy `-D clippy::unwrap_used -D clippy::expect_used` is non-negotiable
    (satan-attrd `AGENTS.md`). `tests/common/mod.rs` `#![allow]`s both for the
    module; new harness code stays inside that module so `.unwrap()` on setup is
    permitted (setup failure should abort the test anyway).
  - `just check` (lint + format + test) must stay green.
  - No auto-migrate on daemon start (unchanged).
  - Cross-repo: code commits land in `satan-attrd`; never write `~/.emacs.d/` from
    that repo's commit.
- **Out of Scope**:
  - Immediate remediation flush of existing orphans
    (`DELETE FROM satan_attributes WHERE scope LIKE 'test:%'`) — destructive prod
    write, human-run, tracked on ISSUE-003.
  - Broker (elisp) changes; attribute semantics / design-contract changes.
  - Deleting the now-redundant intra-test isolation apparatus (DEC-5) — deferred to
    a follow-up delta to keep this change's blast radius minimal.

## 3. Architecture Intent

- **Target Outcomes**:
  - Integration tests can **never** write production `satan_memory`. The harness
    connects only to the maintenance db `postgres` (to administer) and to its own
    generated `satan_attrd_test_*` database — and *asserts* the latter before any
    write.
  - A panicking/failing test **leaves no orphaned rows** — its entire database is
    disposable and reclaimed.
  - The rebuild-zeroes-table cross-test race is dissolved: each test owns its DB.
  - `DATABASE_URL` collapses to one meaning: a **server pointer**; its database
    component is ignored by tests.
- **Guiding Principles**:
  - Isolation by **disposal**, not bookkeeping. Cheapest correct end state.
  - Safety **by construction** (harness never targets the prod name) plus a hard
    runtime assertion, over safety by caller discipline.
- **Lifecycle Impact**: test databases are ephemeral — created per test, reclaimed
  by a later run's sweep.

## 4. Code Impact Summary

| Path | Current State | Target State |
| --- | --- | --- |
| `tests/common/mod.rs` `shared_pool()` | connect `$DATABASE_URL` (maybe prod); migrate; return pool | derive admin URL (db→`postgres`); sweep stale (age-filtered); `CREATE DATABASE … TEMPLATE template0`; connect pool; **assert `current_database()` == generated name**; migrate; return pool |
| `tests/common/mod.rs` `cleanup_scope`/`cleanup_run` | delete rows for a scope/run | **removed** (dead once DB is disposable) |
| `tests/common/mod.rs` `unique_scope`/`unique_run_id`/`upsert_raw`/`select_raw` | helpers | **kept** unchanged |
| `tests/store.rs` | `cleanup_scope`/`cleanup_run` at tails (≈8); `REBUILD_LOCK` | cleanup tails removed; `REBUILD_LOCK`/`unique_scope` **kept** (DEC-5) |
| `tests/decay.rs` | `cleanup_scope` at tails (5); `DECAY_TEST_LOCK` + snapshot/restore | cleanup tails removed; lock + snapshot/restore **kept** (DEC-5) |
| `tests/dispatcher.rs` | `cleanup_run` at tails (8) | tail calls removed |
| `tests/run_loop.rs` | `cleanup_run` at tails | tail calls removed |
| `Justfile` | `export DATABASE_URL := …54322/postgres` | unchanged value; comment: tests treat `DATABASE_URL` as a server pointer and derive their own DB |

### 4.1 Harness design (per-test)

`shared_pool()` is called **once per `#[tokio::test]`** (38 call sites; per-test
pools are deliberate — a static pool outlives the per-test tokio runtime,
`tests/common/mod.rs:35`). Each call therefore provisions a **fresh disposable
database**, giving every test total isolation.

```rust
// Process start, captured once — the sweep age cutoff.
static PROC_START_MS: Lazy<u64> = Lazy::new(epoch_ms);
static SWEPT: OnceCell<()> = OnceCell::const_new();   // sweep at most once per process

// with_db: keep host/socket/creds/params of `url`, replace only the db name.
// Implement via sqlx PgConnectOptions (.database(db)) rather than string surgery,
// so the socket form `postgres:///x?host=/run/postgresql` is handled correctly.
fn with_db(url: &str, db: &str) -> String { /* parse PgConnectOptions; .database(db); re-encode */ }

pub async fn shared_pool() -> PgPool {
    init_log();
    let base = std::env::var("DATABASE_URL")
        .expect("DATABASE_URL must be set (server pointer; its db component is ignored)");

    let mut admin = PgConnection::connect(&with_db(&base, "postgres")).await.unwrap();
    SWEPT.get_or_init(|| async { sweep_stale(&mut admin).await }).await;   // §4.2

    let name = format!("satan_attrd_test_{}_{}", *PROC_START_MS, Uuid::new_v4().simple());
    debug_assert!(name.starts_with("satan_attrd_test_"));
    // CREATEDB failure surfaces here with a clear message (see note below).
    create_database(&mut admin, &name).await;            // CREATE DATABASE "name" TEMPLATE template0

    let pool = PgPoolOptions::new().max_connections(2)
        .connect(&with_db(&base, &name)).await.unwrap();

    // HARD GUARD: refuse to migrate/write unless we are truly on the throwaway DB.
    let current: String = sqlx::query_scalar("SELECT current_database()")
        .fetch_one(&pool).await.unwrap();
    assert_eq!(current, name, "refusing to run: connected to {current}, not the test DB");

    migrate::run_migrations(&pool).await.unwrap();        // seeds 8 globals + settings
    pool
}
```

- **`current_database()` guard before migrate** (review finding 4): the name-prefix
  check is insufficient — a botched `with_db()` could connect us elsewhere. Asserting
  the live connection's actual database closes that hole.
- **`TEMPLATE template0`** (review finding 5): avoids inheriting local `template1`
  mutations and avoids failing when `template1` has sessions.
- **CREATEDB privilege** (review finding 6): `create_database` matches on the sqlx
  error and `panic!`s with an explicit message — *"role lacks CREATEDB; point
  DATABASE_URL at a server/role that can create databases, or set up a dedicated
  test role"* — so the failure is loud and early, not a buried operational note.
  The socket `.envrc` connects as the OS user; that role must have CREATEDB (note
  for IP-002 / machine setup).

### 4.2 Teardown / GC — lock-free, age-filtered

Rust integration tests have **no cross-binary global teardown**. The reclaimer is a
**sweep-on-init that runs at most once per process** (`OnceCell`) and only drops
databases that are **older than this process's start** and **idle**:

```rust
async fn sweep_stale(admin: &mut PgConnection) {
    let cutoff = PROC_START_MS.saturating_sub(SWEEP_MARGIN_MS);   // small margin, e.g. 60_000
    let dbs: Vec<String> = sqlx::query_scalar(
        "SELECT datname FROM pg_database WHERE datname LIKE 'satan_attrd_test_%'")
        .fetch_all(&mut *admin).await.unwrap();
    for db in dbs {
        // Parse the embedded epoch; skip databases created at/after our cutoff
        // (they belong to this run or a concurrent run).
        if epoch_of(&db).map_or(true, |ms| ms >= cutoff) { continue; }
        // Backstop: DROP fails (55006) on a DB with live connections — an idle
        // older DB from a finished prior run drops; anything still in use is skipped.
        let _ = sqlx::query(&format!(r#"DROP DATABASE IF EXISTS "{db}""#))
            .execute(&mut *admin).await;
    }
}
```

- **Why lock-free is safe** (replaces v1's advisory lock; review finding 8):
  - A concurrent run's databases carry a **recent epoch ≥ cutoff** → skipped by age,
    so the create→connect window cannot be swept out from under a sibling.
  - A prior run's databases carry an **old epoch** and are **idle** (their tests
    finished) → dropped. If still in use, the `DROP` fails and is ignored.
  - The `SWEEP_MARGIN_MS` cushions clock granularity and overlapping runs; anything
    missed is reclaimed on the next run. No lock to leak, time-out, or wedge on.
- **Accumulation** (review finding 7): a full run leaves up to `~concurrency` live
  test DBs at a time and up to 38 idle ones until the next run's sweep. Postgres
  handles hundreds of empty databases; the next run reclaims them. Documented, not
  hidden. (Optional future nicety: a best-effort own-DB drop on the happy path; the
  sweep remains the panic-safe backstop. Out of scope for v2.)

### 4.3 Rejected alternatives

- **`sqlx::test`** (review finding 10): tempting — it provisions temp DBs with
  migrations. Rejected (DEC-6) because it writes its `_sqlx_test` bookkeeping into
  the database named by `$DATABASE_URL`, which under the current `.envrc` is
  **`satan_memory` (prod)**. Adopting it safely would still require a non-prod
  admin URL — i.e. the same `with_db` indirection — for no net simplification.
- **Strategy A (tx-rollback)** / **B (RAII row-guard)**: see DEC-1.

## 5. Verification Alignment

| Verification | Impact | Notes |
| --- | --- | --- |
| VT-no-prod | new | **Headline.** The `current_database()` guard in `shared_pool()` *is* the proof in every test; add one focused test asserting the live db matches `satan_attrd_test_%` and `!= 'satan_memory'`. Production is never a write target. |
| VT-sweep-gc | new | Pre-seed two stray DBs: one with an old embedded epoch + no connection (must be reclaimed), one with a recent epoch (must be skipped). Run a `shared_pool()`; assert outcomes. |
| VT-with-db | new | Unit test `with_db()` against both forms: `postgres:///satan_memory?host=/run/postgresql` → `postgres:///postgres?host=…`, and `postgresql://u:p@h:5432/satan_memory` → `…/postgres`. (review finding 9) |
| existing suites | regression | all integration tests pass with `cleanup_*` tails removed; kept isolation is now belt-and-suspenders. |
| gate | manual | `just check` green; post-run `SELECT … FROM satan_attributes WHERE scope LIKE 'test:%'` on prod returns 0 new rows. |

> Panic-safety needs no dedicated test: with per-test disposable DBs and a hard
> `current_database()` guard, a panicking test cannot reach prod and its own DB is
> swept later. The proof reduces to VT-no-prod + VT-sweep-gc + VT-with-db.

## 6. Supporting Context

- Migrations seed all global state a fresh DB needs: `0007_attributes.sql` seeds 8
  globals at `scope='global'`; `0012_attribute_settings.sql` seeds
  `attribute_updates_enabled`. Decay `tick_*` snapshot/restore works on a freshly
  migrated DB. No out-of-band seeding exists.
- `satan-attrd/AGENTS.md` test rule preserved: integration tests need Postgres on
  `$DATABASE_URL`; only the *meaning* of that URL (server vs database) is clarified.

## 7. Design Decisions & Trade-offs

- **DEC-1 — Strategy C (disposable DB)** over A (tx-rollback) / B (RAII guard). A
  needs threading an `Executor`/`&mut PgConnection` through `src/` code-under-test
  and fights the decay `tick_*` writer that hardcodes `Scope::Global` on `&PgPool`;
  B still writes whatever DB the env names and wrestles `Drop`-can't-`await`. C has
  the heaviest setup but the simplest end state.
- **DEC-2 — Per-test DB** (not per-binary). Matches `shared_pool`'s per-test
  contract (the original DR's per-binary framing was wrong) and is the *only* option
  that dissolves the `rebuild_projection` whole-table-zero cross-test race. Cost:
  ~38 `CREATE DATABASE … TEMPLATE template0` + idempotent migrate cycles per run.
  Acceptable — `template0` clone is fast and there are only 6 small migrations; if
  it ever dominates wall-clock, a per-binary pooled DB is the optimisation, but it
  reintroduces the rebuild race and is therefore explicitly not chosen now.
- **DEC-3 — Admin URL derived from `DATABASE_URL`** (db→`postgres`), no new env var.
- **DEC-4 — GC by lock-free, age-filtered sweep-on-init** (once per process via
  `OnceCell`), with the in-use `DROP` failure as a backstop. Replaces v1's advisory
  lock (no RAII / hang risk).
- **DEC-5 — Keep the redundant intra-test isolation** (`unique_scope`,
  `REBUILD_LOCK`, `DECAY_TEST_LOCK`, snapshot/restore); delete only the `cleanup_*`
  apparatus. Smallest correct diff; removing working safety nets in the same change
  as a prod-safety fix is a separate, lower-priority refactor.
- **DEC-6 — Reject `sqlx::test`** (writes `_sqlx_test` into the prod-named DB).

## 8. Open Questions

- (none blocking) `SWEEP_MARGIN_MS` value — pick a conservative default (≈60s) in IP-002.

## 9. Rollout & Operational Notes

- **Migration / Backfill**: none — test-only; no production schema touched.
- **Observability**: prod `satan_attributes` should stop accruing `test:%` scopes.
- **Recovery / Rollback**: revert the harness change; tests fall back to prior
  (leaky) behaviour. Low blast radius — no production code path altered.
- **Permissions**: the admin role needs `CREATEDB`; failure now panics with an
  explicit message. CI roles must also have it (note for IP-002 / machine setup).

## 10. References & Links

- ISSUE-003 (`.spec-driver/backlog/issues/`).
- `~/dev/satan-attrd/tests/common/mod.rs:35`, `tests/{store,decay,dispatcher,run_loop}.rs`.
- `~/dev/satan-attrd/src/store.rs:497` (`rebuild_projection` whole-table zero).
- `~/dev/satan-attrd/{Justfile,.envrc,migrations/0007_attributes.sql,migrations/0012_attribute_settings.sql}`.
- `~/dev/satan-attrd/AGENTS.md`, `HANDOVER.md`.
- External review: codex/gpt-5.5 hostile pass, 2026-05-30 (10 findings; 2 blockers fixed).
