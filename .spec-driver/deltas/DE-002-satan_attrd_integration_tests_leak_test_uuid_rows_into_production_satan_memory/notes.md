# Notes for DE-002

## New Agent Instructions

### Task card

- **Delta**: `DE-002` — satan-attrd integration tests leak `test:<uuid>` rows into production `satan_memory`.
- **Backlog source**: `ISSUE-003`.
- **State**: P01 (harness engine) **implemented + committed + phase completed** (12/12). Next = **P02 call-site migration** (needs a phase-02 sheet first).

### Required reading (in order)

1. `DE-002.md` — scope, two-defect framing, acceptance criteria.
2. `DR-002.md` — **canonical design (v2)**. §4.1 harness pseudocode, §4.2 sweep, §4.3 rejected alts, §5 verification, §7 decisions (DEC-1..6).
3. `IP-002.md` — phase plan; **§P02 specs the next phase** (call-site migration, VT-suite-green).
4. `phases/phase-01.md` — **completed** P01 sheet — read §9 Decisions + §10 Findings (sqlx socket caveat, accumulation) before P02.

### Related documents

- `ISSUE-003` (`.spec-driver/backlog/issues/`) — symptom, root cause, fix options.
- `POL-001` (SATAN module extraction policy) — reviewed, **not in conflict** (satan-attrd is already an extracted module; this is test-isolation, not extraction).

### Key files (code repo: `~/dev/satan-attrd/` — SEPARATE git repo)

- `tests/common/mod.rs:35` — `shared_pool()` (per-test pool; rewrite target). Also `cleanup_scope`/`cleanup_run` (delete), `unique_scope`/`unique_run_id`/`upsert_raw`/`select_raw` (keep).
- `tests/{store,decay,dispatcher,run_loop}.rs` — ~21 `cleanup_*` tail calls to delete; 38 `shared_pool().await` call sites total.
- `src/store.rs:497` — `rebuild_projection` zeroes the **whole** `satan_attributes` table across scopes (the latent cross-test race per-test DBs dissolve).
- `migrations/0007_attributes.sql` (seeds 8 globals), `0012_attribute_settings.sql` (seeds settings).
- `.envrc` (prod `satan_memory` URL — the leak vector), `Justfile` (supabase-local URL; clippy `-D unwrap_used -D expect_used`), `AGENTS.md`, `HANDOVER.md`.

### Relevant memories

- `feedback_subagent_worktree_pinning` — **pin absolute `~/dev/satan-attrd/` paths in any subagent prompt**; worktree isolation flag unreliable. Directly applies if dispatching P01/P02 to sub-agents.

### Relevant doctrine

- Commit policy: small frequent `.spec-driver/**` commits; keep worktree clean.
- Cross-repo rule (satan-attrd AGENTS.md): code commits in satan-attrd; never write `~/.emacs.d/` from that repo's commit. Don't `git stash` (HOME is a git repo).
- `boot` + `using-spec-driver` routing mandatory at session start.

### User decisions locked

- Strategy **C** (disposable test DB), **per-test** granularity (DEC-2).
- Admin conn **derived from `DATABASE_URL`** db→`postgres` (DEC-3).
- **Keep** redundant isolation (`unique_scope`/`REBUILD_LOCK`/`DECAY_TEST_LOCK`/snapshot); **delete only `cleanup_*`** (DEC-5). Apparatus removal = future delta.
- External codex/gpt-5.5 review **was run** (user authorised; separate billing) — integrated into DR-002 v2.

### Incomplete work / loose ends

- **P01 (harness engine) — DONE** (`tests/common/mod.rs` + `tests/harness.rs`, satan-attrd). All three carry-forwards resolved (below).
- **P02 (call-site migration) — outstanding.** Delete `cleanup_*` defs + ~21 tail calls; keep redundant isolation (DEC-5); `Justfile` comment.
- ~~`SWEEP_MARGIN_MS` default~~ — **resolved**: `const SWEEP_MARGIN_MS: u64 = 60_000` (no env override).
- ~~`with_db` return type~~ — **resolved**: returns `PgConnectOptions`; callers `connect_with`.
- ~~STOP/CREATEDB~~ — **cleared**: role `david` has CREATEDB (`rolcreatedb=t`); gate passed, no escalation.

