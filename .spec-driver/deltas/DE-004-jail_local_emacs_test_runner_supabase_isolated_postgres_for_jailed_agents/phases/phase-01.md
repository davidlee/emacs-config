---
id: IP-004-P01
slug: "004-jail_local_emacs_test_runner_supabase_isolated_postgres_for_jailed_agents-phase-01"
name: Phase 01 - Readiness and Isolation Gates
created: "2026-05-31"
updated: "2026-05-31"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-004
delta: DE-004
---

# Phase 01 - Readiness and Isolation Gates

## 1. Objective

Resolve DE-004's remaining design gates before any steady-state Nix, Justfile,
or Supabase wiring begins. This phase turns DR-004's open questions into
evidence-backed decisions: whether DE-003 is ready, whether bootstrap is needed,
whether the `.emacs.d` specDev jail can reach Supabase, and what exact batch
test/DB setup later phases should implement.

## 2. Links & References

- **Delta**: DE-004
- **Design Revision Sections**: DR-004 §§4, 5, 7, 8, 9; especially DEC-001,
  DEC-002, DEC-003, DEC-008, R5, and R6.
- **Specs / PRODs**: none.
- **Policy**: POL-001 (SATAN module extraction policy; no extraction triggered).
- **Support Docs / Code**:
  - `/home/david/dev/vk/flake.nix`, `/home/david/dev/vk/Justfile`
  - `/home/david/flakes/modules/home/emacs.nix`
  - `/home/david/flakes/pub/flake.nix`
  - `/home/david/flakes/pub/jailed-agents.nix`
  - `flake.nix`, `Justfile`, `dev/dl-test.el`
  - `mem.fact.satan.test-db-isolation`, `mem.fact.satan.psql-plumbing`

## 3. Entrance Criteria

- [x] DE-004, DR-004, and IP-004 exist.
- [x] Required policy POL-001 was read.
- [x] No required standards or accepted ADRs apply at planning time.
- [x] No DE-004 implementation files have been edited in this phase.
- [x] Confirm whether the worktree has unrelated DE-003/user changes that must be preserved during execution.

## 4. Exit Criteria / Done When

- [x] DE-003 dependency state is recorded: user clarified DE-003 is blocked by lack of DB access.
- [x] Bootstrap path is chosen: host-Postgres bootstrap is needed, and requires dated full `pg_dumpall` evidence before any exposure.
- [x] Backup evidence is captured before enabling any temporary host-Postgres exposure.
- [x] `.emacs.d` specDev jail reachability to Supabase at `127.0.0.1:54322` is tested and recorded.
- [x] If TCP reachability fails, DR-004 is revised with the chosen bind/socket fallback before Phase 02. Not needed: TCP reachability passed.
- [x] Wrapped Emacs version/invocation is confirmed: `--init-directory` works, or the fallback `(setq user-emacs-directory default-directory)` is planned.
- [x] `db-init` scope is known: exact test databases, role/auth, and migration/seed source.
- [x] `pub` Emacs export approach is selected without duplicating the package list from `emacs.nix`.
- [x] IP-004 and this phase sheet are updated with final decisions and evidence links.

## 5. Verification

- **VA-DE004-P01**: a short agent report containing the exact jailed-agent
  command used to test Supabase reachability and the result.
- **VA-DE004-BACKUP**: required only if bootstrap is used; record the dated
  `pg_dumpall` path/command before enabling any host DB exposure.
- **Static checks**:
  - inspect DE-003 state via spec-driver and worktree status.
  - inspect wrapped Emacs source/version path from Nix.
  - inspect default ERT DB references with `rg`, not by guessing.
- **No full implementation verification in this phase**: `just check-batch`,
  `home-manager switch`, and jailed full-suite execution belong to later phases.

## 6. Assumptions & STOP Conditions

- **Assumptions**:
  - DE-004 does not implement the DB host knob; DE-003 owns that work.
  - `exposePostgres=false` is the steady-state default and close requirement.
  - New `check-batch` is additive; existing `just check` remains the live
    emacsclient workflow.
  - The only sanctioned `~/flakes` edit is the `pub` wrapped-Emacs export.
- **STOP when**:
  - implementing DE-004 would require editing `~/flakes/pub/jailed-agents.nix`;
  - host Postgres exposure is considered without backup evidence;
  - Supabase reachability fails and no explicit fallback design has been chosen;
  - execution would mix DE-003 DB-code changes into a DE-004 commit;
  - the wrapped-Emacs export requires copy-pasting the package list.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 1.1 | Confirm DE-003 host-knob state and whether bootstrap is needed | [ ] | User clarified DE-003 is blocked by lack of DB access; bootstrap is needed. |
