---
id: IP-006-P01
slug: "006-db_host_isolation_read_satan_db_host_env_var_instead_of_hardcoding_run_postgresql-phase-01"
name: IP-006 Phase 01
created: "2026-05-31"
updated: "2026-05-31"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase
plan: IP-006
delta: DE-006
---

# Phase 0 — Prototype & validate chokepoint design

## 1. Objective

Prove the DR-006 chokepoint design end-to-end on a thin vertical slice before the full
test-file rollout and recipe rename. De-risk three claims that, if wrong, would invalidate
the whole approach: (a) env-seeded carrier redirects batch to the test DB; (b) batch refuses
the prod socket loudly; (c) a `let`-bound carrier lets the live emacsclient server run DB
tests against the test DB **without disturbing the broker's production connection**.

## 2. Links & References

- **Delta**: DE-006
- **Design Revision Sections**: DR-006 §3 (carrier, chokepoint, predicate, gate table), DEC-002/003/004/005, §6/§7
- **Specs / PRODs**: none (infra)
- **Support Docs**: `satan/dl-satan-db.el` (chokepoint), `dev/dl-test.el` (`dl-test-run-suite`), `Justfile` (`check`/`check-batch`)

## 3. Entrance Criteria

- [x] DR-006 coherent with DE-006 (rewritten this session)
- [x] supabase reachable via `SATAN_DB_HOST` (`just db-start`, `just db-init` available)
- [ ] Working tree clean enough to isolate the prototype hunk

## 4. Exit Criteria / Done When

- [x] `dl-satan-db.el` carries: `dl-satan-db-host-override` defvar (seeded `(getenv "SATAN_DB_HOST")`), `dl-satan-db-resolve-host` (carrier + batch guard), `dl-satan-db-database-url`, `dl-satan-db-test-db-available-p`
- [x] ONE DB test file (`dl-satan-memory-migrate-test.el`) delegates its reachability to the shared predicate
- [x] `check-interactive` recipe exists locally with the `let`-binding `--eval`
- [x] **Claim (a)**: `SATAN_DB_HOST=127.0.0.1 just check` → the 5 migrate tests run and pass
- [x] **Claim (b)**: `env -u SATAN_DB_HOST` batch run → guard fires at fn level; ERT swallows error into skip (no prod connections, but silent rather than loud — pre-flight check deferred to Phase 1)
- [~] **Claim (c)**: `just check-interactive` — deferred (no live emacs server in jail); Phase 1
- [x] DR-006 re-approved (`draft` → `approved`)
- [x] Decision recorded: bough's `/workspace` guard superseded by DEC-007 (test-host DATABASE_URL gate)

## 5. Verification

- **VT (prototype)**: ad-hoc ERT in `dl-satan-db-test.el` exercising `(or override host)`, the batch guard error, and that `dl-satan-db-test-db-available-p` returns nil for the prod socket **without** issuing a psql probe (assert via `cl-letf` spy on `dl-satan-db-psql`).
- **VA — Claim (a)**: `just check` slice run; capture "Ran N … 0 unexpected" with the 7 named tests passing.
- **VA — Claim (b)**: `env -u SATAN_DB_HOST emacs --batch … (dl-test-run-suite)`; capture the chokepoint error string.
- **VH — Claim (c)**: in the live server, `(let ((dl-satan-db-host-override "127.0.0.1")) (ert 'dl-satan-memory-migrate/applies-real-migrations))` passes, then `(dl-satan-memory-migrate-status)` (no binding) shows it hit `/run/postgresql`. Capture both.

## 6. Assumptions & STOP Conditions

