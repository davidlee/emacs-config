# SL-014 implementation notes

## PHASE-01 — Key policy lints (2026-10-08)

Done. `core/dl-policy-lint.el` now holds L1–L3; `lisp/test/dl-policy-lint-test.el`
(27 tests) runs in `just check`.

- **L1 (D2).** `my-policy-lint-family-maps` deleted. A `C-c <letter>` keymap
  passes iff some bound `my-…-map` variable holds it (one `mapatoms` pass per
  scan, `my-policy-lint--family-maps`). `my-policy-lint-scan` takes an optional
  map for fixtures. `C-c i` (`my-org-iw-map`) is clean by construction; the
  real-config gate (`l1-real-config`, `require 'dl-keymap`) is green.
- **Records.** `my-policy-lint-form-records` walks every subform except
  `quote` data. Positional writers are table-driven (`my-policy-lint--writers`:
  map arg or fixed map, key arg, key syntax, command arg). Three key syntaxes:
  `raw` (define-key / global-*-key strings are event strings, not kbd),
  `kbd` (`:bind`, `bind-keys`, `my/bind`), `keymap` (`keymap-set`,
  `keymap-global-set`). `(kbd "…")` and vectors accepted everywhere.
  Positional map must be a symbol (a call like `(foo)` is non-literal); a
  `:map` list in `:bind` means several maps.
- **Files.** `my-policy-lint-file-records` reads with
  `forward-comment` + `read`; any read error re-signals naming file:line.
  `:file` is relative to `user-emacs-directory`. `my-policy-lint-config-files`:
  `init.el` + top level of the 8 config dirs, minus tests and dotfiles
  (`.#` lock files). Test-file predicate duplicates `dl-test--file-p`
  (dev runner; requiring it from a runtime module would invert the dependency).
- **L2.** `forbidden-form` for the six raw writers, minus R3 family prefixes
  (shape + `core/dl-keymap.el`); `my-bind-foreign-map` for `my/bind` into a
  map not named `my-…-map`.
- **L3.** `seq-group-by` on (map . key); allow-list
  `my-policy-lint-duplicate-allow-list` (empty).

### Dry run on the real config (not committed as a gate — PHASE-02)

371 records (by form: `my/bind` 214, `:bind` 79, `global-set-key` 41,
`define-key` 23, `keymap-global-set` 8, `keymap-set` 5, `global-unset-key` 1);
64 L2 violations; 3 L3 duplicates (`C-z`, `C-:`, ``C-M-` ``). Identical to
`research/census.md`, and `core/dl-theme.el` (lost by the census prototype) now
reads.

### Incidental

- `plan.toml`: the first `[[phase]]` header was commented out
  (`# One [[phase]]`), so PHASE-01 parsed as top-level keys and
  `doctrine slice phases` reported "up to date" without a phase-01 sheet.
  Fixed the header.
- `docs/KEYS.md`: stale "keep family-maps in sync" sentence replaced (rest of
  the docs is PHASE-03).

## PHASE-02 — Migrate key writes; resolve collisions (2026-10-08)

Done in `4d8fb12`. Gates `l2-real-config` / `l3-real-config` went red
(64 / 3), green after migration. Allow-list stays empty.

### Audit table (collisions)

| Key | Writers before | Resolution |
|---|---|---|
| `C-:` | `jinx-correct` (`core/dl-prose.el` :bind), `avy-goto-char` (`editing/dl-motion.el` :bind) | avy keeps it; jinx keeps `M-$` |
| ``C-M-` `` | `popper-toggle-type` (`core/dl-popups.el`), `popterm-toggle` (`apps/dl-ghostel.el`, key had a trailing space) | popper keeps it; `popterm-toggle` → `C-<f1>` |
| `C-<f1>` | `my/ghostel-toggle` (`apps/dl-term.el`) | replaced by `popterm-toggle`; `my/ghostel-toggle` deleted |
| `C-z` | `global-unset-key` + `global-set-key`, `core/dl-keybind.el` | unset dropped |

### Where things went

- `core/dl-keybind.el`: all ownerless globals as `bind-keys` blocks (tabs,
  editing chords, `C-x C-j/C-n` from dl-keymap, org `C-c a/c/l`, `M-Q`,
  `C-s-<return>`, view scroll, zoom, function keys incl. `C-<f2>`), plus
  `bind-keys :map comint-mode-map`. windmove keys → its `:bind`.
- `:bind` moves: crux (now deferred; remaps resolve to autoloads), vertico
  (`:demand t`), org-timeblock (`:demand t`, two `:map` sections),
  repeat-fu (`:map meow-*-state-keymap`; meow is eager above it, so the
  `boundp` branch binds immediately), popterm.
- embark's `org-mode-map` `C-,`: `bind-keys :map` inside the existing
  `with-eval-after-load 'org` (map owned by org; adding `:bind` to
  `use-package org` would defer org).
