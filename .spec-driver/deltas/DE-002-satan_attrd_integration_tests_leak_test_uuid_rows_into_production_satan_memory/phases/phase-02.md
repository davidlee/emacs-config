---
id: IP-002-P02
slug: "002-satan_attrd_integration_tests_leak_test_uuid_rows_into_production_satan_memory-phase-02"
name: IP-002 Phase 02
created: "2026-05-30"
updated: "2026-05-30"
status: draft  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-002
delta: DE-002
---

# Phase 02 — Call-site migration & verification

## 1. Objective

Delete the now-dead `cleanup_*` apparatus across the satan-attrd integration
suite, leaving per-test disposable DBs (P01 engine) as the sole isolation
mechanism for row leakage. Remove the two `cleanup_*` defs and all 25 tail
calls; keep the redundant in-process isolation (DEC-5). End state: full
integration suite green, `just check` green, production `satan_memory` gains
**zero** new `test:%` rows (VT-suite-green). Mechanical deletion against a
proven engine — no design latitude.

## 2. Links & References

- **Delta**: DE-002
- **Design Revision Sections**: DR-002 §4 (code-impact table), §7 DEC-5 (keep redundant isolation; delete only `cleanup_*`).
- **Specs / PRODs**: none; traces to ISSUE-003. Coverage artefact: VT-suite-green.
- **Support Docs**: `phases/phase-01.md` §9/§10 (engine decisions, sqlx socket caveat); `~/dev/satan-attrd/AGENTS.md` (clippy `-D unwrap_used -D expect_used`, test rules); `~/dev/satan-attrd/Justfile`.

## 3. Entrance Criteria

- [x] P01 complete — harness engine proven green (satan-attrd `1600e90`; full suite 42 passed)
- [x] `cleanup_*` call sites enumerated (defs ×2, calls ×25; see §7)
- [x] No `cleanup_*` refs outside test call sites (`src/`, `tests/harness.rs` clean)

## 4. Exit Criteria / Done When

- [ ] `cleanup_scope` + `cleanup_run` defs removed from `tests/common/mod.rs`.
- [ ] All 25 `cleanup_*` tail calls removed (store 11, decay 5, dispatcher 8, run_loop 1) + `run_loop.rs:16` import edited.
- [ ] DEC-5 isolation **kept**: `unique_scope`, `unique_run_id`, `upsert_raw`, `select_raw`, `REBUILD_LOCK`, `DECAY_TEST_LOCK`, snapshot/restore — untouched.
- [ ] `Justfile`: comment noting `DATABASE_URL` is a server pointer (db component ignored — tests self-provision).
- [ ] Full integration suite green: `cargo test --test '*'`.
- [ ] `just check` green (clippy `-D unwrap_used -D expect_used` + fmt) — no newly-unused `scope`/`run_id`/`pool` bindings left dangling.
- [ ] Post-run prod check: `SELECT count(*) FROM satan_attributes WHERE scope LIKE 'test:%'` == 0 (VT-suite-green).

## 5. Verification

- `cargo test --test '*'` (with prod-pointing `DATABASE_URL=postgres:///satan_memory?host=/run/postgresql`) — full suite green on throwaway DBs.
- `just check` — clippy + fmt clean (zero warnings).
- Prod leak probe before/after: `psql .../satan_memory -tAc "SELECT count(*) FROM satan_attributes WHERE scope LIKE 'test:%'"` — must read 0 after the run (VT-suite-green).
- Evidence: capture suite pass count, `just check` exit, and prod count in `notes.md` §Phase 02 evidence.

## 6. Assumptions & STOP Conditions

- Assumptions: P01 engine unchanged; every test's `scope`/`run_id` is still consumed by its own assertions (so deleting the cleanup tail leaves no orphan binding); `just check` == clippy + fmt (confirm `Justfile`).
- STOP when: a test relied on `cleanup_*` for *intra-test* correctness (not just tail hygiene) — i.e. removing it changes an assertion outcome rather than only leaving a warning. Surface via `/consult` rather than mutating test logic.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [ ] | 2.1 | Delete `cleanup_scope` + `cleanup_run` defs (`tests/common/mod.rs:248–266`, incl. doc comment) | [ ] | self-contained; no helper deps |
| [ ] | 2.2 | Delete 11 calls in `tests/store.rs` (L84,165,223,268,335,400,484,485,552,553,628) | [P] | mix scope/run; qualified `common::` |
| [ ] | 2.3 | Delete 5 calls in `tests/decay.rs` (L125,153,177,211,245) | [P] | all `cleanup_scope`, qualified |
| [ ] | 2.4 | Delete 8 calls in `tests/dispatcher.rs` (L138,183,214,241,287,379,476,524) | [P] | all `cleanup_run`, qualified |
| [ ] | 2.5 | Delete call in `tests/run_loop.rs:78` + drop `cleanup_run` from `use common::{…}` (L16) | [P] | named import — must edit `use` list |
| [ ] | 2.6 | `Justfile`: comment `DATABASE_URL` = server pointer (db component ignored) | [P] | doc-only |
| [ ] | 2.7 | Run full suite + `just check`; confirm prod `test:%` == 0; capture evidence | [ ] | gate — VT-suite-green |

