---
id: DR-006
slug: db_host_isolation_read_satan_db_host_env_var_instead_of_hardcoding_run_postgresql
name: "Design Revision - DB host isolation: chokepoint host resolution + host-as-gate test policy"
created: "2026-05-31"
updated: "2026-05-31"
status: approved
kind: design_revision
aliases: []
owners: []
relations:
  - type: implements
    target: DE-006
delta_ref: DE-006
source_context: []
code_impacts:
  - path: satan/dl-satan-db.el
    current: 'psql/query use the HOST arg verbatim; no test/prod guard'
    target: 'Add carrier dl-satan-db-host-override (env-seeded); dl-satan-db-resolve-host (carrier + batch prod-guard) wrapped by psql/query; dl-satan-db-database-url builder; dl-satan-db-test-db-available-p predicate'
  - path: satan/test/dl-satan-patch-store-test.el
    current: 'dl-satan-patch-store-test--listen builds -h <patch-store-host> directly (bypasses chokepoint)'
    target: 'Route -h through dl-satan-db-resolve-host'
  - path: satan/test/dl-satan-tools-bough-test.el
    current: 'Guard = (not (file-exists-p /workspace)) AND bough-executable; bough hits prod pg by default'
    target: 'Guard on bough-executable AND test-host DATABASE_URL; let-bind DATABASE_URL from dl-satan-db-database-url (Phase 1 spike: DB name/port)'
  - path: satan/test/*.el (DB-touching files)
    current: 'Per-file --reachable-p re-implements a SELECT 1 probe; 2 files carry --host defconsts'
    target: 'Each --reachable-p delegates to dl-satan-db-test-db-available-p; --host defconsts removed'
  - path: Justfile
    current: 'check (emacsclient), check-batch (emacs --batch)'
    target: 'check ← old check-batch body (emacs --batch, the default); check-interactive ← old check body (emacsclient) + let-binds the host carrier via --eval'
verification_alignment:
  - verification: "just check (was check-batch; supabase up, SATAN_DB_HOST set)"
    impact: "DB tests connect to the test DB and run+pass (were erroring on the prod socket)"
    notes: "Justfile already exports SATAN_DB_HOST=127.0.0.1"
  - verification: "just check (SATAN_DB_HOST unset)"
    impact: "Chokepoint errors loudly — refuses the production socket in batch"
    notes: "SATAN_FAILOVER_TO_SYSTEM_DB is the explicit escape hatch"
  - verification: "just check-interactive (was check; emacsclient)"
    impact: "DB tests run against the test DB for the let-binding's dynamic extent; the live broker's production connection is untouched"
    notes: "Replaces the old always-skip stance"
design_decisions:
  - id: DEC-001
    summary: "SATAN_DB_HOST, not PGHOST"
    rationale: "psql is always called with explicit -h, which overrides PGHOST."
  - id: DEC-002
    summary: "One dynamic carrier, resolved at the chokepoint"
    rationale: "dl-satan-db-host-override (seeded from SATAN_DB_HOST at load) overrides the HOST arg inside dl-satan-db-psql/query at call time. Modules keep their honest /run/postgresql defaults. Single resolution site, runtime not load-time — no per-module edits, no two-mechanism drift."
  - id: DEC-003
    summary: "Interactive opt-in by let-binding the carrier"
    rationale: "check-interactive passes (let ((dl-satan-db-host-override ...)) (dl-test-run-suite)) via emacsclient --eval. The redirect lasts only the suite's dynamic extent; the live broker keeps using the production host outside it. No setenv (which would pollute the running broker). Batch becomes the default `check`; the emacsclient path is renamed `check-interactive`."
  - id: DEC-004
    summary: "Refuse the production socket in batch (chokepoint guard)"
    rationale: "noninteractive + host=/run/postgresql + no SATAN_FAILOVER_TO_SYSTEM_DB → error. Lives in the chokepoint so it catches every code-under-test path, not just explicit probes. Never green-washes, never touches prod from batch."
  - id: DEC-005
    summary: "Host value is the gate; one availability predicate"
    rationale: "dl-satan-db-test-db-available-p decides run/skip from the effective host and never probes the prod socket. Drops SATAN_SKIP_DB_TESTS_IF_UNREACHABLE and the resolve-test-host/skip-or-fail pair from the prior design."
  - id: DEC-006
    summary: "Resolution is centralized in dl-satan-db-resolve-host; not all DB access is through the chokepoint"
    rationale: "Phase 0 proved the chokepoint is NOT the sole DB path. Two bypass classes exist: in-process raw psql that builds its own -h (e.g. dl-satan-patch-store-test--listen), and external binaries that connect via DATABASE_URL/PG env (prod patch/attribute listeners; the bough binary). The carrier alone only catches the chokepoint. Fix: extract dl-satan-db-resolve-host (carrier + batch guard); the chokepoint and every raw-psql spawn call it for -h, and dl-satan-db-database-url builds DATABASE_URL from the resolved host for env-channel binaries. Rule: every psql/connection spawn routes its host through dl-satan-db-resolve-host."
  - id: DEC-007
    summary: "bough is an external binary; redirect via env, gate strictly on test-host"
    rationale: "bough runs via call-process and does not route through dl-satan-db.el; it defaults to the prod pg unless DATABASE_URL is passed, and is non-reachable in the jail. Its integration tests must run ONLY when pointed at a test DB (never prod) — gate on bough-executable AND a test-host DATABASE_URL. Wiring bough's exact test DB name/port is a Phase 1 spike; until proven, the 3 integration tests skip. This supersedes the /workspace proxy guard (commit 080a352)."
open_questions:
  - "bough's test DB target: which db name on the supabase instance, and does it honour postgres:///db?host=127.0.0.1 + PGPORT, or need a full URL? (Phase 1 spike)"
  - "DB-NAME isolation (Tension 3): tests referencing satan_memory (prod name) need that name provisioned on the test instance, OR migration to _test names. Out of DE-006 host-isolation core scope — provision both via db-init now, file hardening follow-up."
---

# DR-006 – DB host isolation

## 1. Executive Summary

- **Delta**: [DE-006](./DE-006.md)
- **Status**: draft (re-approval pending; design changed materially from the first approval)
- **Synopsis**: Resolve the Postgres host once, at the `dl-satan-db` chokepoint, via a dynamic carrier seeded from `SATAN_DB_HOST`. Batch redirects to the test DB through the env var; interactive redirects by `let`-binding the carrier for the test suite's extent; the production broker is never disturbed. A single host-derived predicate gates DB tests and never touches the production socket.

## 2. Problem & Constraints

- **Current**: Every DB module hardcodes `/run/postgresql` and passes it to `dl-satan-db-psql` as the explicit `-h` host. The Justfile exports `SATAN_DB_HOST=127.0.0.1` (the supabase test DB) but nothing reads it, so `check-batch` connects to the prod socket and errors. The interactive (`emacsclient`) path can only either skip every DB test or risk running them against the production DB.
- **Production fact**: `/run/postgresql` **is** the legitimate production host the broker connects to. Tests must never touch it.
- **Constraints**: Single resolution mechanism. No new abstractions beyond a thin carrier + one predicate. Production broker behaviour unchanged when `SATAN_DB_HOST` is absent.

## 3. Architecture Intent

### One dynamic carrier in `dl-satan-db.el`

```elisp
(defvar dl-satan-db-host-override (getenv "SATAN_DB_HOST")
  "Redirects every psql call's host when non-nil.
Batch: seeded from SATAN_DB_HOST at process start.
Interactive: `let'-bound around the test suite so DB tests hit the
test DB for that dynamic extent only — the live broker keeps using
its production host outside the binding.")
```

### One resolver — `dl-satan-db-resolve-host` (carrier + batch guard)

Resolution is extracted so **every** psql/connection spawn shares it, not just the chokepoint:

```elisp
(defun dl-satan-db-resolve-host (host)
  "Effective psql host: the override carrier wins over HOST.
Refuses the production socket in batch unless SATAN_FAILOVER_TO_SYSTEM_DB.
Every psql/connection spawn — chokepoint or not — routes its host
through this so the test redirect is universal."
  (let ((h (or dl-satan-db-host-override host)))
    (when (and noninteractive (equal h "/run/postgresql")
               (not (getenv "SATAN_FAILOVER_TO_SYSTEM_DB")))
      (error "dl-satan-db: refusing production socket in batch; set SATAN_DB_HOST"))
    h))
```

`dl-satan-db-psql` and `dl-satan-db-query` wrap their host: `(let ((host (dl-satan-db-resolve-host host))) …)`.

- Production broker (interactive, `SATAN_DB_HOST` unset): `override` nil → module's `/run/postgresql` → guard is batch-only → no error. Unchanged.
- Batch tests (`SATAN_DB_HOST=127.0.0.1`): `override` → supabase; every chokepoint caller redirected at once.
- Batch without the env var: guard errors loudly — refuses prod, never green-washes.

### Non-chokepoint DB access (Phase 0 finding — DEC-006/007)

The chokepoint is **not** the only DB path. Two bypass classes must also route through the resolver:

1. **In-process raw psql** — `dl-satan-patch-store-test--listen` builds `-h <dl-satan-patch-store-host>` directly for a backgrounded LISTEN/NOTIFY session. Fix: `-h (dl-satan-db-resolve-host dl-satan-patch-store-host)`.
2. **External binaries via env** — prod patch/attribute listeners spawn the satan-patcher daemon with `DATABASE_URL=postgres:///<db>?host=<host>`; the `bough` binary runs via `call-process` inheriting `process-environment` (defaults to prod pg). For test redirection, build the URL from the resolved host and `let`-bind it:

```elisp
(defun dl-satan-db-database-url (db &optional host)
  "libpq DATABASE_URL for DB on the resolved host (port via PGPORT env)."
  (format "postgres:///%s?host=%s"
          db (dl-satan-db-resolve-host (or host dl-satan-db-default-host))))

;; test side, around an external-binary call:
(let ((process-environment
       (cons (concat "DATABASE_URL=" (dl-satan-db-database-url db))
             process-environment)))
  …)
```

Production listeners keep using their `*-host` defcustom (carrier nil → `/run/postgresql`), unchanged. The bough integration tests gate on **bough-executable AND a test-host DATABASE_URL** (never prod); exact bough test DB name/port is a Phase 1 spike (open question).

### One availability predicate, host-derived, prod-safe

```elisp
(defun dl-satan-db-test-db-available-p (db)
  "Non-nil when DB tests may run against DB. Never probes the prod socket."
  (let* ((host (or dl-satan-db-host-override "/run/postgresql"))
         (is-prod (equal host "/run/postgresql")))
    (cond
     ((and is-prod (not (getenv "SATAN_FAILOVER_TO_SYSTEM_DB"))) nil) ; skip; never touch prod
     (t (eq 'ok (car (dl-satan-db-psql
                      db host dl-satan-db-default-program
                      (list "-A" "-t" "-c" "SELECT 1"))))))))
```

Each test file's `--reachable-p` collapses to a call to this; the two `--host` defconsts are removed.

### The unifying gate

Run DB tests **iff the effective host is not the production socket** (and answers `SELECT 1`):

| context | effective host | outcome |
|---|---|---|
| batch + `SATAN_DB_HOST` set | test DB | run |
| batch + unset | prod socket | **error** (chokepoint guard) |
| interactive, no binding | prod socket | **skip** (predicate, no prod touch) |
| interactive, `let`-bound | test DB | run |
| any + `SATAN_FAILOVER_TO_SYSTEM_DB` | prod socket | deliberately probe/run |

The same effective host feeds the env-channel binaries (`dl-satan-db-database-url` → `DATABASE_URL`), so raw-psql and external-binary paths obey the identical gate.

### Justfile: batch becomes the default `check`; emacsclient → `check-interactive`

```make
# was check-batch — now the default
check:
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{justfile_directory()}}"
  emacs --batch -Q --init-directory="{{justfile_directory()}}" \
    -L core -L lisp -L org -L editing -L completion -L apps -L lang -L dev -L satan -L satan/test -L lisp/test \
    -l dev/dl-test.el \
    --eval '(dl-test-run-suite)' | tee /dev/stderr | grep -q PASS

# was check — runs in the live server; redirects DB tests to the test DB
# for the suite's dynamic extent only (broker untouched outside it)
check-interactive:
  @emacsclient --eval '(let ((dl-satan-db-host-override (or (getenv "SATAN_DB_HOST") "127.0.0.1"))) (dl-test-run-suite))' | tee /dev/stderr | grep -q PASS
```

`check-batch` is removed (its body is now `check`).

## 4. Design Decisions

- **DEC-001**: `SATAN_DB_HOST`, not `PGHOST` — psql `-h` overrides `PGHOST`.
- **DEC-002**: One dynamic carrier resolved at the chokepoint at call time. Modules keep literal `/run/postgresql`. Single mechanism; no load-time/runtime drift.
- **DEC-003**: Interactive opt-in by `let`-binding the carrier via `check-interactive`'s `--eval`. No `setenv` (would pollute the live broker). Batch becomes the default `check`; the emacsclient path is renamed `check-interactive`.
- **DEC-004**: Refuse the production socket in batch from inside the chokepoint, unless `SATAN_FAILOVER_TO_SYSTEM_DB`.
- **DEC-005**: The host value is the gate; one `dl-satan-db-test-db-available-p` predicate, never probes prod. Drops `SATAN_SKIP_DB_TESTS_IF_UNREACHABLE` and the `resolve-test-host`/`skip-or-fail` pair.
- **DEC-006**: Resolution centralized in `dl-satan-db-resolve-host`; every psql/connection spawn (chokepoint, raw-psql, DATABASE_URL builder) routes its host through it. The chokepoint is not the sole DB path.
- **DEC-007**: bough is an external binary outside `dl-satan-db.el`; redirect via `DATABASE_URL`, gate its integration tests strictly on a test-host (never prod). Supersedes the `/workspace` proxy guard.

## 5. Affected Files

**Source (1 file):**
- `satan/dl-satan-db.el` — add carrier `dl-satan-db-host-override`; `dl-satan-db-resolve-host` (carrier + batch guard); wrap host in `dl-satan-db-psql` and `dl-satan-db-query`; add `dl-satan-db-database-url`; add `dl-satan-db-test-db-available-p`.

**Non-chokepoint redirect (DEC-006/007):**
- `satan/test/dl-satan-patch-store-test.el` — `dl-satan-patch-store-test--listen` routes `-h` through `dl-satan-db-resolve-host`.
- `satan/test/dl-satan-tools-bough-test.el` — replace the `/workspace` guard with a test-host gate; `let`-bind `DATABASE_URL` from `dl-satan-db-database-url` around bough calls (Phase 1 spike confirms the DB name/port).
- `satan/dl-satan-patch-listener.el`, `satan/dl-satan-attribute-listener.el` — **no change** (prod daemons; carrier nil → `/run/postgresql`). Listed for audit-completeness only.

**DB-name provisioning (Tension 3):** `just db-init satan_memory` **and** `satan_memory_test` on the supabase instance so context/intervention/etc. tests (which reference the prod-named `satan_memory`) connect against the test host. This is DB-name parity, not host isolation; see open question + follow-up.

**Tests (DB-touching files):** delegate each `--reachable-p` to `dl-satan-db-test-db-available-p`; remove the 2 `--host` defconsts. Mechanical, incremental; no behaviour change beyond delegation.
- `satan/test/dl-satan-db-test.el` (remove `--host` defconst)
- `satan/test/dl-satan-memory-grammar-test.el` (remove `--host` defconst)
- `satan/test/dl-satan-memory-store-test.el`
- `satan/test/dl-satan-memory-migrate-test.el`
- `satan/test/dl-satan-patch-store-test.el`
- `satan/test/dl-satan-patch-runner-test.el`
- `satan/test/dl-satan-observer-test.el`
- `satan/test/dl-satan-intervention-test.el`
- `satan/test/dl-satan-tools-memory-test.el`
- `satan/test/dl-satan-tools-hippocampus-test.el`
- `satan/test/dl-satan-tools-patch-test.el`
- `satan/test/dl-satan-memory-renormalize-test.el`

**Justfile:** rename old `check-batch` → `check` (the default); rename old `check` → `check-interactive` and add the host-carrier `let`-binding to its `--eval`.

Rename blast radius — sweep references to the old recipe names before landing: `dev/dl-test.el` header comments (lines ~4, ~18 describe `just check` as the emacsclient path), `CHANGELOG.md`, `AGENTS.md`/docs, any CI invocation.

## 6. Risks

- **R1 — carrier set globally instead of `let`-bound**: a stray `setq dl-satan-db-host-override` in the live server would redirect production traffic. Mitigation: only ever `let`-bind it; default nil; document on the defvar.
- **R2 — forgotten interactive binding**: plain `dl-test-run-suite` (unbound) skips DB tests. Safe and visible (SKIPPED count); `check-interactive` is the supported entry point.
- **R3 — env seeded at load**: changing `SATAN_DB_HOST` after Emacs starts won't affect batch. Acceptable — batch sets it before launch.
- **R4 — unaudited non-chokepoint spawn (DEC-006)**: a psql/connection spawn that builds its own `-h`/`DATABASE_URL` without `dl-satan-db-resolve-host` silently hits prod. Mitigation: Phase 1 greps all `call-process`/`make-process`/`-h ` sites; the batch guard inside the resolver only protects callers that route through it, so the audit is the real safety net, not the guard.
- **R5 — prod-named test DB (Tension 3)**: tests using `satan_memory` connect to `<resolved-host>/satan_memory`. With the carrier set → supabase copy (safe). If a test ran without the host gate, interactive-unbound would target prod `satan_memory`. Mitigation: the host-gate predicate skips when host = prod; DB-name isolation tracked as a follow-up.

## 7. Superseded design (first approval)

The original DR introduced `dl-satan-db-resolve-test-host` + `dl-satan-db-test--skip-or-fail`, env-var-baked defcustoms in 5 modules, `SATAN_SKIP_DB_TESTS_IF_UNREACHABLE`, and error-by-default in batch. Dropped because: (a) two host-resolution mechanisms (load-time defcustom vs runtime helper) could diverge precisely when `SATAN_DB_HOST` was unset, letting code-under-test silently hit prod while the strict test guard would have errored; (b) the `skip-or-fail (resolve-test-host)` call had an argument-evaluation ordering bug (the resolver errored before the skip flag could be honored); (c) the scope (18 files, 2 functions, 2 env vars) far exceeded DE-006. The chokepoint design collapses host resolution to one runtime site and one predicate. (The `check`/`check-interactive` recipe rename is retained — it is cheap and clarifies that batch is the default.)