| [x] | 1.2 | Capture backup gate requirements | [ ] | `pg_dumpall` evidence recorded; no host exposure was enabled in DE-004. |
| [x] | 1.3 | Test or design the jail-to-Supabase reachability gate | [ ] | TCP reachability passed for the current specDev bwrap profile. |
| [x] | 1.4 | Confirm wrapped Emacs version and batch invocation shape | [x] | Emacs 30.2 accepts `--init-directory`. |
| [x] | 1.5 | Inventory DBs, role/auth assumptions, and migration source | [x] | Default suite needs `satan_memory_test`; migrations are `satan/memory/migrations/0001..0006`. |
| [x] | 1.6 | Finalize pub export structure and pin-alignment strategy | [ ] | Use a `pub`-owned define-once wrapped Emacs export with parent-input follows for pin alignment. |
| [x] | 1.7 | Reconcile DR/IP/phase with the decisions and evidence | [ ] | DR/IP/phase/notes updated from Phase 01 evidence. |

### Task Details

- **1.1 Confirm DE-003 host-knob state**
  - **Design / Approach**: determine whether DE-003 has already provided the
    env-driven `SATAN_DB_HOST`/shared DB plumbing DE-004 consumes.
  - **Files / Components**: `.spec-driver/deltas/DE-003-*`, `satan/dl-satan-db.el`,
    `satan/test/dl-satan-db-test.el`, touched SATAN DB modules.
  - **Testing**: none; this is state/readiness inspection.
  - **Observations & AI Notes**: user clarified DE-003 is blocked by lack of DB
    access, so DE-004 planning assumes the DR-004 DEC-008 bootstrap path. Current
    worktree contains untracked DE-003 and SATAN DB files. Treat them as
    user/other-agent work unless assigned.

- **1.2 Backup gate for bootstrap**
  - **Design / Approach**: require `pg_dumpall` before any temporary
    `exposePostgres=true`.
  - **Files / Components**: DE-004 risk R5, DR-004 DEC-008.
  - **Testing**: record command/evidence only; do not perform destructive DB work.
- **Observations & AI Notes**: bootstrap is a time-boxed exception, not the
    steady-state design. Evidence captured before any exposure:
    `/home/david/.cache/de-004-backups/pg_dumpall-20260530T234338Z.sql`,
    mode `-rw-------`, size `82598908`, SHA-256
    `83c336846fab430b73b5939cea55d955ea3ce30518018542636690dec8d904d8`.

- **1.3 Supabase reachability gate**
  - **Design / Approach**: start or locate Supabase, then from the same
    `.emacs.d` specDev jail profile run a minimal `psql` TCP probe to
    `127.0.0.1:54322`.
  - **Files / Components**: `flake.nix`, `/home/david/flakes/pub/jailed-agents.nix`,
    `/home/david/dev/vk/flake.nix`, `/home/david/dev/vk/Justfile`.
  - **Testing**: capture command and output as VA-DE004-P01.
- **Observations & AI Notes**: vk proves the lifecycle shape, not DE-004's
    final TCP reachability path. Host Supabase port probe passed:
    `pg_isready -h 127.0.0.1 -p 54322 -U postgres` returned accepting
    connections. The generated `.emacs.d` `jailed-pi` wrapper is an agent
    wrapper rather than a general shell, so the gate used the same bwrap
    runtime closure args/profile shape with a temporary bash payload; TCP to
    `127.0.0.1:54322` returned `TCP_OK_127.0.0.1_54322`. Current
    `jailed-pi` lacks `psql`, so Phase 02 must add `postgresql` before a
    database-auth probe is possible.

- **1.4 Wrapped Emacs invocation**
  - **Design / Approach**: confirm Emacs version and whether `--init-directory`
    is accepted; otherwise plan the explicit `user-emacs-directory` fallback.
  - **Files / Components**: `/home/david/flakes/modules/home/emacs.nix`,
    `dev/dl-test.el`, `Justfile`.
  - **Testing**: later Phase 03 will run the batch suite; this phase only
    decides the invocation.
- **Observations & AI Notes**: external packages should resolve through the
    wrapped Emacs site-lisp; project dirs still need `-L`. Host Emacs reports
    GNU Emacs 30.2, and
    `emacs --batch -Q --init-directory=/home/david/.emacs.d --eval '(princ user-emacs-directory)'`
    prints `/home/david/.emacs.d/`, so no fallback is needed.

- **1.5 DB inventory, auth, and migrations**
  - **Design / Approach**: inspect default ERT tests and migration helpers to
    decide what `db-init` must create and seed.
  - **Files / Components**: `satan/test/*.el`, `satan/*.el`, migration fixtures.
  - **Testing**: no DB mutation required for the inventory.
- **Observations & AI Notes**: most tests reference `satan_memory_test`; confirm
    any `trace_test`/`patch_live_test` references are mocked or gated. Inventory
    confirmed the default non-gated elisp suite needs `satan_memory_test`.
    `trace_test` is a stub payload in `dl-satan-intervention-test`; `patch_live_test`
    appears only under `SATAN_PATCH_LIVE`-gated listener/runner tests. No
    default test hardcodes role `david` or depends on `current_user`/`session_user`.
    Role/auth should therefore come from `PGUSER=postgres`, `PGPASSWORD=postgres`,
    `PGPORT=54322`, and DE-003's host knob. Schema source is the existing
    `dl-satan-memory-migrate-apply` runner over
    `satan/memory/migrations/0001_init.sql` through `0006_interventions.sql`;
    `db-init` should create/drop `satan_memory_test` and apply those migrations.

