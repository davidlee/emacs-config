# Notes for DE-004

## 2026-05-31 - Preflight and phase planning

- Preflight read DE-004, DR-004, IP-004, POL-001, referenced memories, and the relevant Nix/Justfile surfaces.
- Obvious DR issues fixed:
  - frontmatter `open_questions` now mirrors the body;
  - vk reference wording no longer claims it proves `.emacs.d` jail TCP loopback reachability;
  - rollout now distinguishes the DE-003 bootstrap exception from DE-004 steady state.
- User clarified DE-003 is currently blocked by lack of DB access, so Phase 01 assumes the DR-004 DEC-008 bootstrap path: full `pg_dumpall` evidence before any temporary host Postgres exposure, then teardown before DE-004 steady-state wiring.
- User had no strong preference on wrapped-Emacs ownership; plan defaults to the cleaner define-once shape: `pub` exports the wrapped Emacs package and both host home module + jailed agents consume it, unless Phase 01 finds a concrete flake-boundary problem.
- Created `phases/phase-01.md` as a readiness/isolation gate. It does not authorize implementation yet; Phase 02 should be created only after Phase 01 records backup, reachability, DB inventory/auth/migration, Emacs invocation, and pub pin decisions.
- DE-004 now links Phase 01 in its relationships block and no longer says IP-004 is unplanned.
- Uncommitted `.spec-driver` changes are pending. Worktree also contains unrelated/unowned DE-003/SATAN DB files; preserve them during execution.

## 2026-05-31 - Phase 01 execution

- Moved DE-004 and IP-004 to `in-progress`, then started workflow phase `IP-004-P01`.
- Captured the backup gate before any host Postgres exposure:
  `/home/david/.cache/de-004-backups/pg_dumpall-20260530T234338Z.sql`,
  size `82598908`, mode `0600`, SHA-256
  `83c336846fab430b73b5939cea55d955ea3ce30518018542636690dec8d904d8`.
- Confirmed host Supabase port is listening:
  `pg_isready -h 127.0.0.1 -p 54322 -U postgres` returned accepting
  connections. `supabase` is not on the host PATH yet; Phase 02 should provide
  `supabase-cli` through the jail packages.
- Confirmed `.emacs.d` specDev bwrap networking can reach host loopback by
  using the generated `jailed-pi` runtime closure args/profile shape with a
  temporary bash payload; TCP to `127.0.0.1:54322` returned
  `TCP_OK_127.0.0.1_54322`.
- Confirmed GNU Emacs 30.2 supports the planned batch invocation shape:
  `--init-directory=/home/david/.emacs.d` sets `user-emacs-directory` to
  `/home/david/.emacs.d/`.
- Inventoried default elisp DB scope. `db-init` should create/drop
  `satan_memory_test` and apply the existing
  `dl-satan-memory-migrate-apply` migrations from
  `satan/memory/migrations/0001_init.sql` through `0006_interventions.sql`.
  `trace_test` is a stub payload; `patch_live_test` is `SATAN_PATCH_LIVE` gated.
- Selected the wrapped-Emacs ownership strategy: define/export the derivation
  once in `/home/david/flakes/pub`, consume `pub.packages.${system}.emacs` from
  both the host home module and `.emacs.d` jailed agents, and align
  `nixpkgs`/`emacs-overlay`/`emacs-config` through input follows. Do not copy the
  package list into `.emacs.d/flake.nix`.
- Updated DE-004, DR-004, IP-004, and `phases/phase-01.md` with the Phase 01
  evidence and decisions. No steady-state Nix/Justfile/Supabase implementation
  files were edited in this phase.
- Captured durable memory `mem.fact.satan.jailed-agent-loopback` so future
  agents know current specDev wrappers share host loopback but are not general
  diagnostic shells.

## 2026-05-31 - Phase 02 planning

- Accepted the Phase 01 handoff and created `phases/phase-02.md`.
- Phase 02 is scoped to steady-state Nix/Justfile/Supabase wiring only. DE-003's
  missing `SATAN_DB_HOST` knob remains an explicit blocker for Phase 03
  end-to-end DB-backed suite evidence, not for adding packages, env, recipes, and
  config.
