<!-- doctrine:section sec-1 -->
## Context and goals

Move the umbriel IPC client (five modules, five suites; research.md
Thread 2) out of the config into its own Elisp package. The behaviour does
not change. The config keeps what is config: key bindings, derived face
shading, saved faces, and one integration file.

```
before                               after
~/.config/emacs                      ~/dev/umbriel.el            ~/.config/emacs
  desktop/dl-umbriel*.el  ──move──▶    umbriel/umbriel*.el      desktop/dl-umbriel.el (integration)
  test/dl-umbriel*-test.el ─move──▶    umbriel/test/*.el        test/dl-umbriel-keys-test.el
  keys/, ui/dl-faces.el,               dev/umbriel-test.el      keys/, ui/dl-faces.el,
  custom-vars.el                       justfile, flake.nix      custom-vars.el (renamed refs)
```

Governed by DEC-033 to DEC-037 and STD-001. SL-012 is the worked example.
Not needed (research ✓): self-location, defcustoms, process-environment
handling.

<!-- doctrine:section sec-2 -->
## Package repo (DEC-033)

`~/dev/umbriel.el`, a new git repo; origin `git@github.com:davidlee/umbriel.el.git`, never pushed by the run (DEC-038, superseding DEC-033).

```
~/dev/umbriel.el/
  umbriel/umbriel.el            client      (was dl-umbriel.el)
  umbriel/umbriel-model.el      pure model  (was dl-umbriel-model.el)
  umbriel/umbriel-columns.el    pure layout (was dl-umbriel-columns.el)
  umbriel/umbriel-focus.el      frame focus (was dl-umbriel-focus.el)
  umbriel/umbriel-buffer.el     *umbriel* UI (was dl-umbriel-buffer.el)
  umbriel/test/umbriel{,-model,-columns,-focus,-buffer}-test.el
  dev/umbriel-test-runner.el    batch ERT runner (not `umbriel-test`: see below)
  docs/umbriel.md               (was docs/emacs/umbriel.md)
  justfile  flake.nix  flake.lock  README.md  AGENTS.md  .gitignore
```

- **Headers** on `umbriel.el`: lexical-binding, `Author: David Lee`. Take the
  personal email from the git identity. **Never** copy the work email from
  `~/dev/satan/satan/satan.el:3`. Also `Version: 0.1.0`,
  `Package-Requires: ((emacs "30.1") (magit-section "4.0"))`, `Keywords`,
  `URL`. The other files get standard headers.
- **`defgroup umbriel`** goes in `umbriel-buffer.el`, beside the 17 faces
  (`:group 'umbriel`). Not in `umbriel.el`: model and columns stay
  client-free, as asserted by `model-test.el:629-652`.
- **Runner** `dev/umbriel-test-runner.el` (feature `umbriel-test-runner`): a
  cut-down copy of `~/dev/satan/dev/satan-test.el` with no DB pre-flight. It
  must not be named `umbriel-test`, because that is the client suite's
  feature. The runner skips files whose feature is already provided
  (satan-test.el:117), so the client suite would silently not run. It sets
  `load-prefer-newer t`. Contract:
  `umbriel-test-runner-run-batch-and-exit` loads every `*-test.el` under
  `umbriel/test/`, prints the ERT summary, and exits non-zero on any
  unexpected result, any load error, or **zero tests loaded**.
- **justfile**: `check: lint test`. `lint` runs a paren check and a
  byte-compile with warnings as errors on each `umbriel/*.el`. `test` runs
  `emacs -Q --batch -L umbriel -L umbriel/test -L dev -l umbriel-test-runner
  -f umbriel-test-runner-run-batch-and-exit`. Because of `-Q`, hidden
  transitive requires fail here.
- **.gitignore**: `*.elc`, `*.eln`. The config's compile helper writes
  `.elc` into the checkout.
- **flake.nix**: a minimal devshell that provides the config's wrapped Emacs
  (it has `magit-section`), `just` and `ripgrep`. Same input as SATAN's
  (`flake.nix:11-15`). Its lisp tooling (the paren checker) is copied from
  this config's `bin/elisp-locate-paren-error`, or the devshell points at
  it. The phase plan picks one.
