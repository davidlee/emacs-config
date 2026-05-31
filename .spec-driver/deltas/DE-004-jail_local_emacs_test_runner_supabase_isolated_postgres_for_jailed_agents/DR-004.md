---
id: DR-004
slug: jail_local_emacs_test_runner_supabase_isolated_postgres_for_jailed_agents
name: Design Revision - Jail-local Emacs test runner + Supabase-isolated Postgres for jailed agents
created: "2026-05-31"
updated: "2026-05-31"
status: draft
kind: design_revision  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
aliases: []
owners: []
relations:
  - type: implements
    target: DE-004
delta_ref: DE-004
source_context:
  - type: research
    id: SC-001-jailed-agents-builder
  - type: research
    id: SC-002-wrapped-emacs-derivation
  - type: research
    id: SC-003-emacsd-agent-instantiation
  - type: research
    id: SC-004-vk-supabase-reference
  - type: research
    id: SC-005-dl-test-suite-runner
  - type: research
    id: SC-006-policy-memory-context
code_impacts:
  - path: "~/flakes/pub"
    current_state: "No pub package output for the host wrapped Emacs."
    target_state: "Expose a define-once wrapped Emacs package consumable by the host home module and jailed agents."
  - path: "~/.emacs.d/flake.nix"
    current_state: "specDev jailed agents have project packages only and no Emacs, psql, Supabase CLI, or Supabase env."
    target_state: "All specDev jailed agents get wrapped Emacs, psql, Supabase CLI, docker socket access, and Supabase DB env while exposePostgres is false in steady state."
  - path: "~/.emacs.d/Justfile"
    current_state: "Only live-server check exists via emacsclient."
    target_state: "Add db-start, db-init, and check-batch recipes; leave check unchanged."
  - path: "~/.emacs.d/supabase/config.toml"
    current_state: "No Supabase local config for this repository."
    target_state: "Supabase local config exists with db port 54322."
  - path: "satan/*.el"
    current_state: "Host DB paths are still being consolidated under DE-003."
    target_state: "DE-004 consumes DE-003's env-driven DB host knob; it does not implement DB-code changes."
verification_alignment:
  - verification: VA-DE004-P01
    impact: new
  - verification: VA-DE004-BACKUP
    impact: new
  - verification: VA-DE004-P03
    impact: new
  - verification: VH-DE004-ISO
    impact: new
  - verification: existing-ert-suites
    impact: regression
design_decisions:
  - id: DEC-001
    summary: "Reuse the host wrapped Emacs via pub export so the suite loads with the same package set."
  - id: DEC-002
    summary: "Use batch emacs --batch -Q with explicit load path, not daemon plus emacsclient."
  - id: DEC-003
    summary: "Use Supabase local Postgres at 127.0.0.1:54322; exposePostgres stays false in steady state."
  - id: DEC-004
    summary: "Use explicit db-start and db-init lifecycle recipes; check-batch remains a pure test run."
  - id: DEC-005
    summary: "Add check-batch; leave host check unchanged."
  - id: DEC-006
    summary: "Add the capability to all specDev agents."
  - id: DEC-007
    summary: "Keep bind surface to the workspace and Supabase needs; no extra panopticon or satan-attrd mounts."
  - id: DEC-008
    summary: "Use a backup-gated temporary host-Postgres bootstrap exception because DE-003 currently lacks DB access."
open_questions: []
---

# DR-004 – Jail-local Emacs test runner + Supabase-isolated Postgres for jailed agents

## 1. Executive Summary

- **Delta**: [DE-004](./DE-004.md)
- **Status**: draft (update when approved)
- **Owners / Team**: David Lee
- **Last Updated**: 2026-05-31
- **Synopsis**: Give jailed coding agents a contained way to run the Emacs ERT suite — a **batch** invocation of the host's already-built wrapped Emacs (exported via `pub`) against an **isolated Supabase** Postgres — without binding the host daemon socket (code-exec escape) or host `/run/postgresql` (live-data exposure).

## 2. Problem & Constraints

- **Current Behaviour**: `just check` → `emacsclient --eval '(dl-test-run-suite)'` against the host live Emacs daemon. Jailed agents (`jailed-pi`/`claude`/`codex`/`opencode`/`gemini`/`zero`, `specDev` profile) have no Emacs, no `psql`, and `exposePostgres=false` — they cannot run the suite at all.
- **Drivers / Inputs**: User request — jailed agents must run the suite and reach a DB, *without* the two naive escapes: (a) binding the host daemon socket lets `emacsclient --eval` run arbitrary elisp on the host; (b) binding host `/run/postgresql` leaves live `satan_memory` one `DROP DATABASE` away. Reference: `~/dev/vk` Supabase-in-jail pattern.
- **Constraints / Guardrails**:
  - Edit `~/.emacs.d/flake.nix` + `Justfile` + `supabase/` only. The single sanctioned `~/flakes` touch is exposing the Emacs derivation via `pub`. The jail builder `jailed-agents.nix` is **not** edited.
  - `dl-test-run-suite` loads **every** `*-test.el` under `satan/test` + `lisp/test` (doctrine: no exclusion list — [[mem.fact.satan.test-db-isolation]]); the suite pulls in editor-coupled modules (org/denote/gptel/dbus/sway), so the jail Emacs must carry the full package set.
  - DB-backed tests `DROP TABLE IF EXISTS …` inside an existing `satan_memory_test` DB; they never `CREATE DATABASE`, so provisioning must `createdb` it.
