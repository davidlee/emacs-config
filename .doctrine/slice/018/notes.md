# Notes SL-018: Extract umbriel client to standalone Elisp package

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-11 · planned (status ready) · f505183 (+ uncommitted doctrine artefacts)

### Produced

DEC-033, DEC-034, DEC-035, DEC-036, DEC-037 · RV-023 (done: 13 findings
raiser-verified at plan time, pi run run-20261110T154155679Z-12-7b2c632eebd7) ·
design.md (run rev 31, locked) · research/research.md (restamped at plan) ·
plan.toml + plan.md (PHASE-01..04; plan-time refinements in plan.md)

### Learned

- Runner/suite feature collision trap: a runner named `<pkg>-test` hides the
  `<pkg>-test.el` suite (satan-test.el:117 skip-if-featurep). Candidate
  memory at close.

### Open

- Follow-up backlog to file at P4: opt-in focus hook (DEC-035); SATAN
  author-email defect (SATAN repo); remote/publish (DEC-033).

## Design triage (2026-11-11, exploring)

Evidence: `research/research.md` (✓ = verified).

### Shaping decisions (need answers)

- Q1 Repo name, path, layout: `~/dev/umbriel` with `umbriel/*.el` (SATAN
  layout) vs flat. GitHub remote now or later (outward-facing).
- Q2 Cutover: one step, no aliases (SL-012 precedent) vs obsolete aliases.
- Q3 `refresh` collision ✓: lib keeps `umbriel-refresh`; command name TBD
  (e.g. `umbriel-buffer-refresh`).
- Q4 `server-switch-hook` added at load (dl-umbriel-focus.el:40 ✓): keep
  (mechanical) vs opt-in (behaviour change).
- Q5 Stale-`.elc` shim (ai/dl-satan.el:9-16 ✓): generalise to one config
  helper vs copy.
- Q6 Key tests (dl-umbriel-buffer-test.el:3282-3360 ✓) move to a config
  suite; name.
- Q7 Records: DECs stay as history; backlog items move only if the new
  repo has a tracker.

### Risks

- Saved faces in custom-vars.el:81-84 drop silently if not renamed together.
- User's uncommitted ui/dl-faces.el edits overlap the face rename.
- Daemon runs old names until restart.

### Assumptions

- No self-location needed ✓ (no user-emacs-directory use).
- magit-section is the only non-core dependency.

### Constraining governance

STD-001 (faces home; one concern per file), docs/emacs/naming.md,
AGENTS.md traps 1 and 6. POL-001 and ADR-001 checked, not applicable.

### Out of band

- quotient `read` form needs re-approval (`form-unapproved`).
- ~/dev/satan/satan/satan.el:3 `Author:` carries the work email (separate
  defect in the SATAN repo).

## Review passes (2026-11-11, reviewing)

What a further pass would probe, if run: (a) the namespace rewrite order
(sec-3) against macro-generated row commands (buffer.el:964; checked: the table at :659 names each command symbol literally, so a textual rewrite covers it); (b) whether `use-package umbriel-buffer` with
`:ensure nil` on Guix finds magit-section; (c) the filtered-staging step for
user WIP. An adversarial (GPT) pass is optional: the change is mechanical,
SL-012 is a close precedent, and every load-bearing claim is ✓. Point (a) is already resolved.

## Review pass 1 — pi (deepseek-flash, `review` profile), 2026-11-11

Run `run-20261110T152943879Z-5-d755815d3cf9` (evidence under
`~/.local/state/quotient/runs/`). 13 findings; adjudicated on evidence:

- Accepted, design revised (sec-2/3/4/5/7/8/9): F1 integration file
  `require`/`provide`; F2 runner/suite feature collision (confirmed:
  satan-test.el:117 skips provided features) → runner `umbriel-test-runner`;
  F3 hard checkout dependency → soft-load with warning; F4 smoke test that
  loads `dl-umbriel` in a fresh Emacs; F5 defgroup moves to umbriel-buffer.el
  (confirmed: model-test.el:647); F6 lint sees tracked files only (confirmed:
  bin/elisp-lint:16) → `git add` first; F7 `-Q` and zero-loaded guard;
  F8 47 path/record refs → foreign refs + sweep; F9 `.gitignore`,
  `load-prefer-newer`; F10 V7 made checkable; F11 count equality from P2
  baseline (595 / 245 umbriel); F13 line refs.
- Rejected: F10 pin worry (installed magit-section 20260926.1436 satisfies
  "4.0"); F12 central compile list in core/ (couples core to every package;
  per-integration call is the STD-001 shape; package-side compile out of
  scope).

A further pass would probe: the soft-load branch on a host without the
checkout (needs a run, not a read), and the foreign-ref rewrite list. Not
needed before lock: both are covered by V2 (smoke) and V3 (sweep).

## Implementation run

Seat: /super-orchestrator, started 2026-11-11. Main worktree, no dispatch.

**Operator rulings (user, this session):**
- Planning artefacts committed by the seat as one commit before PHASE-01/02.
- PHASE-01: the user adds `/home/david/dev/umbriel` to quotient `roots`
  (policy.src.json) and approves it. A pi run sees only its own root, so the
  cross-repo copy (config → `~/dev/umbriel`) is a Claude step; pi does the
  rest with `cwd` `~/dev/umbriel`. To read the satan precedent, a pi run
  needs `cwd` `~/dev/satan` (allowed root).
- Gate: host `just check` is the only authoritative gate. Sandbox-only
  failures below are known, not form gaps.

**Host gate:** `just check` from `/home/david/.config/emacs` (Justfile exports
`SATAN_DB_HOST` etc.). Baseline at start (HEAD `f505183`): 595 tests,
593 expected, 0 unexpected, 2 skipped, exit 0.

**Known sandbox-only failures (pi `write` form, cwd config root):**
- `just lint` / `just check` exit 1: `ai/dl-sediment.el:6` cannot load
  `sediment`; `test/dl-modeline-test.el:8`, `test/dl-org-iw-test.el:9`
  cannot load `org-iw` (external checkouts not bound into the form).
- Running `dev/dl-test.el` outside `just` errors on the production-DB guard
  unless `SATAN_DB_HOST` is set; never set `SATAN_FAILOVER_TO_SYSTEM_DB`.
- Workers therefore run targeted checks: `bin/elisp-lint FILE…` (works in
  sandbox), `bin/elisp-locate-paren-error FILE`, and per-file ERT
  (`emacs --batch -Q -L <dir> -l <test> -f ert-run-tests-batch-and-exit`).
- Sandbox tools present: emacs 31.1, just, git (guarded), rg, fd, jq, bash,
  network. Absent: nix, python3.

**Other writers:** the user may edit `.doctrine/` and unrelated files.
Commit only a phase's own paths.

## Autonomy log