- History starts fresh with an import commit that cites the config SHA it
  came from. Per-file history stays in the config repo.

<!-- doctrine:section sec-3 -->
## Namespace map (DEC-034)

One-step cutover, no aliases. The rules apply in order:

| From | To | Notes |
|---|---|---|
| feature / file `dl-umbriel[-X]` | `umbriel[-X]` | |
| `dl-umbriel-refresh` (lib, dl-umbriel.el:412) | `umbriel-refresh` | library keeps the name |
| `my/umbriel-refresh` (cmd, buffer.el:640) | `umbriel-buffer-refresh` | collision rule (SL-012 D3) |
| other `my/umbriel[-X]` | `umbriel[-X]` | `my/umbriel` → `umbriel`; feature/function share harmlessly |
| other `dl-umbriel-…` (fns, vars, consts, faces, hook, mode, map, macro) | `umbriel-…` | includes `--private` |
| `dl-umbriel-buffer-test--…`, test names `dl-umbriel…/` | `umbriel…` | |

Not renamed, because they are config-owned: `my-umbriel-map`,
`my/shade-umbriel-*`.

**Path and record references.** About 47 comments and docstrings cite
config paths (`docs/emacs/…`, `.doctrine/slice/016/…`) or this repo's
records (DEC-019, IMP-031, …). Rewrite them as foreign references:
`emacs-config:DEC-019`, and `docs/umbriel.md` for the moved doc. Bare ids do
not resolve in the new repo.

**Method.** Apply one ordered rewrite (refresh pair first, then `my/umbriel`,
then `dl-umbriel`) with a script over the copied files. Then check:
`rg 'dl-umbriel|my/umbriel'` and
`rg '\.doctrine|docs/emacs|(?<![:\w])(DEC|IMP|ISS|IDE|SL)-\d{3}' --pcre2` return
nothing in the package, and every
renamed symbol is still defined. That is caught by byte-compile warnings
plus the tests.

<!-- doctrine:section sec-4 -->
## Config integration

```
init.el ──require──▶ desktop/dl-umbriel.el ──use-package──▶ umbriel-buffer, umbriel-focus
                         │                                     (~/dev/umbriel.el/umbriel)
                         └─calls─▶ core/dl-checkout.el  dl-checkout-compile-stale
ai/dl-satan.el ──calls──▶ core/dl-checkout.el
keys/dl-keymap.el ─binds─▶ umbriel, umbriel-switch-workspace, umbriel-set-active-layout, umbriel-focus-frame
ui/dl-faces.el ─shades─▶ umbriel-buffer-{active-workspace[-window],workspace-name,layout}
```

- **`core/dl-dirs.el`**: append `"~/dev/umbriel.el/umbriel"` to
  `dl-dirs-checkouts` (:34-35). Load path, lint, Flymake and tests all read it.
- **`core/dl-checkout.el`** (new, DEC-036): its one concern is packages
  loaded from git checkouts.
  `(dl-checkout-compile-stale LIBRARY)` byte-compiles the `.el` files in
  LIBRARY's directory whose `.elc` is missing or older. It does nothing
  while `byte-compile-current-file` is bound. That guard lives in the helper,
  so callers need not repeat it. Its body is
  `dl-satan--compile-stale` moved here (ai/dl-satan.el:9-16), with the
  library name as a parameter. `ai/dl-satan.el` calls it with `"satan.el"`
  and keeps its own darwin/Guix gate, which is about whether SATAN is
  present.
- **`desktop/dl-umbriel.el`** (new content, at the path freed by the move):

  ```elisp
  ;;; dl-umbriel.el --- integration with umbriel (~/dev/umbriel.el) -*- lexical-binding: t; -*-
  (require 'dl-checkout)
  (if (not (locate-library "umbriel-buffer"))
      (display-warning 'dl-umbriel
                       "umbriel checkout not on load-path (~/dev/umbriel.el); skipped")
    (dl-checkout-compile-stale "umbriel.el")
    (use-package umbriel-buffer :ensure nil :demand t)
    (use-package umbriel-focus :ensure nil :demand t))
  (provide 'dl-umbriel)
  ```

  It loads on every host where the checkout exists, with no darwin or Guix
  gate. A host without the checkout gets a warning instead of a failed
  init. That is the one new behaviour: today the client ships inside the
  config.
