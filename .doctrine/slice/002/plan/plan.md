# Implementation Plan for SL-002

```yaml supekku:plan.overview@v1
schema: supekku.plan.overview
version: 1
plan: IP-002
delta: DE-002
revision_links:
  aligns_with:
    - DR-002
specs:
  primary: []
  collaborators: []
requirements:
  targets: []
  dependencies: []
phases:
  - id: IP-002-P01
  - id: IP-002-P02
```

```yaml supekku:verification.coverage@v1
schema: supekku.verification.coverage
version: 1
subject: IP-002
entries:
  - artefact: VT-with-db
    kind: VT
    requirement: ISSUE-003
    status: verified
    notes: with_db() rewrites both socket (?host=) and tcp DATABASE_URL forms; P01 (harness 4 passed).
  - artefact: VT-no-prod
    kind: VT
    requirement: ISSUE-003
    status: verified
    notes: shared_pool current_database() == generated test DB, never satan_memory; P01.
  - artefact: VT-sweep-gc
    kind: VT
    requirement: ISSUE-003
    status: verified
    notes: sweep reclaims old idle stray DB, skips recent one; P01.
  - artefact: VT-suite-green
    kind: VT
    requirement: ISSUE-003
    status: verified
    notes: full suite green with cleanup_* removed (42 integration + 69 unit); prod test:% == 0; P02.
```

## 1. Summary

- **Delta**: DE-002 — satan-attrd integration tests leak `test:<uuid>` rows into production `satan_memory`.
- **Specs Impacted**: none (workspace tracks no tech specs; traceability is to ISSUE-003).
- **Problems / Issues**: ISSUE-003.
- **Desired Outcome**: integration tests run against per-test disposable databases;
  production is never a write target; `cleanup_*` apparatus deleted.
- **Code repo**: `~/dev/satan-attrd/` (separate git repo — commit code there).

## 2. Context & Constraints

- **Current Behaviour**: `shared_pool()` connects to `$DATABASE_URL` (prod via `.envrc`);
  per-test best-effort `cleanup_*` at test tails leaks rows on panic.
- **Target Behaviour**: per DR-002 — `shared_pool()` self-provisions
  `satan_attrd_test_<epoch_ms>_<uuid>`, guards `current_database()`, migrates, returns.
- **Dependencies**: none.
- **Constraints**: clippy `-D unwrap_used -D expect_used` (test code `#![allow]`s in
  `common`); `just check` green; no auto-migrate on daemon start; admin role needs CREATEDB.

## 3. Gate Check

- [x] Backlog items linked and prioritised (ISSUE-003)
- [x] Spec(s) updated or delta specifies required changes (no specs; DE/DR carry scope)
- [x] Test strategy identified (integration harness + unit tests for `with_db`/sweep)
- [x] Workspace/config changes assessed (Justfile comment only; no flake change expected)

## 4. Phase Overview

| Phase | Objective | Entrance Criteria | Exit Criteria / Done When | Phase Sheet |
| --- | --- | --- | --- | --- |
| P01 — Harness engine | Build per-test DB provisioning in `tests/common/mod.rs` (with_db, sweep, create+guard) | DR-002 v2 accepted | `with_db`/sweep unit tests green (VT-with-db, VT-sweep-gc); VT-no-prod passes; one existing test runs on a throwaway DB; `cargo clippy` clean | `phases/phase-01.md` |
| P02 — Call-site migration & verification | Delete `cleanup_*` + tail calls across 4 test files; full-suite + gates | P01 complete | `cleanup_*` removed; full integration suite green; `just check` green; prod shows 0 new `test:%` rows (VT-suite-green) | `phases/phase-02.md` |

## 5. Phase Detail Snapshot

- **Research Notes**: captured in DR-002 §2/§6 (Phase 0 folded into design).
- **Design Revision**: `DR-002.md` (v2, review-integrated).
- **Active Phase Sheet**: `phases/phase-02.md` (P01 + P02 complete; ready for audit).
- **Parallelisable Work**: P02 call-site deletions across files are `[P]`-able.

## 6. Testing & Verification Plan

- **New unit tests** (`tests/common` or a `#[cfg(test)]` mod): `with_db()` both URL forms.
- **New integration tests**: VT-no-prod (current_database guard), VT-sweep-gc (age/in-use sweep).
- **Updated suites**: store/decay/dispatcher/run_loop — `cleanup_*` tails removed; assertions unchanged.
- **Tooling/Fixtures**: `epoch_ms`, `epoch_of`, `create_database`, `sweep_stale`, `PROC_START_MS`.
- **Rollback Plan**: revert harness change → prior behaviour; no prod code path touched.
- **Verification Coverage**: VT-with-db, VT-no-prod, VT-sweep-gc (P01); VT-suite-green (P02).

## 7. Risks & Mitigations

| Risk | Mitigation | Owner |
| --- | --- | --- |
| Admin role lacks CREATEDB | Explicit early panic with remediation message; document machine/CI setup | Dev |
| `with_db` mishandles socket `?host=` form | Use sqlx `PgConnectOptions.database()`, not string surgery; VT-with-db covers both forms | Dev |
| Per-test CREATE+migrate too slow | `TEMPLATE template0` + 6 small migrations; measure; per-binary is the fallback optimisation (rejected unless needed) | Dev |
| Sweep drops a concurrent run's DB | Age filter (epoch ≥ cutoff skipped) + in-use DROP-fails backstop | Dev |

## 8. Open Questions & Decisions

- [ ] `SWEEP_MARGIN_MS` default (≈60s) — fix in P01.

## 9. Progress Tracking

- [x] P01 complete
- [x] P02 complete
- [x] Verification gates passed

## 10. Notes / Links

- DR-002 §4.1/§4.2 carry the canonical harness + sweep pseudocode.
- External review (codex/gpt-5.5) findings already integrated into DR-002 v2.