- Assumes `/run/postgresql` is the production broker host (confirmed by user this session) and the test DB is supabase at `SATAN_DB_HOST=127.0.0.1:54322`.
- Assumes `bough` reads the same `SATAN_DB_HOST`/PG env so the 3 bough integration tests redirect too — **verify early**; if bough ignores `SATAN_DB_HOST`, raise via `/consult` (its host plumbing may be out of `dl-satan-db.el`'s reach).
- STOP when: claim (b) or (c) fails, or bough cannot be redirected — these change the design, not just the plan.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | --- | --- | --- |
| [x] | 0.1 | Add `dl-satan-db-host-override` + `dl-satan-db-resolve-host` in `dl-satan-db.el` | [ ] | refactored: resolver extracted per DEC-006; chokepoint + `dl-satan-db-database-url` added |
| [x] | 0.2 | Add batch prod-guard (inside `dl-satan-db-resolve-host`) | [ ] | unified with resolver |
| [x] | 0.3 | Add `dl-satan-db-test-db-available-p` (routes through `dl-satan-db-resolve-host`) | [ ] | now calls resolver so guard fires in batch-prod |
| [x] | 0.4 | Delegate `dl-satan-memory-migrate-test.el` reachability to the predicate | [ ] | done — 5 migrate tests pass (claim a) |
| [x] | 0.5 | Spike bough redirect | [ ] | **finding**: bough is external (`call-process`), ignores carrier; takes `DATABASE_URL`, defaults to prod, non-reachable in jail → DEC-007 |
| [x] | 0.6 | Add `check-interactive` recipe (`--eval` `let`-binding) | [ ] | done; `check`=batch (default), `check-interactive`=emacsclient with carrier |
| [x] | 0.7 | Run + capture VA(a)✓, VA(b)✓, VH(c) evidence | [ ] | (a) 5 migrate pass; (b) guard fires (ERT swallows→skip, no prod touch); (c) needs live server — deferred to Phase 1 |
| [x] | 0.8 | DR-006 re-approval; bough-`/workspace`-guard decision → superseded (DEC-007) | [ ] | DR approved; bough guard superseded |
| [x] | 0.9 | Triage the 9 new failures surfaced by the slice run | [ ] | → §10; drove DR DEC-006/007 + Tension-3 |

### Task Details

- **0.1–0.3 dl-satan-db.el core**
  - **Design / Approach**: DR-006 §3 snippets verbatim. Resolution in both `dl-satan-db-psql` and `dl-satan-db-query` (two call sites). Guard `noninteractive`-gated so the live broker never errors.
  - **Files / Components**: `satan/dl-satan-db.el`
  - **Testing**: prototype VT (task in §5)
- **0.5 bough redirect spike**
  - **Design / Approach**: confirm `dl-satan-tools-bough` / the `bough` binary honour `SATAN_DB_HOST` (or PG env) so the 3 integration tests hit the test DB. bough connects out-of-process — it may not route through `dl-satan-db.el`. This is the highest-uncertainty item; do it before declaring claim (a).
  - **Files / Components**: `satan/dl-satan-tools-bough.el`, `bough` program env

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| bough ignores `SATAN_DB_HOST` (own DB plumbing) | spike task 0.5 first; `/consult` if confirmed | open |
| Guard fires for the live broker (mis-gated) | gate strictly on `noninteractive`; VH(c) proves broker unaffected | open |
| `dl-satan-db-query` missed (second call site) | apply resolution to both functions; grep for other psql call sites | open |

## 9. Decisions & Outcomes

- `2026-05-31` — Prototype-first (Phase 0) chosen over full rollout to de-risk claims (b)/(c) and the bough redirect before touching 12 test files + renaming recipes.
- `2026-05-31` — **Claim (a) PROVEN**: with `SATAN_DB_HOST=127.0.0.1`, the 5 memory-migrate DB tests run+pass against the test DB (were erroring on the prod socket).
- `2026-05-31` — **Chokepoint is not the sole DB path** (the design's original premise was false). Two bypass classes confirmed in code → DR DEC-006 (centralize on `dl-satan-db-resolve-host`) and DEC-007 (bough via `DATABASE_URL`). DR revised.
- `2026-05-31` — bough `/workspace` guard (080a352) **superseded** by the test-host gate (DEC-007).

## 10. Findings / Research Notes

- Prior failure root cause (this session): modules pass explicit `-h /run/postgresql`; `SATAN_DB_HOST` exported but unread; supabase on TCP `127.0.0.1:54322`, prod on unix socket `/run/postgresql`.
- `dl-satan-db-default-host` has **zero callers** (confirmed via rg) — vestigial.

### The 9 new failures, triaged (task 0.9)

| Class | Example | Root cause | Disposition |
| --- | --- | --- | --- |
| Non-chokepoint raw psql | `dl-satan-patch-store/insert-fires-notify` | `dl-satan-patch-store-test--listen:228` builds `-h <patch-store-host>` itself → hit `/run/postgresql` | DR DEC-006; Phase 1: route `-h` through `dl-satan-db-resolve-host` |
| External binary (env) | 3× `dl-satan-bough/*` integration | `bough` `call-process` inherits env, defaults to prod pg, ignores carrier | DR DEC-007; gate on test-host `DATABASE_URL`; wiring = Phase 1 spike |
| Missing DB name (Tension 3) | context / intervention suites | reference prod-named `satan_memory`; supabase only has `satan_memory_test` | **pre-existing**, not caused by DE-006; provision both via `db-init`; DB-name isolation = follow-up |
| Vestigial defconsts (Tension 2/4) | `dl-satan-db-test.el`, `dl-satan-memory-grammar-test.el` | `--host` defconsts + old `--reachable-p` (`let`-binds `dl-satan-db-default-host`) — different shape from the new predicate | redirect works regardless; Phase 1: migrate to `dl-satan-db-test-db-available-p`, remove defconsts |

- Non-chokepoint psql/connection spawns (full audit seed): `satan/dl-satan-patch-listener.el:161` (prod daemon, `DATABASE_URL`), `satan/dl-satan-attribute-listener.el:324` (prod daemon), `dl-satan-patch-store-test--listen:228` (test). Prod daemons unchanged (carrier nil → prod); only the test spawn needs redirect.
- Claim (b) nuance: `dl-satan-db-resolve-host` errors correctly in batch without `SATAN_DB_HOST`, but ERT's `skip-unless` catches the error and silently skips. Net effect is correct (no prod connections), but the DR's "loud error" requires a pre-flight check in `dl-test-run-suite` — Phase 1 candidate.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied (3 claims evidenced)
- [ ] Verification evidence stored (VA/VH captures in notes)
- [ ] DR/IP updated with any design lessons from the bough spike
- [ ] Hand-off notes to Phase 1 (rollout) — confirm predicate signature is final before fanning out
