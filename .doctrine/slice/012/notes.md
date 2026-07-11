# Notes SL-012: Extract SATAN to standalone Elisp package

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## 2026-07-10 — design + plan locked, external review integrated

- Design adversarial pass (internal): 9 findings integrated (coupling facts,
  .emacs.d flake teardown, test-runner behaviour, hook symlink, SL-011 ordering
  → D9, memory staleness follow-up).
- Plan: 4 phases, copy-then-cutover (rationale in plan.md).
- External codex review on **RV-010**: 8 findings (1 blocker — Justfile `-L
  satan` hardcode; 5 major; 2 minor), all disposed `fixed`, all verified by
  raiser; ledger `done`. Key deltas: consumer-based decouple scope (13+2
  files), runner anchored off `user-emacs-directory`, git-add-before-flake-eval
  gate, EN-1 waiver requires explicit user /consult approval, PHASE-04 EX-8
  (Justfile), PHASE-02 EX-6 (timeout(1) dep).
- Workflow memory recorded: `mem.pattern.doctrine.codex-external-review`.
- SL-011 status at plan time: `ready` (not closed) — PHASE-01 EN-1 gates on it.

## 2026-07-12 — PHASE-01 executed; boundary crossing exposed a design gap

**Context state:** SL-011 closed (EN-1 ✓). DB up (supabase 127.0.0.1:54322).
Dispatch dropped — executing **inline** (no worktree), writing into
`/workspace/satan` (a separate git repo, user-confirmed writable). PHASE-01
`in_progress`, slice `started`.

### What landed (committed to the satan repo — real, keep)
- Full D1 tree copied verbatim (old `dl-satan-*` names), manifest-exact:
  `satan/*.el` ×65, `test/` ×62, harness ×9, bin ×4, memory/migrations ×7,
  protocol ×1, patterns.eld; `docs/satan/**` → `docs/**` (×39, flattened);
  `dev/satan-test.el` (runner); `bin/` + `tools/` linter; `justfile`.
- Scaffold `src/`/`test/` deleted; `.direnv` added to `.gitignore`.
- **`just lint` GREEN** (65/65).

### Design gap #1 (fixed in place) — linter not self-contained
`bin/elisp-locate-paren-error` depends on `tools/elisp-locate-paren-error.el`
(**absent from the D1 move table**) and hardcoded `.emacs.d` `-L` dirs. Fixed:
copied the tool `.el` into `tools/`, repointed the wrapper, dropped the dead
`-L` flags. **D1 move table is incomplete** — record at reconcile.

### Design gap #2 (THE design revision) — package self-location coupling
`just check` (ERT) = 64 fail / 39 LOADERR / 361 ran. Two config-root coupling
axes, but the design severs only one:

- **Axis 1 — `dl-notes-root`** (config module `dl-notes-paths`): 10 prod files
  hard-`require` it → 39 LOADERR cascade. **Design D4 / PHASE-03 owns this.** ✓
- **Axis 2 — `user-emacs-directory`** (package assumes its *own* code/data live
  under the config root): **NOT in the design.** Root cause proven:
  `user-emacs-directory` = `~/.emacs.d` = `/home/david/.emacs.d`, but the repo
  is `/workspace/.emacs.d` — different paths; `migrate-directory` resolved to a
  non-existent dir (`dir-exists=nil`) → test DBs never migrated → 64 failures
  (`function memory_show_trace does not exist`). **This breaks the SHIPPED
  package too:** PHASE-04 deletes `~/.emacs.d/satan/`, dangling every such path.

  The design half-saw this — RV-010 **F-1** noted `user-emacs-directory` is
  wrong in batch, but scoped the fix to the **test runner only** (done). It is
  endemic in **5 production defcustoms + 1 hardcode**:
  - `dl-satan-memory-migrate.el:26` — `satan/memory/migrations/`
  - `dl-satan-pattern.el:44` — `satan/patterns.eld`
  - `dl-satan-context.el:535` — `satan` dir
  - `dl-satan-tools-docs.el:35,129` — doc-corpus roots
  - `dl-satan-broker.el:56` — repo root
  - `dl-satan-tools-vcs.el:24` — hardcoded `~/.emacs.d/`

### User decision (2026-07-12) — do it properly
"If it's to be a real package, it needs its own identity and resolution."
Scope: a **package "know thyself" root convention** — a documented
`satan--root` (resolved from `load-file-name`, canonical ELPA self-location)
that all package path resolution anchors to. Not a minimal spot-fix. This is a
**design revision** (new decision, e.g. D4b/D10, extending D4 to *both*
config-root axes), cascading to a **plan revision** (owning phase + green
invariant). Routing agreed: `/design` → `/plan` → phase-sheet update.

### Plan tension to resolve in the plan revision
PHASE-01 (and cascading PHASE-02) exit gate "**full ERT green**" is
**unsatisfiable** for a copy-verbatim / defer-decouple phase — green requires
both axes severed. Re-cut the green bar to: *lint green + suite loads & runs
across the boundary + suites not blocked by the two axes pass; coupling-blocked
suites known-red until the decouple phase*. Full green only from the decouple
phase onward.

