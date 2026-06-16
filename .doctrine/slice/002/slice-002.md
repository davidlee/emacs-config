# SL-002: satan-attrd integration tests leak test:<uuid> rows into production satan_memory

# DE-002 – satan-attrd integration tests leak test:<uuid> rows into production satan_memory

```yaml supekku:delta.relationships@v1
schema: supekku.delta.relationships
version: 1
delta: DE-002
revision_links:
  introduces: []
  supersedes: []
specs:
  primary: []
  collaborators: []
requirements:
  implements: []
  updates: []
  verifies: []
phases: []
```

```yaml supekku:delta.context_inputs@v1
schema: supekku.delta.context_inputs
version: 1
entries:
- type: issue
  id: ISSUE-003
```

```yaml supekku:delta.risk_register@v1
schema: supekku.delta.risk_register
version: 1
risks: []
```

## 1. Summary & Context

- **Code repo**: `~/dev/satan-attrd/` — a **separate git repo** (`github:davidlee/emacs-config`
  is the broker; the daemon is its own tree). This spec-driver workspace lives in `~/.emacs.d/`.
  Implementation commits land in `satan-attrd`; the DE/DR/IP/notes artefacts live here.
- **Implementation Plan**: [IP-002](./IP-002.md)
- **Change Drivers**: ISSUE-003 (test-scope leak into production `satan_memory`).
- **No governing SPEC**: this workspace tracks no tech specs; traceability is to the
  backlog issue only.

## 2. Motivation

satan-attrd integration tests write `test:<uuid>` scope rows into `satan_attributes`
and run-scoped rows into `satan_attribute_events`, cleaned only by a **best-effort
inline `cleanup_*` call at each test tail**. Any panic/assert-fail before that line
orphans rows. Observed 2026-05-30: 3 leaked scopes / 12 rows from one failed run.

Bounded investigation surfaced a deeper root cause the issue did not name — **three
conflicting notions of the test database**:

| Source | DATABASE_URL | Nature |
| --- | --- | --- |
| `.envrc` (`direnv use flake`) | `postgres:///satan_memory?host=/run/postgresql` | **production** |
| `Justfile` (`just check`) | `postgresql://…@127.0.0.1:54322/postgres` | supabase-local |
| `HANDOVER.md` (intended) | `postgres:///satan_memory_test?host=/run/postgresql` | dedicated test DB |

A bare `cargo test` in the dev shell inherits the `.envrc` prod URL — that is how the
leak reached production. So there are **two distinct defects**:

1. **Targeting** — tests can run against production at all (env/config defect; the dangerous half).
2. **Panic-leak** — even in the correct DB, a panicking test orphans rows (isolation defect; the hygiene half).

## 3. Scope & Objectives

- **Primary Outcomes**:
  - Integration tests can **never** touch production `satan_memory` — they target a
    dedicated, disposable test database by construction, not by remembering an env override.
  - A panicking/failing test **leaves no orphaned rows** (panic-safe isolation).
  - The three-way DATABASE_URL discrepancy is collapsed to one source of truth.
- **Operational Constraints**: clippy `-D unwrap_used -D expect_used` (non-negotiable per
  satan-attrd AGENTS.md); `just check` must stay green; no auto-migrate on daemon start.
- **Dependencies**: none must land first.

## 4. Out of Scope

- Immediate remediation flush of existing orphaned rows
  (`DELETE FROM satan_attributes WHERE scope LIKE 'test:%'`) — destructive prod-DB write,
  tracked on ISSUE-003, run by a human out-of-band.
- Broker-side (elisp) changes; daemon attribute semantics / contract changes.

## 5. Approach Overview

- **System Touchpoints**: `tests/common/mod.rs` (harness), `tests/{decay,store,dispatcher,run_loop}.rs`
  (call sites), `Justfile`, `.envrc`, possibly `flake.nix` (test-DB provisioning).
- **Key Changes** (decided in [DR-002](./DR-002.md); v2 after external review):
  - Harness self-provisions a disposable **per-test** DB
    (`satan_attrd_test_<epoch_ms>_<uuid>`) from an admin conn derived from
    `DATABASE_URL` (db→`postgres`); `CREATE … TEMPLATE template0`; migrate+seed.
  - **Hard guard**: `shared_pool()` asserts `current_database()` == the generated
    test DB before migrating — prod is never written even on a botched URL rewrite.
  - Per-test DBs also dissolve a latent cross-test race: `rebuild_projection`
    (`src/store.rs:497`) zeroes the whole `satan_attributes` table across scopes.
  - GC: lock-free, age-filtered sweep-on-init (once/process); idle old DBs dropped,
    recent/in-use skipped.
  - Delete only the `cleanup_*` apparatus + tail call-sites; keep the (now redundant)
    `unique_scope`/`REBUILD_LOCK`/`DECAY_TEST_LOCK`/snapshot isolation (DEC-5).
- **Migration / Rollout Notes**: test-only; no production schema change.

## 6. Verification Strategy

- **Acceptance Criteria**:
  - Live test pool's `current_database()` matches `satan_attrd_test_%`, never
    `satan_memory` — even when `$DATABASE_URL` names prod (VT-no-prod).
  - Sweep reclaims an old idle stray DB and skips a recent one (VT-sweep-gc).
  - `with_db()` rewrites both socket and tcp `DATABASE_URL` forms (VT-with-db).
  - `just check` green; `satan_attributes` shows no new `test:%` scopes after a full run.
- **Planned Artefacts**: VT-no-prod, VT-sweep-gc, VT-with-db (DR-002 §5); finalised in IP-002.

## 7. Follow-ups & Tracking

- **Backlog Items**: ISSUE-003 (closes on landing + human-run flush), IMPR-003 (render
  verification — unblocked once global scope reads clean).

## 8. Implementation Notes

- Cross-repo: pin absolute `~/dev/satan-attrd/` paths in any subagent prompt; commit code
  there, artefacts here.
- Design decision (A/B/C) is deferred to DR-002 via `/draft-design-revision`.
