---
id: IP-004-P02
slug: "004-jail_local_emacs_test_runner_supabase_isolated_postgres_for_jailed_agents-phase-02"
name: Phase 02 - Steady-State Nix and Recipe Wiring
created: "2026-05-31"
updated: "2026-05-31"
status: in-progress  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-004
delta: DE-004
objective: "Add the non-bootstrap wiring for wrapped Emacs, Supabase tooling, and batch recipes."
entrance_criteria:
  - Phase 01 complete.
  - "DE-003 SATAN_DB_HOST knob available, or its absence is an explicit blocker."
  - Any temporary host-Postgres bootstrap exposure has been removed.
exit_criteria:
  - pub exports the wrapped Emacs derivation without copy-pasting the package list.
  - ".emacs.d/flake.nix equips every specDev jailed agent with Emacs, psql, Supabase CLI, docker socket access, and Supabase env."
  - "Justfile has db-start, db-init, and additive check-batch recipes; host check remains unchanged."
  - supabase/config.toml exists with the planned local DB port.
---

# Phase 02 - Steady-State Nix and Recipe Wiring

## 1. Objective

Add the non-bootstrap wiring that lets jailed specDev agents run the planned
batch Emacs test flow against Supabase-local Postgres: export the wrapped Emacs
from `pub`, consume it in the host home module and `.emacs.d` jail packages, add
Supabase/Postgres tooling and environment, create local Supabase config, and add
additive Just recipes. This phase does not implement DE-003's SATAN DB host knob
and does not claim end-to-end DB-backed suite evidence.

## 2. Links & References

- **Delta**: DE-004
- **Design Revision Sections**: DR-004 §§4, 7, 8, 9; DEC-001 through DEC-005,
  DEC-008.
- **Specs / PRODs**: none.
- **Policy**: POL-001 read in Phase 01; no extraction triggered.
- **Support Docs / Code**:
  - `/home/david/flakes/pub/flake.nix`
  - `/home/david/flakes/pub/jailed-agents.nix` (read-only)
  - `/home/david/flakes/modules/home/emacs.nix`
  - `/home/david/flakes/flake.nix`
  - `flake.nix`, `Justfile`, `dev/dl-test.el`
  - `/home/david/dev/vk/flake.nix`, `/home/david/dev/vk/Justfile`,
    `/home/david/dev/vk/supabase/config.toml`
  - `mem.fact.satan.jailed-agent-loopback`

## 3. Entrance Criteria

- [x] Phase 01 complete and workflow handoff accepted.
- [x] DE-003 `SATAN_DB_HOST` knob is not yet available; its absence is an
  explicit blocker for Phase 03 end-to-end DB-backed suite evidence, not for
  Phase 02 wiring that exports env and tooling.
- [x] No temporary host-Postgres exposure is enabled by DE-004. Any future
  bootstrap exposure belongs to DE-003 and remains backup-gated.
- [x] Worktree contains unrelated/unowned DE-003/SATAN DB files; preserve them
  and do not mix them into DE-004 edits.

## 4. Exit Criteria / Done When

- [ ] `pub` exports a define-once wrapped Emacs package without leaving a copied
  package list in `/home/david/flakes/modules/home/emacs.nix`.
- [ ] `/home/david/flakes/modules/home/emacs.nix` consumes the `pub` wrapped
  Emacs package for host `home.packages`.
- [ ] `.emacs.d/flake.nix` equips every specDev jailed agent with wrapped Emacs,
  `postgresql`, `supabase-cli`, Docker socket access, Supabase DB env, and
  leaves `exposePostgres=false`.
- [ ] `Justfile` has `db-start`, `db-init`, `db-status`, optional `db-stop`, and
  additive `check-batch`; existing `check` remains unchanged.
- [ ] `supabase/config.toml` exists with local DB port `54322`.
- [ ] Nix/recipe evaluation checks pass for the touched surfaces, or failures
  are recorded with concrete blockers.

## 5. Verification

