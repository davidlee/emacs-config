# Notes SL-018: Extract umbriel client to standalone Elisp package

Durable per-slice scratchpad — tracked in git. The place to lift anything from a
disposable phase sheet (`.doctrine/state/.../phase-NN.md`) that must survive
`rm -rf` before the slice close-out audit harvests it.

## Harvest
<!-- single-copy: updated in place each harvest; ids only, never restated content -->
fresh-as-of: 2026-11-11 · audit · 96b9c8a (+ RV-024, plan.toml VT-1 waiver/VT-4, uncommitted)

### Produced

- PHASE-01..04 done (09f7962 cutover, 23a73a5 helper, 41fa239 docs/records; package `~/dev/umbriel.el` c315b3b, 8d3bb77)
- RV-024: audit ledger (6 findings) with Reconciliation Brief
- minted: ISS-025 — opt-in focus hook; IDE-007 — publish the package; satan:ISS-068 — SATAN author email (uncommitted in the SATAN repo)
- user follow-ups since: IMP-033 — package font/face/docs leftovers; 79e5086 — `C-c u f` dropped
- PHASE-03 VT-1 waived and VT-4 appended (RV-024 F-1, user choice)

### Learned

- mem.fact.elisp.test-runner-feature-collision — runner named `<pkg>-test` hides the suite
- mem.fact.elisp.batch-eval-let-is-lexical — `--eval` let can't reach `bound-and-true-p`; use defvar

### Open

- RV-024 F-5 — user commits `~/.config/umbriel/app_support.toml` and satan:ISS-068 in their repos
- CHR-008 — `doctrine check gate` has no `gate` recipe
- DEC-035 — focus hook opt-in, tracked by ISS-025
- DEC-038 — push to origin waits on the user (IDE-007)

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
- Repo is `~/dev/umbriel.el`, origin `git@github.com:davidlee/umbriel.el.git`, never pushed by the run (DEC-038 supersedes DEC-033; design/plan/scope paths rewritten by the seat, flag for audit).
- PHASE-01: quotient `roots` needs `/home/david/dev/umbriel.el` (user act; `~/dev/umbriel` was added first, then renamed). A pi run sees only its own root, so the
  cross-repo copy (config → `~/dev/umbriel.el`) is a Claude step; pi does the
  rest with `cwd` `~/dev/umbriel.el`. To read the satan precedent, a pi run
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

## PHASE-01 evidence

Package repo `~/dev/umbriel.el` (outside this checkout; VA rows). Built by a Sonnet capsule-worker; verified by the orchestrator on the host.

- VA-1: `cd ~/dev/umbriel.el && nix develop -c just check` exit 0: `Ran 240 tests, 240 results as expected, 0 unexpected` · `umbriel-test-runner: 5 suites loaded` · `PASS 240/240 passed (0 skipped)`. **Package total 240** (245 - 5 keys tests). Zero-loaded guard: scratch copy without `umbriel/test/*-test.el` prints `umbriel-test-runner: 0 suites loaded`, `FAIL no tests loaded`, exit 1. Lint negative controls (scratch copies): an added byte-compile warning and an unbalanced paren each make `just lint` exit 1. No `*.elc` in the tree after `just check`.
- VA-2: `rg 'dl-umbriel|my/umbriel'`, `rg --pcre2 '\.doctrine|docs/emacs|(?<![:\w])(DEC|IMP|ISS|IDE|SL)-\d{3}'`, `rg '\bdl-|\bmy[-/]'` over the repo: all empty.
- VA-3: `lm-header`: `Author: David Lee <dav@davlee.com>`, `Version: 0.1.0`, `Package-Requires: ((emacs "30.1") (magit-section "4.0"))`. `rg -i inlight`: empty. `git log --format='%ae %ce'`: `dav@davlee.com dav@davlee.com` (import commit, see below).
- VA-4: config `git status --short` lists only `.doctrine/` paths during the phase.
- Import commit `c315b3b` (`~/dev/umbriel.el`, branch main, origin set, not pushed).
- flake.lock hand-built from `~/dev/satan/flake.lock` nodes (same pins); nothing fetched.
- EX-3 rename script (`.doctrine/state/slice/018/phase-01-rename.sh`):

