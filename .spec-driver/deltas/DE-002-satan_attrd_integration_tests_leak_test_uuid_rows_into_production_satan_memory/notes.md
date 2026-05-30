# Notes for DE-002

## New Agent Instructions

### Task card

- **Delta**: `DE-002` — satan-attrd integration tests leak `test:<uuid>` rows into production `satan_memory`.
- **Backlog source**: `ISSUE-003`.
- **State**: scoped + designed + planned. **Not yet implemented.** Next = execute Phase 01.

### Required reading (in order)

1. `DE-002.md` — scope, two-defect framing, acceptance criteria.
2. `DR-002.md` — **canonical design (v2)**. §4.1 harness pseudocode, §4.2 sweep, §4.3 rejected alts, §5 verification, §7 decisions (DEC-1..6).
3. `IP-002.md` — phase plan (P01 harness engine, P02 call-site migration).
4. `phases/phase-01.md` — **active phase sheet**, 7-task breakdown + exit criteria.

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

- All implementation (P01 + P02) outstanding — no code written yet.
- Open: `SWEEP_MARGIN_MS` default (≈60s) — fix in P01 (IP-002 §8).
- Open: `with_db` return type — prefer returning `PgConnectOptions` over a lossy URL re-encode (phase-01 task 1.2 / risk).
- **STOP condition** (phase-01 §6): if admin role lacks `CREATEDB` and no non-prod admin URL exists → raise with user (affects DEC-3). Verify CREATEDB in task 1.1 before coding.

### Commit-state guidance

- Worktree clean for DE-002 artefacts — committed `7e8d7a3`, `1f4b971`, `1c29300`.
- Pre-existing **unrelated** dirty files in `~/.emacs.d/` (NOT part of DE-002, do not bundle): `.spec-driver/run/events.jsonl`, `init.el`, untracked `.spec-driver/registry/policies.yaml`, `apps/dl-eca.el`.
- Code commits land in `~/dev/satan-attrd/` per repo doctrine — separate from these artefact commits.

## Next Agent Instructions

Invoke `/using-spec-driver`, then `/execute-phase` for **DE-002 / IP-002 Phase 01**.

Phase 01 = harness engine, TDD, in `~/dev/satan-attrd/`:
1. Verify Postgres reachable + admin role has CREATEDB (gate; STOP if absent).
2. TDD `with_db()` (both URL forms) → VT-with-db.
3. epoch/`PROC_START_MS`/`SWEPT`/`SWEEP_MARGIN_MS`.
4. TDD `sweep_stale()` (drop old idle, skip recent/in-use) → VT-sweep-gc.
5. `create_database()` `TEMPLATE template0` + explicit CREATEDB-failure panic.
6. Rewrite `shared_pool()` with `current_database()` guard before migrate → VT-no-prod.
7. Smoke one existing test on a throwaway DB; clippy + fmt clean.

Carry forward the two open design points (SWEEP_MARGIN_MS, with_db return type) and the CREATEDB STOP condition — resolve in-phase, escalate if blocked. Do NOT start P02 (call-site deletion) until the engine is proven green.