- `spec-driver validate file` for DE-004, DR-004, IP-004, this phase, and any
  memory touched.
- `nix eval /home/david/flakes/pub#packages.x86_64-linux.emacs.name --raw`.
- `nix eval .#packages.x86_64-linux.jailed-pi.name --raw`.
- `nix build .#packages.x86_64-linux.jailed-pi --no-link`.
- `nix eval /home/david/flakes#homeConfigurations.david.config.home.packages --apply builtins.length`
  or a narrower home-module evaluation if the full eval is too expensive.
- `just --list` and `just --dry-run check-batch db-init`.
- No full `just check-batch` requirement in this phase: DE-003 still owns the
  runtime DB host knob, and Phase 03 owns jailed execution evidence.

## 6. Assumptions & STOP Conditions

- **Assumptions**:
  - `pub` is the single definition point for the wrapped Emacs package.
  - Parent flakes align `pub` inputs with their local `nixpkgs`,
    `emacs-overlay`, and `emacs-config` inputs where possible.
  - Supabase runs on host loopback `127.0.0.1:54322`; Phase 01 already proved
    bwrap-profile TCP reachability.
  - Docker is rootless on `/run/user/1000/docker.sock`; `DOCKER_HOST` is
    forwarded from the caller.
  - DE-004 exports `SATAN_DB_HOST=127.0.0.1` and PostgreSQL env, but tests that
    still hardcode `/run/postgresql` remain DE-003's responsibility.
- **STOP when**:
  - wiring requires editing `/home/david/flakes/pub/jailed-agents.nix`;
  - a package list would need to be copied into `.emacs.d/flake.nix`;
  - implementation would touch `satan/*.el` or DE-003's DB host code;
  - Nix wants to expose `/run/postgresql` in steady state;
  - editing `/home/david/flakes` is not approved by the sandbox/user.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [ ] | 2.1 | Refactor/export wrapped Emacs through `pub` | [ ] | Requires `/home/david/flakes` edits. |
| [ ] | 2.2 | Consume `pub` wrapped Emacs from host home module | [ ] | Remove local package-list ownership from home module. |
| [ ] | 2.3 | Add jailed-agent packages/env/binds in `.emacs.d/flake.nix` | [ ] | All specDev agents, `exposePostgres=false`. |
| [ ] | 2.4 | Add Supabase local config | [x] | Use port `54322`. |
| [ ] | 2.5 | Add Just recipes for DB lifecycle and batch checks | [x] | Preserve existing `check`. |
| [ ] | 2.6 | Run feasible Nix/Just validation | [ ] | Full jailed suite deferred to Phase 03. |
| [ ] | 2.7 | Reconcile DE/IP/DR/phase/notes with evidence | [ ] | Required before phase completion. |

### Task Details

- **2.1 Refactor/export wrapped Emacs through `pub`**
  - **Design / Approach**: create a pub-owned wrapped Emacs helper/package using
    the current host package list and `emacs-config`; add `emacs-overlay` and
    `emacs-config` inputs to `pub`.
  - **Files / Components**: `/home/david/flakes/pub/flake.nix`,
    likely `/home/david/flakes/pub/emacs.nix`.
  - **Testing**: `nix eval /home/david/flakes/pub#packages.x86_64-linux.emacs.name --raw`.
  - **Observations & AI Notes**: keep the package list in one place after the
    refactor.

- **2.2 Consume `pub` wrapped Emacs from host home module**
  - **Design / Approach**: add `pub` input to `/home/david/flakes/flake.nix`
    with input follows; replace the local wrapped-Emacs derivation in
    `modules/home/emacs.nix` with `inputs.pub.packages.${system}.emacs`.
  - **Files / Components**: `/home/david/flakes/flake.nix`,
    `/home/david/flakes/modules/home/emacs.nix`.
  - **Testing**: home-module evaluation; full `home-manager switch` is not
    required in this phase unless needed to prove eval.
  - **Observations & AI Notes**: this is the only sanctioned `~/flakes` touch
    outside `pub`.