```bash
#!/usr/bin/env bash
# SL-018 PHASE-01: ordered namespace rewrite over the copied package files.
# Usage: phase-01-rename.sh DIR   (rewrites DIR/umbriel/*.el, DIR/umbriel/test/*.el, DIR/docs/umbriel.md in place)
set -euo pipefail
dir=${1:?usage: phase-01-rename.sh PKG_REPO_DIR}
perl -pi -e '
  s/\bdl-umbriel-refresh\b/umbriel-refresh/g;          # (a) library refresh keeps the name
  s/\bmy\/umbriel-refresh\b/umbriel-buffer-refresh/g;  # (a) command: collision rule
  s/\bmy\/umbriel/umbriel/g;                           # (b) other my/umbriel[-X]
  s/\bdl-umbriel/umbriel/g;                            # (c) other dl-umbriel[-X]
' "$dir"/umbriel/*.el "$dir"/umbriel/test/*.el "$dir"/docs/umbriel.md
# (d) bare config record ids -> foreign form (not already qualified)
perl -pi -e 's/(?<![:\w-])((?:DEC|IMP|ISS|IDE|SL|RV)-\d{3})/emacs-config:$1/g' \
  "$dir"/umbriel/*.el "$dir"/umbriel/test/*.el "$dir"/docs/umbriel.md
```

## PHASE-02 evidence

- TDD: pi wrote `test/dl-checkout-test.el` first (run-20261110T160728303Z-25); red = `Cannot open load file ... dl-checkout`; a no-op stub fails the 3 compile tests. Pi wrote the helper (run-20261110T160837702Z-27). Guard negative control (helper without the `byte-compile-current-file` guard) fails `dl-checkout/does-nothing-while-compiling`.
- Targeted: dl-checkout-test 5/5, dl-satan-test 2/2; `bin/elisp-lint` on the 3 files: no output, exit 0.
- Host `just check` (exit 0): `Ran 600 tests, 598 results as expected, 0 unexpected, 2 skipped`.
- **Config test baseline for PHASE-03 VA-3 (design sec-5): total 600, passed 598, skipped 2** (595 at start + 5 dl-checkout tests; skipped: dl-nostr/nostr-reads-key-without-a-key-file, dl-nostr/timeline-keys-beat-meow-motion).

## PHASE-03 evidence

- Commit `09f7962` (config). TDD: pi wrote `test/dl-umbriel-keys-test.el` + `test/dl-faces-test.el` edits first (run-20261110T210324465Z-29); host red with the checkout on load-path: keys 4 unexpected (global-map, smoke, soft-load, load-order), faces 2 unexpected. Pi did the cutover (run-20261110T210503561Z-31); orchestrator fixed declare-function alignment and wrapped the `dl-dirs-checkouts` line.
- Negative controls (host, scratch copies): smoke test without the `byte-compile-current-file` defvar fails (5 `.elc` written into the checkout; removed after); integration file without the `locate-library` guard fails the soft-load test. No `.elc` in `~/dev/umbriel.el` after `just check`.
- VA-1: host `just check` exit 0: `Ran 362 tests, 360 results as expected, 0 unexpected, 2 skipped` (same 2 dl-nostr skips); lint clean. All 7 `dl-umbriel-keys/` tests passed (none skipped).
- VA-2: sweep hits only `docs/emacs/umbriel.md` (removed in PHASE-04, whose VA-1 covers it).
- VA-3: config 600 - 245 umbriel suites + 7 keys suite (5 moved + smoke + soft-load) = 362 = observed. Package 240 + config 362 = 602 = baseline 600 + 2 new tests. Skipped: 2 before, 2 after.

## PHASE-04 evidence

- EX-1: `docs/emacs/umbriel.md` removed; AGENTS.md "More" points at `~/dev/umbriel.el/docs/umbriel.md`. VA-1 sweep `rg 'docs/emacs/umbriel' --glob '!.doctrine/**' --glob '!CHANGELOG.md'`: empty. PHASE-03 VA-2 sweep now also empty.
- EX-2: CHANGELOG.md entry 2026-11-11 "umbriel client moved to its own package".
- EX-3: IMP-030, ISS-012, ISS-015, ISS-018, IDE-003 bodies rewritten with the sec-3 rules plus path rules (apps/|desktop/dl-umbriel*.el, test/dl-umbriel*-test.el, docs/emacs/umbriel.md to `~/dev/umbriel.el/...`), each with a dated move note. The three umbriel memories: bodies rewritten, `scope.paths` repointed (`memory edit --path-scope`); face-layering memory also `core/dl-faces.el` to `ui/dl-faces.el`.
- EX-4: ISS-025 (opt-in focus hook, DEC-035), IDE-007 (publish the package, DEC-038). SATAN author-email defect: satan:ISS-068 in `~/dev/satan/.doctrine/backlog/issue/068/`, left uncommitted in the SATAN repo.
- VA-2: `doctrine show` of the seven items renders `~/dev/umbriel.el` paths.
- Host `just check` exit 0: `Ran 362 tests, 360 results as expected, 0 unexpected, 2 skipped`. No `.elc` in the package checkout.
- VH-1: pending (user: daemon restart + live check).