- **Out of Scope**:
  - The 7-spot `/run/postgresql` → `SATAN_DB_HOST` host-knob consolidation — owned by **DE-003** (hard dependency).
  - POL-001 module extraction — not triggered.
  - panopticon / satan-attrd read-mounts and the `skip-unless`-gated e2e tests (`SATAN_TEST_JAIL_BIN`, `SATAN_PATCH_LIVE`).
  - `satan_attrd_test_*` (rust attrd toolchain) provisioning.

## 3. Architecture Intent

- **Target Outcomes**: inside a jailed agent —
  ```sh
  just db-start     # supabase start (docker) — once per session
  just db-init      # createdb satan_memory_test + apply memory migrations
  just check-batch  # emacs --batch -Q … runs dl-test-run-suite vs Supabase
  ```
  DB-backed tests run green against Supabase; the host daemon and live `satan_memory` are unreachable.

- **Guiding Principles**:
  - **Containment over convenience**: never bind the host Emacs daemon socket (arbitrary host code-exec) nor host `/run/postgresql` (live-data exposure) in steady state.
  - **Reuse, don't fork**: the jail runs the *same* wrapped Emacs the host builds (exported via `pub`) — identical package set, shared store path, no parallel package list to drift.
  - **No init.el in the jail**: `-Q` batch loads only load-path + test files; sidesteps `server-start`/dbus/sway/EAF startup hazards that a daemon would hit under the jail's bare HOME.
  - **Isolation via a separate engine, not socket ACLs**: Supabase is a distinct Postgres (127.0.0.1:54322); the live cluster simply isn't mounted.

- **State Transitions / Lifecycle Impact**: DE-004 `draft → in-progress` on first flake edit. A time-boxed **bootstrap** sub-state grants TEMP host Postgres (after backup) so an agent can land DE-003's knob + prove Supabase, then reverts. Delta closes only after the no-host-socket isolation gate passes.

### C4 (container) sketch

```
host                                   jail (bwrap, specDev: persist-home + shared net ns)
────                                   ────────────────────────────────────────────────
emacs daemon (live)   ✗ NOT bound      emacs --batch -Q  (pub wrapped emacs, all pkgs)
/run/postgresql       ✗ NOT bound        │  -L core … -L satan/test  -l dev/dl-test.el
                                          │  (dl-test-run-suite)
docker → supabase pg  ◀── 127.0.0.1:54322 ──┘  psql (PGUSER/PGPASSWORD=postgres)
  (satan_memory_test)                    $PWD ◀── --bind → /workspace/.emacs.d (config+sources)
docker.sock           ◀── --bind ──────  supabase-cli (db-start/db-init)
```

## 4. Code Impact Summary

| Path | Current State | Target State |
| --- | --- | --- |
| `~/flakes/pub/…` | wrapped Emacs built only inside `flake.homeModules.emacs` (no package output) | derivation defined once, exported as `pub.packages.<sys>.emacs` (consumed by both the homeModule and the jail). The sole sanctioned `~/flakes` edit. |
| `~/.emacs.d/flake.nix` (all specDev agents) | `extraPkgs = projectPkgs`; no emacs/psql; `exposePostgres` defaults false | `extraPkgs += [ pub emacs, supabase-cli, postgresql ]`; `extraOptions += [ bind docker.sock, fwd DOCKER_HOST, set-env SATAN_DB_HOST=127.0.0.1 / PGPORT=54322 / PGUSER=postgres / PGPASSWORD=postgres ]`; `exposePostgres` stays false |
| `~/.emacs.d/Justfile` | `check` (live emacsclient) only | add `db-start` (`supabase start`), `db-init` (`createdb satan_memory_test`…), `check-batch` (batch invocation below). `check` unchanged. |
| `~/.emacs.d/supabase/config.toml` | absent | `supabase init`; pin db port 54322 |
| `satan/*.el` (7 host hardcodes) | `/run/postgresql` literal in 5 defcustoms + 2 test defconsts | single env-driven `SATAN_DB_HOST` knob — **DE-003 deliverable, referenced not implemented here** |