### Phase 01 evidence (2026-05-30)

- Gate 1.1: `psql .../postgres -tAc "SELECT current_user, rolcreatedb ..."` → `david|t`.
- `cargo test --test harness` (with `DATABASE_URL=postgres:///satan_memory?host=/run/postgresql`) → **4 passed** (VT-with-db ×2, VT-no-prod, VT-sweep-gc).
- `cargo test --test '*'` (same prod URL) → **42 passed** (decay 12, dispatcher 8, harness 4, run_loop 5, store 13). Existing call sites already run on throwaway DBs.
- `cargo clippy --all-targets --all-features -- -D unwrap_used -D expect_used -W pedantic -A too_many_lines` → **exit 0**, no findings in `common/mod.rs`/`harness.rs`.
- `cargo fmt --all --check` → clean.
- Post-run prod check: `SELECT count(*) FROM satan_attributes WHERE scope LIKE 'test:%'` → **0** (no leak). 40 idle `satan_attrd_test_*` DBs left for next-run sweep (DR §4.2, by design).
- **Sharp edge (new):** sqlx `PgConnectOptions::from_str` ignores the libpq `?host=` socket param — works here only via `/var/run`→`/run` symlink. Memory `mem.fact.satan-attrd.sqlx-socket-host`. Affects CI portability (use `$PGHOST` or tcp URL there).

### Commit-state guidance

- P01 committed: **satan-attrd `1600e90`** (harness code: `tests/common/mod.rs` + `tests/harness.rs`); **~/.emacs.d `b6f9113`** (DE-002 artefacts + memory). Earlier artefact commits: `7e8d7a3`, `1f4b971`, `1c29300`.
- Code commits land in `~/dev/satan-attrd/` per repo doctrine — separate from `.emacs.d` artefact commits. P02 follows the same split.
- **satan-attrd** has a pre-existing staged `flake.lock` (NOT ours) — do not bundle; commit P02 test files by explicit pathspec.
- Pre-existing **unrelated** dirty files in `~/.emacs.d/` (NOT part of DE-002, do not bundle): `.spec-driver/run/events.jsonl` (runtime log churn), `init.el`, untracked `.spec-driver/registry/policies.yaml`, `apps/dl-eca.el`.

## Next Agent Instructions

P01 engine is proven green. Invoke `/using-spec-driver`. No `phases/phase-02.md` exists yet, so route `/plan-phases` (P02 is already fully specced in IP-002 §P02 — objectives + VT-suite-green exit criteria; the sheet is quick) **then** `/execute-phase` for **DE-002 / IP-002 Phase 02**.

Phase 02 = delete the now-dead `cleanup_*` apparatus, in `~/dev/satan-attrd/`:
1. Remove `cleanup_scope`/`cleanup_run` **defs** from `tests/common/mod.rs`.
2. Remove ~21 `cleanup_*(...)` **tail calls**: `tests/store.rs` (≈8), `tests/decay.rs` (5), `tests/dispatcher.rs` (8), `tests/run_loop.rs`.
3. **Keep** redundant isolation per DEC-5 (`unique_scope`, `REBUILD_LOCK`, `DECAY_TEST_LOCK`, snapshot/restore) and `upsert_raw`/`select_raw`/`unique_*`.
4. `Justfile`: comment that `DATABASE_URL` is a server pointer (db component ignored by tests).
5. Re-run full suite + clippy + fmt; confirm prod `test:%` count still 0.

Reference IP-002 §P02 and DR-002 §4 (code-impact table). Engine source of truth: `tests/common/mod.rs` (`shared_pool`/`with_db`/`sweep_stale`/`create_database`) + `tests/harness.rs` (VTs).

Caveat for any CI/portability work: sqlx ignores the socket `?host=` param (memory `mem.fact.satan-attrd.sqlx-socket-host`); on a host without `/var/run`→`/run` use `$PGHOST` or a tcp `DATABASE_URL`.
