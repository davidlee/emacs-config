# SL-006: DB host isolation: read SATAN_DB_HOST env var instead of hardcoding /run/postgresql

# DE-006 – DB host isolation: read SATAN_DB_HOST env var

```yaml supekku:delta.relationships@v1
schema: supekku.delta.relationships
version: 1
delta: DE-006
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
    id: PROB-test-isolation
    label: "Every DB module hardcodes /run/postgresql; Justfile exports SATAN_DB_HOST=127.0.0.1 but nothing reads it"
```

```yaml supekku:delta.risk_register@v1
schema: supekku.delta.risk_register
version: 1
risks:
  - id: R1
    title: "Carrier setq globally would redirect live broker's production traffic"
    likelihood: low
    impact: high
    mitigation: "Only ever let-bind dl-satan-db-host-override; default nil; documented on the defvar"
    severity: medium
  - id: R2
    title: "Forgotten interactive binding → plain dl-test-run-suite skips DB tests"
    likelihood: medium
    impact: low
    mitigation: "Safe and visible (SKIPPED count); check-interactive is the supported entry point"
    severity: low
  - id: R3
    title: "Recipe rename (check-batch→check, check→check-interactive) breaks references"
    likelihood: low
    impact: low
    mitigation: "Sweep dev/dl-test.el comments, CHANGELOG, AGENTS/docs, CI before landing"
    severity: low
```

## 1. Summary & Context

- **Problem**: Every DB module hardcodes `/run/postgresql` and passes it to `dl-satan-db-psql` as the explicit `-h` host. `/run/postgresql` is the legitimate **production** host (the broker connects there); tests must never touch it. The Justfile exports `SATAN_DB_HOST=127.0.0.1` (the supabase test DB) but nothing reads it, so `check-batch` connects to the prod socket and errors. The emacsclient path can only skip every DB test or risk running against production.
- **Target**: Resolve the host once, at the `dl-satan-db` chokepoint, via a dynamic carrier `dl-satan-db-host-override` seeded from `SATAN_DB_HOST`. Batch redirects via the env var; interactive redirects by `let`-binding the carrier for the test suite's extent; the production broker is untouched. A single host-derived predicate gates DB tests and never probes the prod socket. See [DR-006](./DR-006.md).

## 2. Motivation

- `just check-batch` fails because DB tests connect to the prod socket instead of the supabase test DB.
- The migration workflow (`just db-init`) already has the right pattern — `--eval '(let ((dl-satan-memory-migrate-host (or (getenv "SATAN_DB_HOST") "127.0.0.1"))) ...)'` — but it is a per-call workaround, not a single resolution site.
- Resolving at the chokepoint removes the workaround, redirects every module at once, and unlocks a safe emacsclient test path that neither skips everything nor creates temp DBs on the production server.

## 3. Scope & Objectives

- **Primary Outcomes**:
  - Host resolved once at the `dl-satan-db` chokepoint via a dynamic carrier seeded from `SATAN_DB_HOST`
  - `just check` (batch, was `check-batch`) connects to the test DB when supabase is up
  - `just check-interactive` (emacsclient) runs DB tests against the test DB via a `let`-binding; the live broker is untouched
  - Batch refuses the production socket loudly (no green-washing, no prod writes)
  - One host-derived predicate gates DB tests; it never probes the prod socket
- **Dependencies**: None

## 4. Out of Scope

- Changing how `PGHOST`/`PGPORT`/`PGUSER`/`PGPASSWORD` are handled (psql respects these natively)
- Per-module defcustom edits — module `*-host` defaults stay literal `/run/postgresql` (honest production identity); the carrier overrides them at the chokepoint
- `dl-satan-db-default-host` (zero callers, vestigial) — leave as-is or delete; not load-bearing

## 5. Approach Overview

- **Source (1 file)**: `satan/dl-satan-db.el` — add `dl-satan-db-host-override` (env-seeded defvar); chokepoint host resolution `(or override host)` + batch prod-guard in `dl-satan-db-psql` and `dl-satan-db-query`; add `dl-satan-db-test-db-available-p`.
- **Tests (DB-touching files)**: delegate each `--reachable-p` to `dl-satan-db-test-db-available-p`; remove the 2 `--host` defconsts (`dl-satan-db-test`, `dl-satan-memory-grammar-test`). Mechanical, incremental.
- **Justfile**: rename `check-batch` → `check` (default); rename `check` → `check-interactive` and add the host-carrier `let`-binding to its `--eval`.

## 6. Verification Strategy

- **Acceptance Criteria**:
  - `just check` passes when supabase is up + `SATAN_DB_HOST` set (DB tests run, no prod-socket errors)
  - `just check` with `SATAN_DB_HOST` unset → errors loudly (refuses prod socket), unless `SATAN_FAILOVER_TO_SYSTEM_DB`
  - `just check-interactive` runs DB tests against the test DB; broker connections outside the suite extent unchanged
  - Production broker (interactive, no `SATAN_DB_HOST`) unchanged — still `/run/postgresql`
- **Planned Artefacts**: existing ERT suites + an `dl-satan-db` unit test for the chokepoint guard / availability predicate (this adds connection-policy logic, so it carries a test).

## 7. Follow-ups & Tracking

- **Backlog Items**: PROB-test-isolation (this delta)

## 8. Implementation Notes

- The carrier is a `defvar` seeded `(getenv "SATAN_DB_HOST")` at load: batch (fresh process, env set before launch) picks it up; the live server (env unset) leaves it nil so the broker uses `/run/postgresql`.
- `let`-bind the carrier for redirect — never `setq` it globally (would redirect the live broker too).
- The batch prod-guard lives in the chokepoint so it catches every code-under-test path, not just explicit reachability probes.
- The `PGHOST` env var set by the Justfile is ignored by psql because of the explicit `-h`; `SATAN_DB_HOST` is the one that must be wired into `-h`.
- Rename blast radius: sweep `dev/dl-test.el` header comments, `CHANGELOG.md`, `AGENTS`/docs, and CI for the old recipe names.
