---
id: IP-002-P02
slug: "002-satan_attrd_integration_tests_leak_test_uuid_rows_into_production_satan_memory-phase-02"
name: IP-002 Phase 02
created: "2026-05-30"
updated: "2026-05-30"
status: completed  # one of: completed | deferred | draft | in-progress | pending
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

- [x] `cleanup_scope` + `cleanup_run` defs removed from `tests/common/mod.rs`.
- [x] All 24 direct `common::cleanup_*` tail calls removed (store 11, decay 5, dispatcher 8) + `run_loop.rs` import edited; run_loop's local `cleanup()` wrapper + its 4 call sites removed (see DEC `2026-05-30`).
- [x] DEC-5 isolation **kept**: `unique_scope`, `unique_run_id`, `upsert_raw`, `select_raw`, `REBUILD_LOCK`, `DECAY_TEST_LOCK`, `PROJECTION_LOCK`, snapshot/restore — untouched.
- [x] `Justfile`: comment noting `DATABASE_URL` is a server pointer (db component ignored — tests self-provision).
- [x] Full integration suite green: `cargo test --test '*'` → **42 passed** (decay 12, dispatcher 8, harness 4, run_loop 5, store 13); unit/bins **69 passed**.
- [x] `just check` green: clippy exit 0 (`-D unwrap_used -D expect_used`; pedantic `-W` only — pre-existing cast warns, none introduced); `cargo fmt --check` clean. No dangling bindings.
- [x] Post-run prod check: `SELECT count(*) FROM satan_attributes WHERE scope LIKE 'test:%'` == **0** before and after, under prod-pointing `DATABASE_URL` (VT-suite-green).

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
| [x] | 2.1 | Delete `cleanup_scope` + `cleanup_run` defs (`tests/common/mod.rs`, incl. doc comment) | [ ] | self-contained; no helper deps |
| [x] | 2.2 | Delete 11 calls in `tests/store.rs` | [P] | mix scope/run; qualified `common::` |
| [x] | 2.3 | Delete 5 calls in `tests/decay.rs` | [P] | all `cleanup_scope`, qualified |
| [x] | 2.4 | Delete 8 calls in `tests/dispatcher.rs` | [P] | all `cleanup_run`, qualified |
| [x] | 2.5 | `tests/run_loop.rs`: remove local `cleanup()` wrapper + 4 call sites; drop `cleanup_run` from `use`; update module doc | [P] | wrapper bundled cleanup_run + audit/outcome inbox deletes (DEC below) |
| [x] | 2.6 | `Justfile`: comment `DATABASE_URL` = server pointer (db component ignored) | [P] | doc-only |
| [x] | 2.7 | Run full suite + clippy + fmt; confirm prod `test:%` == 0; capture evidence | [ ] | gate — VT-suite-green PASS |

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

- `2026-05-30` — Direct `common::cleanup_*` tail-call count is **24** (store 11, decay 5, dispatcher 8), not the ~21 estimated in the P01 handoff. Store carried 11 (4 scope + 7 run), not ≈8.
- `2026-05-30` — **run_loop: removed the whole local `cleanup()` wrapper, not just the `cleanup_run` line** (user decision, this session). `run_loop.rs` had no direct `cleanup_run` tail — its only use was one line inside a local `cleanup()` helper that *also* deleted `satan_audit_inbox`/`satan_outcome_inbox` rows. All five deletions across that file are post-assertion tails on a disposable per-test DB → pure leak-hygiene. Removing the wrapper + its 4 call sites is faithful to DE-002's intent (DEC-5 preserves redundant *isolation*; this is *hygiene*) and avoids leaving a confusing half-wrapper. Bare ad-hoc hygiene DELETEs not wired to `cleanup_*` were left as-is and out of scope: `run_loop.rs` L380 (`satan_audit_inbox`) and `store.rs` `get_setting_bool_…` settings delete — both fall under "other apparatus = future delta".

## 10. Findings / Research Notes

- Defs were `cleanup_scope`/`cleanup_run` in `tests/common/mod.rs`; both raw `sqlx::query` DELETEs, no shared deps → safe straight delete.
- `run_loop.rs` was the only site importing `cleanup_run` by name (`use common::{…}`); the other three files called via qualified `common::` path → no `use` edit there.
- No `cleanup_*` references in `src/` or `tests/harness.rs` — strictly test-tail hygiene, as DR-002 §4 asserts.
- Deleting tail calls left **no** unused `scope`/`run_id`/`pool` bindings — every binding still feeds its test's assertions (the §6 STOP condition never triggered).
- `cargo fmt` collapsed the blank lines left by tail deletion; no manual whitespace cleanup needed.

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Verification evidence stored in `notes.md` + §4 above
- [x] DR/IP/coverage updated (VT-suite-green → verified, IP §9 P02 checkbox)
- [ ] Hand-off / close-out: route `/audit-change` → `/close-change` (delta closure)