- **2.3 Add jailed-agent packages/env/binds**
  - **Design / Approach**: add wrapped Emacs, `postgresql`, `supabase-cli`, and
    `just` to project packages; add `DOCKER_HOST` forwarding, rootless Docker
    socket bind, `SATAN_DB_HOST`, `PGHOST`, `PGPORT`, `PGUSER`, and
    `PGPASSWORD` env options. Apply to all specDev agent constructors without
    setting `exposePostgres=true`.
  - **Files / Components**: `flake.nix`.
  - **Testing**: `nix eval .#packages.x86_64-linux.jailed-pi.name --raw`;
    `nix build .#packages.x86_64-linux.jailed-pi --no-link`.
  - **Observations & AI Notes**: `jailed-pi-research` uses the research profile
    and is not in the specDev acceptance target unless explicitly chosen.

- **2.4 Add Supabase local config**
  - **Design / Approach**: create `supabase/config.toml` following the vk local
    config shape, with `project_id = "emacs-d"` and `[db].port = 54322`.
  - **Files / Components**: `supabase/config.toml`.
  - **Testing**: config existence and later `supabase status/start` in Phase 03.
  - **Observations & AI Notes**: no `supabase start` requirement here.

- **2.5 Add Just recipes**
  - **Design / Approach**: add explicit `db-start`, `db-stop`, `db-status`,
    `db-init`, and `check-batch` recipes. `db-init` creates/resets
    `satan_memory_test` and invokes `dl-satan-memory-migrate-apply` with the
    Supabase host; `check-batch` uses wrapped Emacs via PATH.
  - **Files / Components**: `Justfile`.
  - **Testing**: `just --list`; `just --dry-run check-batch db-init`.
  - **Observations & AI Notes**: preserve live-daemon `check` exactly.

- **2.6 Run feasible validation**
  - **Design / Approach**: prove Nix eval/build and recipe syntax without
    requiring DE-003 or full jailed execution.
  - **Files / Components**: touched Nix/Just/Supabase files.
  - **Testing**: commands in §5.
  - **Observations & AI Notes**: record any lockfile updates or build failures.

- **2.7 Reconcile artifacts**
  - **Design / Approach**: update DE/IP/DR/phase/notes and verification status.
  - **Files / Components**: `DE-004.md`, `DR-004.md`, `IP-004.md`,
    `phases/phase-02.md`, `notes.md`.
  - **Testing**: `spec-driver validate file` for touched artifacts.
  - **Observations & AI Notes**: do not mark Phase 03-ready if DE-003 remains
    missing.

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| `/home/david/flakes` edits need sandbox approval | Request escalation before editing those files | Open |
| DE-003 host knob absent | Scope Phase 02 to wiring/eval only; Phase 03 blocked until DE-003 lands | Open |
| Pub package drifts from host | Define once in pub and consume from home module and jail | Open |
| Docker socket path differs | Forward `DOCKER_HOST` and bind the known rootless socket path from vk | Open |
| `supabase-cli` config format drift | Use vk's existing local config shape; validate with CLI in later phase | Open |

## 9. Decisions & Outcomes

- `2026-05-31` - Phase 02 may implement wiring while DE-003 remains absent, but
  must not claim full DB-backed suite success; that evidence stays in Phase 03.

## 10. Findings / Research Notes

- Phase 01 proved specDev bwrap-profile TCP reachability to
  `127.0.0.1:54322`.
- Host environment currently has `DOCKER_HOST=unix:///run/user/1000/docker.sock`,
  matching the vk rootless Docker socket bind.
- `/home/david/flakes/pub` has its own `flake.lock`; input-follow strategy must
  be validated by Nix eval.

## 11. Wrap-up Checklist

- [ ] Exit criteria satisfied
- [ ] Verification evidence stored
- [ ] Spec/Delta/Plan updated with lessons
- [ ] Hand-off notes to next phase (if any)