### Open sub-decisions for the design/plan agent
1. **Axis-2 home:** fold into PHASE-03 (rename it "Decouple config-root
   assumptions", cover both axes) — my recommendation — vs a new dedicated
   phase. Both axes are semantic and belong *after* the rename (PHASE-02) so the
   sweep doesn't rewrite new call sites.
2. **`dl-secret-test.el`** requires `dl-secret` (a config-owned module, not
   SATAN). It shouldn't have moved. Recommend dropping it from the package
   (dl-secret stays config; satan only soft-deps `my/op-read-env`). Small
   scope/manifest nit, not design-tier.
3. `satan--root` naming/convention: confirm `satan--root` (private) vs a public
   `satan-lisp-directory`; document the convention so future modules use it.

### Dual-presence window (PHASE-01 EX-5)
Copy-not-move: `.emacs.d/satan/` and `/workspace/satan/satan/` now co-exist.
**No edits to the `.emacs.d` copy** until PHASE-04 cutover, or edits must be
replayed into the package (PHASE-04 EN-2 audits the window closed).

## PHASE-01 execution results (2026-07-12, resumed)

Re-cut gate run, `SATAN_DB_HOST=127.0.0.1 just check` in `/workspace/satan`
(supabase up at `127.0.0.1:54322`). Exit 0.

- **Lint**: 65/65 `{"ok":true}` (satan/*.el). GREEN.
- **ERT**: `Ran 361 tests, 294 as expected, 64 unexpected, 3 skipped`.
- **All 64 unexpected are coupling-blocked** (PHASE-03), zero boundary
  regressions:
  - 63 = **Class B** self-location (unmigrated test DBs — migration dir anchored
    to `user-emacs-directory`): memory-store/renormalize/migrate (28),
    intervention (16), pattern (14), patch-store (8), trace-ex2 (1 DB-write).
  - 1 = **Class A** dl-notes cascade: `trace-ex2` also pulls `dl-satan-context`
    which hard-`require`s `dl-notes-paths` (file-missing). Same PHASE-03 fix.
  - Histogram by module: memory 28, intervention 16, pattern 14, patch 8, trace 1.
  - **0 failures outside the 5 DB-backed modules** → non-coupling suites
    (resonance, sensor, trace-stage, context-render, tools, protocol) all pass.
    Re-cut VA-1 satisfied.
- 3 skipped = `memory-grammar/db-sync-*` (`skip-unless`, expected).
- Full log: scratchpad `gate.log` (disposable).

**T13** — `satan/test/dl-secret-test.el` dropped (`git rm`); it `require`d the
config-owned `dl-secret`. Test dir 62 → 61.

**T8 (flake gptel harness)** — re-enabled the 3 commented blocks in
`/workspace/satan/flake.nix`: `satanGptelHarness` (mkDerivation from
`./satan/harness`), `satanGptelJailOptions`, `satan-jailed-gptel-harness`
(exported via `jailPkgs`→`packages`). Diff proven **pure comment-toggle**
(every changed line token-identical modulo indent + `#`). Src `./satan/harness`
present + tracked (9 files). Config-jail defs (jailed-pi/claude/opencode/dirge)
left intact per user ownership.
- **VA-3 live `nix` eval NOT runnable in-sandbox** — no `nix` binary present
  (same class as PHASE-04 host-only steps). Static half done (pure-toggle proof
  + src-exists + tracked). **Live eval host-deferred.**

**T10 diff-audit (VA-4)** — dest tree vs D1 manifest: all counts match
(satan/*.el 65, test 61, harness 9, bin 4, memory 7, protocol 1, patterns.eld 1,
docs 39, locate-paren 1, satan-test 1). GREEN.

**`.envrc` note (reconcile/PHASE-04):** satan `.envrc` = `JAIL_WORKSPACE_DEPS`
(notes/.emacs.d/flakes) + `use flake . --impure`; lacks the config `.envrc`'s
`DOCKER_HOST`. Flag when wiring host consumer.

## Carried to PHASE-04 host / reconcile (not runnable in sandbox)
- **VA-3 live `nix` flake eval** — `nix eval --impure /workspace/satan#packages.x86_64-linux.satan-jailed-gptel-harness` (+ `satan-gptel-harness` builds from `./satan/harness`). Static-verified in PHASE-01 (pure comment-toggle, src tracked); live eval runs on host. User decision 2026-07-12.
- **Untracked memory** `mem.fact.satan.package-self-location-coupling` — git-add at reconcile.
- **`.envrc` DOCKER_HOST** gap vs config `.envrc` — resolve when wiring host consumer.

## PHASE-02 phase-plan: rename-collision design gap (resolved /consult 2026-07-12)
Blunt `my/satan-* → satan-*` (D3) hard-collides with same-base `dl-satan-*` lib
fns for exactly 2 symbols (both `dl-satan-memory-migrate.el`, impl+wrapper): the
interactive wrapper defun would clobber the tested lib fn. Rule appended to D3:
lib keeps `satan-X`; colliding command → verb-first name.
- `my/satan-memory-renormalize` → `satan-renormalize-memory`
- `my/satan-memory-migrate-status` → `satan-show-migrate-status`
Wrappers have no external callers; blast radius = 2 defuns + docstrings. Other 20
`my/satan-*` commands map cleanly. EX-2/EX-3 gates unchanged.
Surface measured: `dl-satan-` ~10719 hits (4128 prod/65 files, 5926 test/61,
655 docs, 2 bin, 2 harness) + 65+61+1 file renames; `my/satan-` 87/25 files.