- **1.6 pub export structure**
  - **Design / Approach**: default to the cleanest define-once structure: `pub`
    owns the wrapped-Emacs package export, and both the host home module and
    jailed agents consume that package. If Phase 01 finds a flake-boundary
    problem, revise the DR with the smaller shared-helper alternative. Do not
    duplicate the use-package package list.
  - **Files / Components**: `/home/david/flakes/modules/home/emacs.nix`,
    `/home/david/flakes/pub/flake.nix`, `.emacs.d/flake.nix`.
  - **Testing**: later Nix eval/build in Phase 02.
- **Observations & AI Notes**: `pub` currently uses its own `nixpkgs`; pin
    alignment/follows must be considered for the shared-store-path benefit.
    Selected structure: move/define the wrapped-Emacs derivation once in `pub`
    and consume `pub.packages.${system}.emacs` from both
    `/home/david/flakes/modules/home/emacs.nix` and `.emacs.d/flake.nix`.
    Add `emacs-config` and `emacs-overlay` inputs to `pub`; have the parent
    flake inputs follow the same `nixpkgs`/`emacs-overlay`/`emacs-config`
    sources so the host and jail resolve the identical store path. Do not copy
    the package list into `.emacs.d/flake.nix`.

- **1.7 Reconcile artifacts**
  - **Design / Approach**: update DR-004/IP-004/phase-01 with final decisions;
    create Phase 02 only after this sheet exits.
  - **Files / Components**: `DR-004.md`, `IP-004.md`, `phases/phase-01.md`,
    `notes.md`.
  - **Testing**: `spec-driver validate file` for touched artifacts.
  - **Observations & AI Notes**: phase planning is not a substitute for revising
    the DR if a real design fallback is needed.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| R5 bootstrap exposes live host DB | Bootstrap is needed because DE-003 lacks DB access; require backup evidence before exception | Open |
| R6 Supabase TCP unreachable from jail | Gate before wiring; revise DR if bind/socket fallback needed | Mitigated: TCP probe passed |
| pub/home Emacs derivation drift | Define once and align pins; reject package-list copy | Mitigated by selected pub-owned export + follows plan |
| DB tests pass only by skipping | Phase 03 evidence must include DB-backed tests not skipped | Open |
| Unrelated DE-003 worktree changes overwritten | Inspect status and preserve user/other-agent changes | Open |

## 9. Decisions & Outcomes

- `2026-05-31` - Phase 01 is a readiness gate, not a wiring phase. Rationale:
  DR-004 has open questions whose answers affect Nix and DB bind choices.
- `2026-05-31` - User clarified DE-003 is currently blocked by lack of DB
  access, so Phase 01 proceeds on the backup-gated bootstrap assumption.
- `2026-05-31` - Default wrapped-Emacs export strategy is define-once in `pub`,
  consumed by both the host home module and jailed agents, unless Phase 01 finds
  a concrete flake-boundary issue.
- `2026-05-31` - Backup evidence captured before any host DB exposure:
  `/home/david/.cache/de-004-backups/pg_dumpall-20260530T234338Z.sql`,
  SHA-256 `83c336846fab430b73b5939cea55d955ea3ce30518018542636690dec8d904d8`.
- `2026-05-31` - `.emacs.d` specDev bwrap profile can reach host loopback
  TCP `127.0.0.1:54322`; no bind/socket fallback is needed.
- `2026-05-31` - `check-batch` can use Emacs 30.2 with `--init-directory`;
  no `user-emacs-directory` fallback is needed.
- `2026-05-31` - `db-init` scope for the default suite is `satan_memory_test`
  plus existing SATAN memory migrations `0001..0006`; gated live patch tests are
  out of the default run.
- `2026-05-31` - Final pub strategy is a pub-owned wrapped Emacs export with
  parent-input follows for `nixpkgs`, `emacs-overlay`, and `emacs-config`.

## 10. Findings / Research Notes

- Preflight found no conflict with POL-001: DE-004 adds jail/test workflow
  wiring and does not extract a SATAN module.
- DR-004 originally said the vk reference proved host-loopback TCP reachability,
  while DEC-003/R6 said it did not. DR-004 was reconciled to keep R6 as a gate.
- DR-004 frontmatter originally listed `open_questions: []` while the body had
  five open questions. Phase 01 resolved those questions, so frontmatter is now
  intentionally empty and the body records the resolved answers.
- Worktree currently contains untracked DE-003 and SATAN DB files; Phase 01
  execution must not assume those are DE-004 work.
- Backup command succeeded against the host socket as user `david` using
  PostgreSQL 18.4 tooling. The dump is intentionally stored under
  `/home/david/.cache/de-004-backups/` with mode `0600`.
- `supabase` is not currently on the host PATH, but the local Supabase database
  port is already listening on `127.0.0.1:54322`; Phase 02 must add
  `supabase-cli` and `postgresql` to the jailed agent packages.
- The generated `jailed-pi` wrapper has no `--unshare-net`, so current
  specDev networking shares host loopback for the TCP gate.

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Verification evidence stored
- [x] Spec/Delta/Plan updated with lessons
- [x] Hand-off notes to next phase (if any)