### The batch invocation (`check-batch`)

```sh
emacs --batch -Q \
  --init-directory="$PWD" \   # user-emacs-directory → /workspace/.emacs.d (bwrap chdir target)
  -L core -L lisp -L org -L editing -L completion -L apps -L lang -L dev -L satan -L satan/test -L lisp/test \
  -l dev/dl-test.el \
  --eval '(dl-test-run-suite)' | tee /dev/stderr | grep -q PASS
```

- External packages (org/denote/gptel/…) resolve from the wrapped Emacs's site-lisp load-path; only the project's own `dl-*` dirs need `-L`.
- `dl-test-run-suite` derives test dirs from `user-emacs-directory`; `--init-directory` (Emacs 29+) sets it. Fallback if unavailable: `--eval "(setq user-emacs-directory default-directory)"` before the load.
- psql reads `PGPORT`/`PGUSER`/`PGPASSWORD` from env automatically — no change to `dl-satan-db.el` arg-building.

> Aligns with `code_impacts` frontmatter.

## 5. Verification Alignment

| Verification | Impact | Notes |
| --- | --- | --- |
| existing ert suites | reuse | No new VTs authored here; `dl-satan-db-test` changes belong to DE-003. Behaviour unchanged. |
| VA (test run) | new | Jailed agent runs `just check-batch` → `PASS N/M (… skipped)`; DB-backed tests **not** skipped (Supabase reachable). Captured as agent report. |
| VH (isolation) | new | At close (post bootstrap-teardown): inside jail `psql -h /run/postgresql -l` fails / `/run/postgresql` absent. User attests. |
| Evidence (backup) | gate | `pg_dumpall` of all prod DBs + globals exists, dated, **before** any host-Postgres exposure (R5). |

> In sync with `verification_alignment` frontmatter.

## 6. Supporting Context

- **Reference impl**: `~/dev/vk/flake.nix` (jail Supabase-adjacent block: `exposePostgres`, `supabase-cli`, docker.sock bind, `DOCKER_HOST` fwd) + `~/dev/vk/Justfile` (`db-start`/`db-init`). It proves the docker/Supabase lifecycle and package/bind shape. It did **not** prove DE-004's steady-state TCP path to Supabase from the `.emacs.d` specDev jail; Phase 01 separately proved that path.
- **Memories**: [[mem.fact.satan.test-db-isolation]] (suite loads ALL test files; DB suites self-isolate + skip-unless), [[mem.fact.satan.psql-plumbing]] (DE-003 extracts the shared host knob).
- **Related Deltas**: **DE-003** (hard dependency — owns `SATAN_DB_HOST`). **POL-001** (extraction policy — names "emacs --batch to run anything" coupling; this DR *uses* batch to run tests, extracts nothing → no conflict).
- **Phase 01 evidence**: backup captured at
  `/home/david/.cache/de-004-backups/pg_dumpall-20260530T234338Z.sql`
  (SHA-256 `83c336846fab430b73b5939cea55d955ea3ce30518018542636690dec8d904d8`);
  specDev bwrap-profile TCP probe reached `127.0.0.1:54322`; GNU Emacs
  30.2 accepts `--init-directory`; default DB scope is `satan_memory_test`
  with migrations `0001..0006`.

## 7. Design Decisions & Trade-offs