- Phase 02 STOP conditions include: no edits to
  `/home/david/flakes/pub/jailed-agents.nix`, no `satan/*.el` DB-host work, no
  `exposePostgres=true` steady-state change, and no copied package list in
  `.emacs.d/flake.nix`.
- `DOCKER_HOST` is currently `unix:///run/user/1000/docker.sock`, matching the
  vk rootless Docker bind pattern.
- `spec-driver phase start DE-004 --phase IP-004-P02` reported the workflow was
  already implementing after handoff acceptance, so Phase 02 status and
  `workflow/state.yaml` were reconciled manually to make `IP-004-P02` the active
  in-progress phase.

## 2026-05-31 - Phase 02 execution

- Implemented the steady-state wiring:
  - `/home/david/flakes` commit `eb79fce` (`shared emacs`) defines
    `pub.packages.${system}.emacs` in `pub/emacs.nix`, consumes it from
    `modules/home/emacs.nix`, and aligns `pub` inputs with the parent flake.
  - `.emacs.d/flake.nix` consumes the pub wrapped Emacs, adds `postgresql_18`,
    `supabase-cli`, and `just` to project packages, and applies Supabase TCP
    env plus the rootless Docker socket bind to all specDev jailed agents.
  - `Justfile` now has additive `db-start`, `db-stop`, `db-status`, `db-init`,
    and `check-batch` recipes; host `check` remains the live-daemon path.
  - `supabase/config.toml` exists with `[db].port = 54322`.
- Validation evidence:
  - `alejandra` over the touched Nix files passed.
  - `just --list`, `just --dry-run check-batch`, and `just --dry-run db-init`
    passed.
  - Host psql against
    `postgresql://postgres:postgres@127.0.0.1:54322/postgres` returned `1`.
  - `nix eval /home/david/flakes/pub#packages.x86_64-linux.emacs.name --raw`
    returned `emacs-unstable-pgtk-with-packages-30.2`.
  - `nix eval .#packages.x86_64-linux.jailed-pi.name --raw` returned
    `jailed-pi` after the local `pub` lock was refreshed.
  - A concurrent `nix build .#packages.x86_64-linux.jailed-pi --no-link` /
    devshell probe crashed the caller shell and was not repeated; user then
    resynced and ran `home-manager`, unblocking the other agent.
- Phase 02 is complete as wiring/eval work only. Phase 03 still owns jailed
  `db-start`/`db-init`/`check-batch` evidence and the proof that DB-backed tests
  do not merely skip.
- The new `/home/david/flakes/pub/emacs.nix` had to be git-tracked before Nix
  could see it, confirming the flake tracked-file trap already documented in
  `docs/emacs/traps.md`; no new memory is needed.
- `.spec-driver` changes from Phase 02 remain uncommitted in this repo. The
  worktree also contains staged/unowned DE-003 follow-up changes; preserve them.

## 2026-05-31 - Phase 03/04 collapse + close

- User judgement: P03 is ceremony (jailed agents already run `check-batch` against
  Supabase in practice) and P04 is mostly redundant bwrap checking whose only live
  concern is exposePostgres. Collapsed both into evidence capture rather than
  authoring separate phase sheets.
- exposePostgres is already `false` for every specDev profile in
  `~/flakes/pub/jailed-agents.nix` (lines 126/133/140); no override to `true` in
  `.emacs.d/flake.nix`, none uncommitted. The R5 bootstrap exception was therefore
  never enabled — teardown is a no-op.
- VH-DE004-ISO evidence: user ran `ls /run/postgresql` inside a specDev jail ->
  `cannot access '/run/postgresql': No such file or directory`. Host Postgres socket
  dir absent inside the jail => prod isolation (AC closure target #3) proven.
- VA-DE004-P03 marked verified-by-practice; VH-DE004-ISO marked verified. IP-004
  §9 and the DE-004/IP-004 phase blocks reconciled to P03/P04 completed.