## Autonomy log
- Re-probe at `~/dev/umbriel` (before the rename): pi `write` form writable, has git/just/rg, **no emacs** (no project flake yet). Until PHASE-01's flake exists and its form is approved (`quotient allow`, a user act), the package's lint/tests run on the host. If pi is refused `form-unapproved` there, run the step on the host; do not wait.
- seat · DEC-033→DEC-038 path/remote rewrite across design.md, plan.toml, plan.md, slice-018.md · user ruling mid-preflight · decided (audit: confirm no stale `~/dev/umbriel` path)
- PHASE-02 · fixture `load-path` widened from `(list dir)` to `(cons dir load-path)`; dropped the `bytecomp`/`byte-opt`/`warnings` requires pi had added to `core/dl-checkout.el` · they existed only because the narrowed fixture broke `byte-compile-file`'s lazy loads (test artefact in production code); unique fixture names keep real checkouts out · decided
- PHASE-02 · VA-1 sweep `rg dl-satan--compile-stale` hits CHANGELOG.md:1223 (history) · changelog is history, excluded as in the other sweeps · decided
- PHASE-01 · rename script gained step (d): bare record ids (incl. RV-nnn) -> `emacs-config:ID`, and also runs over docs/umbriel.md · VA-2 sweeps cover the whole tree; same sec-3 rule · decided
- PHASE-01 · test renamed `umbriel-buffer/my-umbriel-opens-once-…` -> `umbriel-buffer/umbriel-opens-once-…`; `bin/elisp-locate-paren-error.el` feature `dl-elisp-locate-paren-error` -> `elisp-locate-paren-error` · third sweep `\bmy[-/]`/`\bdl-` (plan EX-3) · decided
- PHASE-01 · docs/umbriel.md: doctrine frontmatter, `doctrine show` and `docs/emacs/traps.md` refs dropped; "Global keys" says the package binds none and names the author's config · config-only references (sec-3) · decided
- PHASE-01 · flake.lock hand-built from SATAN's lock nodes instead of `nix flake lock` · avoids network fetch; same pins (EX-8) · decided
- PHASE-01 · import commit amended once (local, unpushed) to name the right source repo (emacs-config, not nix-config) · factual fix · decided
- PHASE-03 · run commits the cutover (and PHASE-04) itself once host `just check` is green, overriding plan EX-9's "user commits by hand" · user ruling in this charter · decided
- PHASE-03 · VA-2 sweep evaluated with docs/emacs/umbriel.md as the one expected hit · the file is removed in PHASE-04 (EX-1), whose VA-1 sweep covers it · decided
- PHASE-03 · subprocess compile guard set with a top-level `defvar byte-compile-current-file` instead of a `let` · `--eval` is lexically bound, so a `let` is invisible to `bound-and-true-p`; same intent as EX-8 · decided
- PHASE-03 · deletions staged with `git rm --cached` before `just check` · bin/elisp-lint lints `git ls-files`, so unstaged deletions fail lint · decided
- PHASE-04 · edits made by the orchestrator, not pi · all doctrine-record work (orchestrator-owned) plus three small doc edits; a brief would cost more than the work · decided
- PHASE-04 · backlog bodies rewritten in place with a dated move note, rather than only appending a pointer · EX-3 asks the bodies to cite package paths and names; the note keeps the old names findable · decided
- PHASE-04 · satan:ISS-068 created in ~/dev/satan but not committed there · plan EX-4 places it there; the charter authorises commits only in this repo, and the SATAN tree already holds the user's uncommitted work · decided (user commits it)
- seat · post-run: `~/.config/umbriel/app_support.toml:53` (compositor scratchpad spawn) still called `my/umbriel`; the PHASE-03/04 sweeps only covered this repo. Fixed by the seat at the user's report (uncommitted there). Audit: sweep callers outside the config (compositor config, scripts) for the other renamed names · decided
- seat · PHASE-04 VH-1 recorded passed (user: "agreed"); user follow-up on focus-raise depending on package load appended to ISS-025 · decided