- **`init.el:32-33`**: the two requires become `(require 'dl-umbriel)`.
- **`keys/dl-keymap.el`**: declare-functions at :198-201 point at the
  `umbriel-buffer` and `umbriel-focus` files with the new names. The binds use the new names. The comment at :627 names the package; binds at :629-632.
  `my-umbriel-map` is unchanged.
- **`keys/dl-meow-map.el:279`**: unchanged (it binds `my-umbriel-map`).
- **`ui/dl-faces.el:344-380`**: face symbols renamed to `umbriel-buffer-*`.
  There is no `with-eval-after-load` here: the shading runs at load and on
  `enable-theme-functions`. Applied on top of
  the user's uncommitted edits to this file, never by reverting them.
- **`custom-vars.el:81-84`**: the four saved faces renamed in place. The
  `:inherit magit-section-heading` spec is unchanged.

<!-- doctrine:section sec-5 -->
## Tests

| Suite | Lives | Change |
|---|---|---|
| model, columns, focus, client, buffer (minus keys block) | package `umbriel/test/` | renamed per the namespace map; `model-test` subprocess helper (:629-652) keeps its LD_LIBRARY_PATH scrub (trap 6) |
| keys block (buffer-test.el:3282-3360: 5 tests + helpers) | config `test/dl-umbriel-keys-test.el` | requires `meow`, `dl-keymap`, `dl-meow-map`; asserts the renamed commands; subprocess helper passes `load-path` incl. the checkout. **New smoke test**: a fresh `emacs -Q` with the config load path requires `dl-umbriel` and asserts `(featurep 'umbriel-buffer)` and `(commandp 'umbriel)`. This is the only gate that loads the integration file. Suite `skip-unless (locate-library "umbriel-buffer")` |
| `test/dl-faces-test.el:8, 81-113` | config | `(require 'umbriel-buffer nil t)` and the two umbriel tests `skip-unless` it; face names renamed |
| `dl-checkout` | config `test/dl-checkout-test.el` | new: stale `.el` is compiled, fresh is skipped, nothing is written while `byte-compile-current-file` is bound (red → green) |
| `dl-satan-test` | config | unchanged; still green proves the satan call site |

The config's `just check` runs config suites only. The package suites run
from `~/dev/umbriel.el` with `just check`. **Count check.** Take the baseline from the
config's `just check` summary at the end of P2 (today 595 `ert-deftest`, 245 of
them umbriel). After P3: package total + config total = baseline + new tests
(dl-checkout, the smoke test). Skipped tests are reported separately.

<!-- doctrine:section sec-6 -->
## Code impact

Design targets (recorded as `design-target` selectors):

- new repo: `~/dev/umbriel.el/**` (outside this checkout; noted, not a selector)
- removed: `desktop/dl-umbriel-{model,columns,focus,buffer}.el`,
  `test/dl-umbriel{,-model,-columns,-focus,-buffer}-test.el`
- rewritten: `desktop/dl-umbriel.el` (now the integration file)
- new: `core/dl-checkout.el`, `test/dl-checkout-test.el`,
  `test/dl-umbriel-keys-test.el`
- edited: `init.el`, `core/dl-dirs.el`, `ai/dl-satan.el`,
  `keys/dl-keymap.el`, `ui/dl-faces.el`, `custom-vars.el`,
  `test/dl-faces-test.el`
- docs: `docs/emacs/umbriel.md` (removed; pointer in AGENTS.md "More"),
  `AGENTS.md`, `CHANGELOG.md`
- doctrine (DEC-037): bodies of IMP-030, ISS-012, ISS-015, ISS-018, IDE-003
  get the new paths; the three umbriel memories get path updates; new
  backlog issue for the opt-in focus hook (DEC-035)