- eshell `C-r`: `eshell-mode-map` is defined in `esh-mode`, which
  `(require 'eshell)` does NOT load — `use-package eshell :bind (:map
  eshell-mode-map …)` would `void-variable` after eshell loads. Bound on
  `use-package esh-mode :ensure nil`; the old `my/setup-eshell` hook
  workaround is gone (Emacs 31 eshell uses `eshell-mode-map` directly as
  the local map — verified).
- Deleted: `lisp/dl-global-text-scale.el`, `org/dl-org-links.el` (held only
  `C-c l`; `init.el` require and `docs/NOTES.md` line removed),
  `my/ghostel-toggle`, `my/setup-eshell`.
- `bind-keys :map` takes one symbol: a list breaks its `(boundp 'MAP)`
  wrapper, so two maps = two `:map` sections.

### Verification

- `just check` 166/166.
- VA-1: full init in a fresh batch Emacs (scratch `va1b.el`): no init
  error; 37 key spot checks all resolve as designed (globals, three
  resolutions, zoom, crux remaps, comint, vertico, meow state maps,
  org-timeblock, org `C-,`, eshell `C-r`); `my/ghostel-toggle` and
  `my/global-text-scale-*` unbound; `personal-keybindings` has
  `C-x C-j`, `M-Q`, comint `C-p`; L1 clean. The only stderr noise,
  `Error loading autoloads: (void-function define-compilation-mode)`,
  reproduces with `early-init.el` alone (pre-existing batch artefact).
- VH-1: user restarted and smoke-tested daily keys — "looks good" (2026-10-08).

### Incidental

- A first batch-init attempt without clearing `kill-emacs-hook` rewrote
  `~/.emacs.d/project-window-list` on exit (round trip of the loaded
  file; content intact, 32 KB). Recipe recorded as memory.

## PHASE-03 — Document rules (2026-10-08)

Docs only, plus two stale comments in `core/dl-keymap.el`.

- `docs/KEYS.md`: new § Ownership rules (R1–R5, `describe-personal-keybindings`);
  § Policy lint now a table of L1/L2/L3 — what each checks, what it reads,
  where it runs (L1 startup + `M-x my-policy-lint` + `l1-real-config`; L2/L3
  only `just check`); allow-list named. Mental model restated per R1/R2.
  "Adding a binding": R3 note on the family `define-key`; the
  `[C-f1] . vterm-toggle` + `define-key` example replaced by the real
  `tempel` `:bind`/`:map` block and a `bind-keys` example; Gotchas gained
  the map-owner sharp edges (one-symbol `:map`, `:bind` defers).
  Zoom keys stated in Deferred.
- Pre-existing staleness fixed while there: Jump section claimed `C-;`
  avy-timer and `C-'` embark-dwim. Live: `C-;` iedit, `C-'`
  `avy-goto-char-2`, `M-.` embark-dwim, `C-.`/`C-S-.` goto-chg.
- `docs/REVIEW.md`: `dl-global-text-scale.el` clause dropped.
- `CHANGELOG.md`: entry naming changed keys/commands and the lints.

### Verification

- VA-1: `rg -F` over KEYS.md/REVIEW.md for `C-;`, `C-:`, ``C-M-` ``,
  `C-<f1>`, `C-f1`, `vterm-toggle`, `ghostel-toggle`, `global-text-scale`,
  `dl-org-links`, `C-z`, `family-maps`, `setup-eshell`, `jinx` — every hit
  matches live bindings (checked against `rg` of config sources).
- `just check` 166/166.

## Audit (RV-015, 2026-10-08)

Conformance audit done: 3 findings, all terminal. F-1 (design § Migration
stale on embark/eshell/dl-org-links sites) → reconcile brief; F-2 (ERT names)
tolerated; F-3 (pre-existing KEYS.md Jump staleness) fixed in `8b6984f`.
Harvest: phase-sheet findings already in this file; memories
`mem.fact.emacs.keybinding-map-owners` + batch-init recipe recorded in
PHASE-02. No new backlog items (IMP-019 already holds the follow-up).