### Task Details

- **2.1 Delete defs**
  - **Design / Approach**: remove `tests/common/mod.rs:248–266` (the `/// Delete every row…` doc comment + both `pub async fn cleanup_scope` / `cleanup_run` bodies). Verified self-contained (raw `sqlx::query` DELETEs; no shared helper).
  - **Files / Components**: `tests/common/mod.rs`.
  - **Testing**: compile — no remaining referent after 2.2–2.5.
- **2.2–2.5 Delete tail calls**
  - **Design / Approach**: delete each `common::cleanup_*(…).await;` line (and the bare `cleanup_run(pool, run_id).await;` in run_loop). In `run_loop.rs` also strip `cleanup_run` from the `use common::{cleanup_run, shared_pool, unique_run_id};` list. Do **not** remove the `scope`/`run_id`/`pool` bindings themselves — they feed the test's real assertions. If clippy flags one as newly-unused, that test used the binding *only* for cleanup → STOP per §6 (unexpected; investigate, don't silently `_`-prefix).
  - **Files / Components**: `tests/store.rs`, `tests/decay.rs`, `tests/dispatcher.rs`, `tests/run_loop.rs`.
  - **Testing**: per-file `cargo test --test <name>` after edit; full suite at 2.7.
  - **Parallelism**: 2.2–2.6 are independent files → `[P]`. If dispatching to sub-agents, **pin absolute `~/dev/satan-attrd/` paths** in each prompt (memory `feedback_subagent_worktree_pinning`).
- **2.6 Justfile comment**
  - **Design / Approach**: one comment line by the `DATABASE_URL` definition: tests ignore the db component and self-provision `satan_attrd_test_*`; the URL only locates the server/role. Keep DEC-5 framing — not a behaviour change.
- **2.7 Verification gate**
  - **Testing**: `cargo test --test '*'` (42 tests expected); `just check`; prod `test:%` probe == 0. Capture in `notes.md`.

_(2.2–2.6 parallelisable; 2.1 lands with or after them to avoid a transient unused-fn warning; 2.7 last.)_

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| Deleting a cleanup tail leaves a now-unused `scope`/`run_id` binding → clippy warn | Inspect each; bindings feed assertions, not just cleanup. If genuinely orphaned, STOP (§6) — don't auto-`_`-prefix | open |
| Transient `unused fn cleanup_*` warning if defs deleted before calls | Land 2.1 alongside/after 2.2–2.5, or run gate only after all deletions | open |
| sqlx ignores `?host=` socket param (CI portability) | Out of scope for P02 (Sleipnir has `/var/run`→`/run`); memory `mem.fact.satan-attrd.sqlx-socket-host` carries it for ops | carried |
| A test depended on cleanup for intra-test state, not tail hygiene | §6 STOP condition; `/consult` before altering test logic | open |

## 9. Decisions & Outcomes

- `2026-05-30` — Call count is **25** (store 11, decay 5, dispatcher 8, run_loop 1), not the ~21 estimated in the P01 handoff. Confirmed by `rg`; store carried 11 (3 scope + 8 run), not ≈8.

## 10. Findings / Research Notes

- Defs at `tests/common/mod.rs:250` (`cleanup_scope`) / `:258` (`cleanup_run`); both raw `sqlx::query` DELETEs, no shared deps → safe straight delete.
- `run_loop.rs` is the only site importing `cleanup_run` by name (`use common::{…}`, L16); the other three files call via qualified `common::` path → no `use` edit there.
- No `cleanup_*` references in `src/` or `tests/harness.rs` — strictly test-tail hygiene, as DR-002 §4 asserts.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored in `notes.md`
- [ ] DR/IP/coverage updated (VT-suite-green → status, IP §9 P02 checkbox)
- [ ] Hand-off / close-out: route `/audit-change` → `/close-change` (delta closure)
