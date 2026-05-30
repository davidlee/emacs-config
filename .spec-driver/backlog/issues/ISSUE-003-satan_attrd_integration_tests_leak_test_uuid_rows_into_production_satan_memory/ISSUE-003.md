---
id: ISSUE-003
name: "satan-attrd integration tests leak test:<uuid> rows into production satan_memory"
created: "2026-05-30"
updated: "2026-05-30"
status: in-progress  # one of: in-progress | open | resolved | triaged
kind: issue  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
categories: [satan, attributes, testing]
severity: p2  # one of: p1 | p2 | p3 | p4
impact: process  # one of: user | systemic | process
---

# satan-attrd integration tests leak test:<uuid> rows into production satan_memory

## Symptom

`satan_attributes` accumulates orphaned rows under `test:<uuid>` scopes
alongside the real `global` scope. Observed 2026-05-30: 3 leaked scopes (12
rows), all stamped `2026-05-29 06:20:45` — a single failed test run. The junk
pollutes any naive `SELECT … FROM satan_attributes` (e.g. attribute-drift
checks), where `global` rows must be filtered out by hand.

## Root cause

- satan-attrd integration tests run against the **production** database. Tests
  connect to `$DATABASE_URL` (`tests/common/mod.rs::shared_pool`), and the only
  DB is `satan_memory` — migrations run against it directly. No ephemeral /
  template DB.
- Per-test isolation relies on `common::unique_scope()` → `test:<uuid>` plus a
  **best-effort inline** `common::cleanup_scope()` call at the *tail* of each
  test body (`tests/decay.rs`, `tests/store.rs`).
- There is no `Drop`/RAII guard and no transaction rollback. Any test that
  panics or fails an assertion before reaching its `cleanup_scope` line orphans
  its row. The leaked rows are therefore also a fossil of past test failures.

## Impact

- Drift/observability queries (e.g. IMPR-003 render verification) read polluted
  data; `global` must be filtered manually or results mislead.
- Tests mutate the production store — a failing test can, in principle, also
  collide with or perturb live projection state.

## Fix options

- A. **Transaction-per-test, rolled back** (preferred): each test runs inside a
  `pool.begin()` tx that is never committed. True isolation, zero leak even on
  panic, no cleanup bookkeeping. Requires threading the tx/conn through the
  code-under-test.
- B. **RAII scope guard**: `unique_scope()` returns a guard whose `Drop` runs
  cleanup (Drop can't await — use a blocking delete or `scopeguard` + a
  short-lived runtime). Cheaper to retrofit than A; still hits prod DB.
- C. **Ephemeral test DB**: create-from-template per test run, drop at end.
  Strongest isolation from production; heaviest setup.

## Immediate remediation

Flush the orphaned rows (blocked from auto-run — destructive prod-DB write):

```
psql satan_memory -c "DELETE FROM satan_attributes WHERE scope LIKE 'test:%';"
```

## Resolution

- `2026-05-30` — **Leak mechanism fixed** by DE-002 (chose option C, disposable
  per-test DB) and verified by AUD-001 (conformance, all findings aligned). At
  satan-attrd `fe18bae`: `shared_pool()` self-provisions
  `satan_attrd_test_<epoch>_<uuid>` + asserts `current_database()` before any
  write (prod never a write target), and the best-effort `cleanup_*` apparatus is
  removed (disposable DB → panic-safe). Full suite green; prod `test:%` == 0.
- **Status `in-progress`, not `resolved`**: the **immediate-remediation flush**
  (`DELETE FROM satan_attributes WHERE scope LIKE 'test:%'`) is a destructive prod
  write, **out of DE-002 scope**, human-run out-of-band. Mark `resolved` only once
  a human has run that flush and confirmed the existing orphaned rows are gone.

## Related

- DE-002 / DR-002 / AUD-001 — fix, design, and conformance audit.
- IMPR-003 (attribute capsule render) — discovered while verifying its blocker.
  The `global` scope is clean and shows real drift; this issue is the
  data-hygiene tail, not an IMPR-003 blocker.
- POL-001 (SATAN module extraction policy).