Unchanged: `keys/dl-meow-map.el`, `~/flakes/**` (no Nix input; DEC-033).

<!-- doctrine:section sec-7 -->
## Cutover sequence

Copy, then cut over (SL-012). The config stays green at every commit.

```
P1 package repo   copy + rename into ~/dev/umbriel.el; runner, justfile, flake;
                  package `just check` green.   Config untouched.
P2 shared helper  core/dl-checkout.el (TDD); ai/dl-satan.el calls it.
                  Config `just check` green.
P3 cutover        one config commit: dl-dirs entry, desktop/dl-umbriel.el
                  integration, delete old modules + suites, keys test moved,
                  keymap / faces / custom-vars / dl-faces-test renamed,
                  init.el.  Config `just check` green.
P4 docs + records docs move, AGENTS.md, CHANGELOG, backlog bodies, memories,
                  follow-up issue.  Live check after daemon restart (user).
```

- P1 and P2 are independent of each other. P3 needs both.
- New config files (`core/dl-checkout.el`, the two new test files) are
  `git add`ed before lint. `bin/elisp-lint` lints only tracked files
  (`bin/elisp-lint:16`), and flake builds see only tracked files (trap 1).
- If the user's `ui/dl-faces.el` WIP is still uncommitted at P3, stage only
  the rename hunks (`git apply --cached` of a filtered diff, per SL-012
  notes:261-263) and leave the user's hunks unstaged. Never revert them,
  and never use `git stash` or `git checkout` (global rule).
- Commits in the new repo stay local. Pushing waits on the user (DEC-033).

<!-- doctrine:section sec-8 -->
## Verification

| Id | Check | Mode |
|---|---|---|
| V1 | `~/dev/umbriel.el`: `just check` green; runner reports 5 suites loaded and 0 unexpected; it fails on zero tests loaded | test |
| V2 | config: `just check` green, new files tracked first; lint zero warnings; the keys suite's smoke test loads `dl-umbriel` in a fresh Emacs | test |
| V3 | in `~/dev/umbriel.el`, both sec-3 sweeps (old names; config paths and bare record ids) are empty; `rg 'my/umbriel\|dl-umbriel-(model\|columns\|focus\|buffer\|refresh)' --glob '!.doctrine/**' --glob '!CHANGELOG.md'` in config empty | agent |
| V4 | package + config test totals = P2 baseline + new tests; skipped reported separately | agent |
| V5 | `dl-checkout-test`: compiles stale, skips fresh, writes nothing while compiling | test |
| V6 | live, after daemon restart: `C-c u u` and `SPC u u` open `*umbriel*`; workspace/layout faces keep their look; `emacsclient` focus still raises the frame | human |
| V7 | `umbriel.el` headers: `lm-header` reads Author (personal identity only; no work address anywhere in the repo), Version, Package-Requires; installed magit-section (20260926.1436) satisfies the `"4.0"` floor | agent |

<!-- doctrine:section sec-9 -->
## Risks and follow-ups

- **Saved faces drop silently.** Mitigation: rename `custom-vars.el:81-84`
  in the P3 commit, and check V6.
- **User WIP in `ui/dl-faces.el`.** Mitigation: filtered staging (cutover
  sequence). Better still, the user commits it before P3.
- **Daemon runs the old names until restart.** `C-c u` breaks only between
  the P3 commit and the restart. The user restarts (V6).
- **Hidden transitive requires** surface only in a clean batch Emacs
  (SL-012 notes:187-191). Mitigation: the package runner uses `-Q`, and
  byte-compile treats warnings as errors.
- **Hosts without the checkout** (fresh machine, Guix, darwin): the config
  starts, warns, and has no umbriel. The checkout reaches a host by
  `git clone` from origin, by hand (DEC-038). The umbriel
  tests in the config skip there.
- **Guix hosts:** On Guix, `magit-section` comes from
  Guix Home, as today.

Follow-ups (backlog, at P4): make the focus hook opt-in (DEC-035); publish
(push to origin) when the user decides (DEC-038); fix the SATAN author email
(in the SATAN repo).

