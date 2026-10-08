# SL-014 design — Global keybinding ownership and collision lint

## Current vs target

| | Current | Target |
|---|---|---|
| Who writes global keys | ~32 files, 7 forms (`:bind`, `global-set-key`, `keymap-global-set`, `define-key`, `keymap-set`, `global-unset-key`, `my/bind`) | `:bind` beside its package; everything else in `core/dl-keybind.el` via `bind-keys` |
| Collisions | Last loader wins silently; 3 live (`C-:`, ``C-M-` ``, redundant `C-z` unset) | ERT test fails on any (map, key) written twice |
| Discoverability | None for non-`:bind` writes | `M-x describe-personal-keybindings` lists every personal bind and what it replaced |
| `C-c <letter>` lint | Hand-synced allow-list, already drifted (`C-c i` reported at startup, unnoticed) | Allow-list derived from naming; also run in `just check` |

## Rules (documented in `docs/KEYS.md`)

- **R1** A package's keys live in its `use-package :bind` (including
  `:map` sections for its mode maps).
- **R2** Keys without an owning `use-package` live in
  `core/dl-keybind.el`, written with `bind-keys` (`bind-keys :map M` for
  mode maps). Forbidden in config: `global-set-key`, `keymap-global-set`,
  `global-unset-key`, `local-set-key`, literal `define-key` / `keymap-set`.
  Code that builds its own keymap uses `defvar-keymap` / `define-keymap`
  (L2 cannot tell a let-bound `map` from a mode map, so it flags any
  literal `define-key`).
- **R3** Exceptions: `C-c <letter>` family prefixes stay as literal
  `define-key global-map` lines in `core/dl-keymap.el` (prefixes are
  keymap values, not commands; `bind-keys` would bind the symbol's
  function cell, which `defvar-keymap` doesn't set). `my/bind` stays the
  form for writes into personal `my-*-map` maps. `meow-*-define-key`
  stays meow's DSL (all in one place, not linted).
- **R4** Each (map, key) is written once across config. Deliberate
  duplicates need an allow-list entry with a reason.
- **R5** `[remap cmd]` is its own key space (normalises to
  `"<remap> <cmd>"`), so remaps never collide with keys.

Load order of `core/dl-keybind.el` becomes irrelevant under R4 (closes
the scope's Q3).

## Module boundaries

```
 config sources (*.el) ──read, never loaded──► core/dl-policy-lint.el
                                                 L1 C-c <letter> (live keymap)
                                                 L2 sanctioned forms (source)
                                                 L3 duplicates     (source)
                                                        │
                              lisp/test/dl-policy-lint-test.el
                                fixtures → records/violations
                                gates: real config clean on L1, L2, L3

 throwaway census (scratchpad, never committed) ──► audit table in slice notes
```

- **D1** One module for key policy: `core/dl-policy-lint.el` gains the
  static rules (scope Q5). They are plain functions; nothing new runs at
  startup. The existing startup L1 scan stays.
- **D2** L1's `my-policy-lint-family-maps` is deleted. A `C-c <letter>`
  keymap value is allowed iff it is the value of some bound symbol named
  `my-…-map` (naming convention, `docs/emacs/naming.md`). Fixes `C-c i`
  by construction. Reserved singletons (`C-c a/c/l`) stay an explicit
  list.
- **D3** Allow-list for L3: `defconst` in `dl-policy-lint.el`,
  entries `((MAP . KEY) REASON)`. Target: empty after the migration.
- **D4** L1's ERT test loads only `dl-keymap`; foreign packages that
  grab `C-c <letter>` at runtime remain the startup scan's job.
- **D5** The census is disposable (user direction): cheap scratch
  script, output recorded in slice notes, then discarded. Only the lints
  are permanent.

## Static lint (L2, L3)

Records (plist):

```elisp
(:map global-map :key "C-:" :command avy-goto-char
 :form :bind :file "editing/dl-motion.el" :line 12)
```

Parsed forms — only those with literal map and key:

| Form | Map | Key syntax |
|---|---|---|
| `use-package … :bind` / `:bind*`, with `:map X` sections (X symbol or list) | `global-map` / `override-global-map` / X | kbd |
| `bind-keys [:map X] (K . C)…` | X or `global-map` | kbd |
| `my/bind MAP K C …` | MAP | kbd |
| `define-key MAP (kbd K)\|[vec] C` | MAP | kbd / vector |
| `keymap-set MAP K C` | MAP | keymap |
| `global-set-key`, `keymap-global-set`, `global-unset-key`, `local-set-key` | `global-map` / local | kbd / keymap |

The `define-key`, `keymap-set` and last rows exist so L2 can report
them; post-migration only R3's family `define-key` lines remain. L2 also
flags `my/bind` into a map not named `my-…-map` (none today).

Key normalisation: `key-description` of the parsed vector (`kbd` for kbd
syntax, `key-parse` for keymap syntax, vectors as-is).

API sketch:

```elisp
(my-policy-lint-form-records FORM)          ; one form → records (no :file/:line)
(my-policy-lint-file-records FILE)          ; all top-level forms; :line = form start
(my-policy-lint-config-files)               ; config .el under core lisp org editing
                                            ;   completion apps lang dev + init.el,
                                            ;   excluding tests
(my-policy-lint-form-violations RECORDS)    ; L2: forbidden forms, minus R3 exemptions
(my-policy-lint-duplicates RECORDS)         ; L3: ((MAP . KEY) . RECORDS), minus allow-list
```

Invariants / edge cases:

- An unreadable file signals an error; never skipped silently (the
  prototype silently lost `core/dl-theme.el`).
- A walk into an improper or odd form must not abort the file (the
  prototype's `dl-theme.el` failure was a walker bug, not a read error).
- Non-literal map or key → no record (e.g. `my/bind`'s own body).
- Same command written twice to one key is still a duplicate.
- `:line` is the top-level form's start (`read` gives no nested
  positions).
- Comments and commented-out code are not forms — never reported.

## Migration (from the census, 2026-10-08)

371 keymap writes: 214 `my/bind`, 79 `:bind`, 64 to migrate.

| Source | Writes | Destination |
|---|---|---|
| `core/dl-keybind.el` windmove (in `use-package windmove :config`) | 4 | `:bind` on that `use-package` (R1) |
| `core/dl-keybind.el` other globals + comint | 35 | same file, `bind-keys` / `bind-keys :map comint-mode-map` |
| `core/dl-keymap.el` `C-x C-j`, `C-x C-n` | 2 | `dl-keybind.el` |
| `org/dl-org-{agenda,capture,links}.el` `C-c a/c/l` | 3 | `dl-keybind.el` (no `use-package` in those files) |
| `core/dl-prose.el` `M-Q`; `apps/dl-term.el` `s-C-<return>`, `C-<f2>` | 3 | `dl-keybind.el` |
| `editing/dl-crux.el` (5 in `:config`) | 5 | `:bind` on `use-package crux` |
| `org/dl-org.el` org-timeblock remaps | 4 | `:bind (:map …)` on `use-package org-timeblock` |
| `core/dl-meow.el` `C-\` in two meow state maps | 2 | `:bind (:map …)` on `use-package repeat-fu` |
| `completion/dl-vertico.el` (3), `completion/dl-embark.el` (1), `apps/dl-term.el` eshell (1) | 5 | `:bind (:map …)` on the owning `use-package` |

Collision resolutions (user decisions, 2026-10-08):

| Key | Writers | Resolution |
|---|---|---|
| `C-:` | `jinx-correct` (`core/dl-prose.el`), `avy-goto-char` (`editing/dl-motion.el`) | avy keeps it; jinx keeps `M-$` |
| ``C-M-` `` | `popper-toggle-type` (`core/dl-popups.el`), `popterm-toggle` (`apps/dl-ghostel.el`) | popper keeps it; `popterm-toggle` moves to `C-<f1>` (its `:bind`), replacing `my/ghostel-toggle`, which is then unbound and deleted from `apps/dl-term.el` |
| `C-z` | `global-unset-key` then `global-set-key`, same file | drop the redundant unset |

Other fixes:

- Global zoom: `global-text-scale-adjust` dispatches on the invoking key
  (`-` out, `0` reset, else in), so the `my/global-text-scale-*`
  wrappers are wrong (`…-decrease` on a `-` key zooms in). Bind
  `global-text-scale-adjust` directly on `C-M-=`, `C-M-+`, `C-M--`,
  `C-S-0`; delete `lisp/dl-global-text-scale.el` and its note in
  `docs/REVIEW.md`.
- `apps/dl-ghostel.el`: key string `"C-M-` "` has a trailing space;
  removed when the binding moves.
- `docs/KEYS.md`: add R1–R5; fix stale lines (`C-;` is `iedit-mode`, not
  `avy-goto-char-timer`; `C-<f1>` is `popterm-toggle`, including the
  `[C-f1] . vterm-toggle` example near L483; zoom keys).
- Stale comment in `core/dl-keybind.el` about `C-<f1>`.

## Verification

ERT (`lisp/test/dl-policy-lint-test.el`, runs in `just check`):

- `form-records/bind-global`, `/bind-map-sections`, `/bind-map-list`,
  `/bind-star`, `/bind-keys`, `/bind-keys-map`, `/my-bind`,
  `/define-key-vector`, `/keymap-set-syntax`, `/remap-own-space`,
  `/non-literal-skipped`
- `violations/global-set-key-flagged`, `/define-key-mode-map-flagged`,
  `/family-prefix-exempt`
- `duplicates/cross-file`, `/same-file`, `/allow-listed`
- `l1/family-by-naming` (a foreign keymap on `C-c x` is flagged; a
  `my-…-map` is not)
- Gates: real config L1 clean, L2 clean, L3 clean.

Red/green: the gates go red on the current tree (3 duplicates, 64
violations, `C-c i`), green after the migration.

Live checks (by agent, against the running Emacs after reload):
`C-:` → `avy-goto-char`, ``C-M-` `` → `popper-toggle-type`, `C-<f1>` →
`popterm-toggle`, `C-M--` zooms out, `describe-personal-keybindings`
shows the migrated keys.

## Risks

- The ERT gates read the real config from `user-emacs-directory`
  (`--init-directory` in `just check`; `~/.emacs.d` in
  `check-interactive`). Both resolve to the repo root.

- Moving `crux` / `org-timeblock` / `repeat-fu` keys into `:bind` makes
  those packages autoload instead of loading eagerly. `org-timeblock`
  has `:demand t` (stays eager); `crux` gains deferral — verify the
  remapped `keyboard-quit` / `move-beginning-of-line` still resolve
  (autoloaded commands in remaps work).
- `:bind (:map X)` on a map defined by a package other than the
  `use-package` subject (`org-mode-map` in embark's block,
  `meow-*-state-keymap` in repeat-fu's) needs the map to exist when the
  binding runs; `use-package` wraps `:map` binds in `eval-after-load` of
  the subject package only. Use `bind-keys :map` inside
  `with-eval-after-load` of the map's owner, or put the bind in the
  map owner's block. Resolve per site during execution.
- `vertico-map` binds currently run at top level after `use-package
  vertico`; moving them into its `:bind` is straightforward.

## Out of scope / follow-ups

- IMP-019: mode-owned `C-c` range rule and live per-mode shadowing probe
  (reuses `dl-policy-lint.el`).
- Correct ISS-010's stale `C-=` / `C--` "pending" line at close.
