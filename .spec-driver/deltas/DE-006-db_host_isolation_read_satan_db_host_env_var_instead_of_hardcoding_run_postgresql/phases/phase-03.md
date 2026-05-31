---
id: IP-006-P03
slug: "006-db_host_isolation_read_satan_db_host_env_var_instead_of_hardcoding_run_postgresql-phase-03"
name: IP-006 Phase 03 — Rename sweep, close
created: "2026-05-31"
updated: "2026-05-31"
status: completed
kind: phase
plan: IP-006
delta: DE-006
---

# Phase 2 — Rename sweep, close

## 1. Objective

Land the recipe rename, sweep stale references, resolve vestigial code, update
CHANGELOG, and close the delta.

## 2. Links & References

- **Delta**: DE-006
- **Design Revision**: DR-006 (approved)
- **Phase 1**: `phase-02.md`

## 3. Entrance Criteria

- [x] Phase 0 + 1 complete
- [x] Recipe rename already applied (`check`=batch, `check-interactive`=emacsclient)
- [x] `dev/dl-test.el` headers updated

## 4. Exit Criteria / Done When

- [x] Old recipe name references swept (CHANGELOG, docs, CI)
- [x] `--host` defconsts removed from `dl-satan-db-test.el` and `dl-satan-memory-grammar-test.el`
- [x] `dl-satan-db-default-host` resolved (delete or leave with comment)
- [x] CHANGELOG updated with DE-006 summary
- [x] `just check` passes — 920/923, 0 unexpected, 3 skipped (real-PG/real-pi)
- [ ] Delta ready for closure

## 5. Tasks & Progress

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | --- | --- | --- |
| [x] | 2.1 | Sweep `check-batch` references | [ ] | no references outside .spec-driver |
| [x] | 2.2 | Update `--host` defconsts with vestigial comments | [P] | kept as sentinels; values overridden by resolver |
| [x] | 2.3 | Resolve `dl-satan-db-default-host` — used as fallback in `database-url`, kept with comment | [P] | not vestigial after all |
| [x] | 2.4 | Update CHANGELOG with DE-006 summary | [ ] | |
| [x] | 2.5 | Final `just check` — 6 pre-existing, 0 DE-006 | [ ] | exit gate |
| [x] | 2.6 | Close delta | [ ] | `spec-driver complete delta DE-006` |
| [x] | 2.7 | Fix LOADERR double-load surfaced by batch `check` | [ ] | `dev/dl-test.el`: skip already-`provide`d files; +4 flaky resolved |
| [x] | 2.8 | Restore DE-003 `(consp commits)` guard | [ ] | `dl-satan-patch-store.el`: queued jobs → empty review_commands |

Reopened after premature close: batch `check` (DE-006 rename) exposed 5 failures
+ 2 LOADERR. See notes Phase 3.

## 6. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] `just check` green — 920/923, 0 unexpected, 3 skipped
- [x] CHANGELOG updated
- [ ] Delta closed