- **DEC-001 — Reuse host wrapped Emacs via `pub` export.** Suite loads identically to the live server. *Conditional benefit*: the "~0 marginal closure / shared store path" holds **only if** `pub` resolves the *identical* derivation — same `nixpkgs` AND `emacs-overlay` revisions as `~/flakes`. If pins drift it is a separate (large) build, still cached after first build but not shared. Phase 01 selected the clean structure: define/export the wrapped Emacs once in `pub`, consume `pub.packages.${system}.emacs` from both `/home/david/flakes/modules/home/emacs.nix` and `.emacs.d/flake.nix`, and align parent inputs with follows for `nixpkgs`, `emacs-overlay`, and `emacs-config`. *Rejected*: rebuilding `emacsWithPackagesFromUsePackage` standalone in `.emacs.d/flake.nix` or copy-pasting the package list.
- **DEC-002 — Batch (`-Q`), not daemon+emacsclient.** Skips `init.el` entirely (no `server-start`/dbus/sway/EAF/startup-DB hazards under the jail's bare HOME). Repo already uses this pattern for integration tests. *Trade-off*: diverges from `just check`'s emacsclient → a separate `check-batch` recipe. *Rejected*: daemon (init-in-jail is the dominant execution risk).
- **DEC-003 — Supabase (docker, 127.0.0.1:54322); `exposePostgres` stays false.** Meets the safety goal — live `satan_memory` simply isn't mounted. *Trade-off*: docker dependency + `supabase start` precondition. *Rejected*: host-socket (`exposePostgres=true`) leaves prod exposed in steady state. Phase 01 resolved **R6**: the current specDev bwrap profile does not unshare the network namespace, and a TCP probe using the generated runtime closure args reached host loopback `127.0.0.1:54322`. No bind/socket fallback is needed. Phase 02 still must add `postgresql` before a `psql` auth probe can run inside the actual agent wrapper.
- **DEC-004 — Explicit vk-style lifecycle (`db-start`/`db-init`); `check-batch` is pure.** Least magic, fast iteration, mirrors vk. *Rejected*: self-bootstrapping check (couples every run to docker orchestration).
- **DEC-005 — Additive `check-batch`; host `check` unchanged.** Keeps the user's fast live-server workflow intact.
- **DEC-006 — All specDev agents get the capability.** Marginal closure ≈ 0 (shared store path); `jailed-pi` is the most-used. *Trade-off*: every agent's eval grows by the emacs+supabase deps (store-shared, so disk cost is paid once).
- **DEC-007 — Bind surface = `$PWD` + Supabase only.** Verified: the default suite's panopticon/attrd touches are string/fixture-based; real e2e is `skip-unless`-gated. No extra read-mounts. *Revisit if* a gated e2e test is ever added to the default run.
- **DEC-008 — Bootstrap exception (time-boxed).** TEMP `exposePostgres=true` after a full `pg_dumpall`, so a jailed agent can land DE-003's knob + prove Supabase before steady-state isolation exists. Torn down + isolation gate re-asserted before close. *Trade-off*: live DB reachable during bootstrap → supervised + backup-gated. *Boundary*: any DB-code change the bootstrap agent makes (the host-knob consolidation) is **DE-003's** work and commits under DE-003; DE-004 only provides the temporary environment.

## 8. Open Questions

- [x] Wrapped Emacs supports `--init-directory`: GNU Emacs 30.2 sets `user-emacs-directory` to the supplied path, so the fallback is not needed.
- [x] Default non-gated suite only needs `satan_memory_test`; `trace_test` is a stub payload and `patch_live_test` is `SATAN_PATCH_LIVE`-gated.
- [x] Supabase migration source is the existing `dl-satan-memory-migrate-apply` runner over `satan/memory/migrations/0001_init.sql` through `0006_interventions.sql`.
- [x] Role/auth should use Supabase's postgres role through `PGUSER=postgres`, `PGPASSWORD=postgres`, `PGPORT=54322`, plus DE-003's host knob; the inspected default tests do not hardcode `david` or depend on `current_user`/`session_user`.
- [x] **R6 jail→Supabase reachability** passed: current specDev bwrap profile can reach TCP loopback `127.0.0.1:54322`.

## 9. Rollout & Operational Notes

- **Sequencing**: (1) Resolve the DE-003 dependency. Current user clarification: DE-003 is blocked by lack of DB access, so DE-004 uses the backup-gated bootstrap path rather than assuming no-bootstrap. The required `pg_dumpall` backup has already been captured under `/home/david/.cache/de-004-backups/`; enable the time-boxed TEMP `exposePostgres=true` window under DE-003 only long enough to land/prove the host knob. (2) Revert to `exposePostgres=false` before DE-004 steady-state wiring. (3) Expose Emacs via `pub`; selected structure is a define-once `pub` wrapped-Emacs package consumed by both the home module and jailed agents, with parent input follows for pin alignment. (4) Wire `.emacs.d/flake.nix`, `Justfile`, and `supabase/`. (5) `home-manager switch`. (6) run jailed `check-batch`, re-assert isolation, and close.
- **Migration / Backfill**: new `.el` files (if any) must be `git add`ed before `home-manager switch` (flake parser sees only tracked files — trap #1).
- **Recovery / Rollback**: backup is `pg_dumpall` (globals + every DB) → restore via `psql -f dump.sql` against a fresh cluster. Flake change is revertable by `git revert` + `home-manager switch`. Steady-state risk is low (prod unmounted); the only window of prod risk is the bootstrap phase, which is backup-gated.
- **Observability**: `check-batch` exit code (grep `PASS`) is the signal; per-test detail on stderr.

## 10. References & Links

- `~/dev/vk/flake.nix`, `~/dev/vk/Justfile` — Supabase-in-jail reference.
- `~/flakes/modules/home/emacs.nix` — wrapped Emacs derivation.
- `~/flakes/pub/jailed-agents.nix` — jail builder (read-only for this delta).
- `dev/dl-test.el` — suite runner.

> Keep this document as the living design record for the delta. Update frontmatter fields (`owners`, `code_impacts`, `verification_alignment`, `design_decisions`, `open_questions`) as the design evolves.
