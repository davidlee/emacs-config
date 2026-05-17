# Keys
 Personal command interface for this Emacs config.

## Mental model

- **Leader**: `C-c <letter>` is the durable prefix. In Meow normal state, `SPC <letter>` and `h <letter>` both mirror it. `C-c f f`, `SPC f f`, and `h f f` all reach `find-file`. `h` is bound directly to `mode-specific-map` (the C-c keymap), so lowercase `g` / `m` work without the capital-letter workaround the `SPC` leader needs.
- **Editing vs. commands**: Meow normal state stays editing-focused (motions, selection, operators). Commands live under the leader.
- **Single source of truth**: prefix maps, the `my/bind` helper, the Meow leader mirror, and which-key prefix labels all live in `core/dl-keymap.el`. Package files declare commands (`:commands`) and own their mode-local maps (`:bind (:map foo-mode-map …)` in `:config`).
- **Discoverability**: `C-h` after a prefix triggers `embark-prefix-help-command`. `describe-keymap RET my-file-map RET` lists a map. `SPC ?` runs `meow-cheatsheet`. `which-key-idle-delay` is currently off — set it to `0.5` if you want auto-popups.

## Prefix index

| Prefix | Map | Purpose |
|---|---|---|
| `C-c f` | `my-file-map`   | files |
| `C-c b` | `my-buffer-map` | buffers |
| `C-c w` | `my-window-map` | windows (arrow keys for direction) |
| `C-c s` | `my-search-map` | search *(empty)* |
| `C-c j` | `my-session-map` | easysession (currently disabled in `dl-keymap.el`) |
| `C-c g` | `my-git-map`    | git (Meow alias: `SPC G` — see Gotchas) |
| `C-c n` | `my-notes-map`  | notes (3 sub-prefixes: `N` new-by-class, `m` manage, `v` review). See [Notes](#notes-c-c-n) and `NOTES.md`. |
| `C-c o` | `my-org-map`    | org / open (only `h` → `consult-org-heading` so far) |
| `C-c t` | `my-toggle-map` | toggles *(empty)* |
| `C-c e` | `my-eval-map`   | eval / elisp *(empty)* |
| `C-c m` | `my-term-map`   | ghostel + shpool (Meow alias: `SPC M` — see Gotchas) |
| `C-c z` | `my-fold-map`   | fold (kirigami dispatcher — routes to outline / hs / treesit-fold) |

## Fold (`C-c z`)

Vim/Evil `z`-prefix mnemonics. Bindings call into [kirigami](https://github.com/jamescherti/kirigami.el), which dispatches to whichever backend the current buffer has active (outline-minor-mode, hs-minor-mode, treesit-fold, org, ...) — so the same keys work everywhere a fold backend is on.

| Key | Command | |
|---|---|---|
| `C-c z o` | `kirigami-open-fold`     | open fold at point |
| `C-c z O` | `kirigami-open-fold-rec` | open recursively |
| `C-c z r` | `kirigami-open-folds`    | open all |
| `C-c z c` | `kirigami-close-fold`    | close fold at point |
| `C-c z m` | `kirigami-close-folds`   | close all |
| `C-c z a` | `kirigami-toggle-fold`   | toggle |

Backend selection lives in `editing/dl-fold.el` — `outline-minor-mode` for lisp/conf/markdown/diff, `hs-minor-mode` for legacy major modes (c, js, sh, ...), `treesit-fold-mode` for the `*-ts-mode` family. No fold backend hooked in → kirigami no-ops.

## Notes (`C-c n`)

Notes corpus is `~/notes/`. **Architecture, classes, capture pipeline,
metadata conventions, deferred work all live in `NOTES.md`** — this
section is the keymap only.

Four sub-prefixes under `C-c n`:

- `C-c n N` — new-by-class constructors (`my/denote-new-*`, drops file
  in the matching subdir + tags it)
- `C-c n m` — manage / mutate existing notes (rename, edit keywords)
- `C-c n v` — review surfaces (`my/review-*`)
- `C-c n W` — work compartment (constructors directly under `W`,
  review under `W v`)

### Top-level

| Key | Command | |
|---|---|---|
| `C-c n c` | `org-capture`                       | capture (templates: `c j s S r p L`) |
| `C-c n j` | `my/journal-note`                   | open today's Denote-named journal |
| `C-c n w` | `my/weekly-note`                    | open this week's weekly journal (ISO week) |
| `C-c n n` | `denote`                            | new note (plain — prompts for class via keywords) |
| `C-c n f` | `consult-notes`                     | find note (narrow keys: `j w p a s S r i`) |
| `C-c n s` | `consult-notes-search-in-all-notes` | search across notes |
| `C-c n l` | `org-store-link`                    | store link |
| `C-c n i` | `denote-link`                       | insert link |
| `C-c n o` | `org-open-at-point-global`          | open link |
| `C-c n g` | `org-mark-ring-goto`                | go back |
| `C-c n b` | `denote-backlinks`                  | backlinks |
| `C-c n q` | `org-ql-find`                       | org-ql query dispatcher |

### `C-c n N` — new-by-class

| Key | Command | Subdir | Class tag |
|---|---|---|---|
| `C-c n N p` | `my/denote-new-project`   | `projects/`   | `:project:` |
| `C-c n N a` | `my/denote-new-area`      | `areas/`      | `:area:` |
| `C-c n N s` | `my/denote-new-source`    | `sources/`    | `:source:` |
| `C-c n N S` | `my/denote-new-slip`      | `slips/`      | `:slip:` |
| `C-c n N r` | `my/denote-new-reference` | `references/` | `:reference:` |
| `C-c n N i` | `my/denote-new-index`     | `indexes/`    | `:index:` |
| `C-c n N j` | `my/journal-note`         | `journal/`    | `:journal:` |
| `C-c n N w` | `my/weekly-note`          | `weekly/`     | `:weekly:` |

### `C-c n m` — manage

| Key | Command | |
|---|---|---|
| `C-c n m r` | `denote-rename-file`                    | rename file (prompts) |
| `C-c n m R` | `denote-rename-file-using-front-matter` | rename from `#+title:` / `#+filetags:` |
| `C-c n m k` | `denote-rename-file-keywords`           | edit keyword set (add + remove in one prompt) |
| `C-c n m t` | `denote-rename-file-title`              | retitle (filename slug + `#+title:`) |

### `C-c n v` — review

| Key | Command | What it surfaces |
|---|---|---|
| `C-c n v i` | `my/review-inbox`                  | `inbox.org`, point at first TODO |
| `C-c n v I` | `my/review-intake`                 | Dired `intake/`, newest first |
| `C-c n v w` | `my/review-weekly`                 | weekly note + side-window of WAITING items |
| `C-c n v s` | `my/review-stale`                  | WAITING items with no timestamp in `my/review-stale-days` (7) |
| `C-c n v r` | `my/review-references-retained`    | ripgrep `references/` for `status: raw` |
| `C-c n v u` | `my/review-references-untrusted`   | ripgrep `references/` for `:untrusted:` / `trust: unreviewed` |

### `C-c n W` — work compartment

Constructors live directly under `W` (not duplicated into `C-c n N`); review surfaces under `W v`.

| Key | Command | |
|---|---|---|
| `C-c n W h` | open `work.org` (dashboard) | |
| `C-c n W i` | open `work/inbox.org`       | |
| `C-c n W I` | dired `work/intake/`        | newest first |
| `C-c n W j` | `my/work-journal-note`      | today's work journal |
| `C-c n W w` | `my/work-weekly-note`       | this week's work weekly |
| `C-c n W q` | `my/work-org-ql-find`       | org-ql over work files |
| `C-c n W p` | `my/denote-new-work-project`   | `:work:project:` → `work/projects/` |
| `C-c n W a` | `my/denote-new-work-area`      | `:work:area:`    → `work/areas/` |
| `C-c n W m` | `my/denote-new-work-meeting`   | `:work:meeting:` → `work/meetings/` |
| `C-c n W P` | `my/denote-new-work-person`    | `:work:person:`  → `work/people/` |
| `C-c n W s` | `my/denote-new-work-source`    | `:work:source:`  → `work/sources/` |
| `C-c n W S` | `my/denote-new-work-slip`      | `:work:slip:`    → `work/slips/` |
| `C-c n W r` | `my/denote-new-work-reference` | `:work:reference:` → `work/references/` |
| `C-c n W x` | `my/denote-new-work-index`     | `:work:index:`   → `work/indexes/` |

### `C-c n W v` — work review

Mirrors the personal review set, scoped to work files / dirs.

| Key | Command | |
|---|---|---|
| `C-c n W v i` | `my/review-work-inbox`                | `work/inbox.org` at first TODO |
| `C-c n W v I` | `my/review-work-intake`               | dired `work/intake/` |
| `C-c n W v w` | `my/review-work-weekly`               | work weekly + WAITING side window |
| `C-c n W v s` | `my/review-work-stale`                | work WAITING > stale-days |
| `C-c n W v r` | `my/review-work-references-retained`  | ripgrep work refs `status: raw` |
| `C-c n W v u` | `my/review-work-references-untrusted` | ripgrep work refs untrusted |

### Agenda scope (`C-c a`)

| Key | What |
|---|---|
| `C-c a a` | default dispatcher (combined union — every operational file) |
| `C-c a p` | personal-only agenda (inbox + journal + weekly + projects) |
| `C-c a w` | work-only agenda (work inbox + journal + weekly + projects + meetings + people) |
| `C-c a c` | combined agenda (explicit form of `a`) |

### Other org binds (`C-c o`)

| Key | Command | |
|---|---|---|
| `C-c o h` | `consult-org-heading` | in-buffer outline search (consult bundles consult-org) |

Global Org short forms (kept for muscle memory): `C-c c` capture, `C-c
l` store-link, `C-c a` agenda. The `C-c n c` / `C-c n l` namespaced
forms are aliases for discoverability.

## Adding a binding

### To an existing prefix map

In `core/dl-keymap.el`:

```elisp
(my/bind my-file-map "p" #'find-file-other-window "other-window")
```

`my/bind` does three things: `define-key`, warn on overrides, register a which-key label. The Meow `SPC` mirror is already wired — `SPC f p` works automatically.

### A new prefix map

Four spots in `dl-keymap.el`:

1. `(defvar-keymap my-foo-map :name "foo")`
2. `(define-key global-map (kbd "C-c X") my-foo-map)`
3. Add `"C-c X" "foo"` to the `which-key-add-key-based-replacements` block
4. Add `(cons "X" my-foo-map)` to `meow-leader-define-key`

### Mode-local bindings (map owned by a package)

Always `with-eval-after-load` or use-package's `:config` — never `:init`. The map is void at `:init` time.

```elisp
(use-package vterm-toggle
  :bind (([C-f1] . vterm-toggle))
  :config
  (define-key vterm-mode-map (kbd "M-n") #'vterm-toggle-forward))
```

`:bind (:map FOO-MAP …)` works **only when `FOO-MAP` is owned by the current package**, because bind-keys' deferral keys off the current package's load, not the map's owner.

### Cross-package binding (commands from A bound in keymap from B)

Declare autoloads on the source package with `:commands`. Then bind centrally:

```elisp
;; apps/dl-term.el
(use-package multi-vterm :commands (multi-vterm multi-vterm-next multi-vterm-prev))

;; core/dl-keymap.el
(my/bind my-term-map "t" #'multi-vterm "vterm")
```

## Gotchas we've hit

- **Orphan leader maps**. Don't define a leader keymap without binding it to a key — `my-leader-map` lived for weeks as silent doc.
- **`vterm-mode-map` in `:init`**. Void at init time. Use `:config`.
- **`:bind :map` for foreign maps**. bind-keys defers to the current package, not the map's owner. Symptoms: `eval-after-load-helper: Symbol's value as variable is void: foo-mode-map`. Fix: move to `:config`, or add an explicit `with-eval-after-load`.
- **`:defer` / `:ensure-system-package` parse errors**. use-package keywords sit at the top level of the form. A keyword without a value, or one buried inside `:config` body, makes the parser see "keyword wants exactly one argument" or "wants a non-empty list."
- **Nested `defun` warnings**. A `defun` inside `(use-package … :config …)` defines the function at runtime fine, but the byte-compiler doesn't promote it to "known" status — calls a few lines later warn "not known to be defined." Hoist the `defun` above the use-package form, or inline it.
- **`my/bind` override messages**. `my/bind: overriding KEY in MAP: OLD -> NEW` in `*Messages*` means two bindings fight. Resolve at the source.
- **Meow keypad eats `SPC g` and `SPC m`**. After `SPC`, Meow checks `meow-keypad-meta-prefix` (`m` → M-) and `meow-keypad-ctrl-meta-prefix` (`g` → C-M-) **before** consulting the leader keymap (`meow-keypad.el:485-513`). `c` and `x` are similarly reserved as the `C-c`/`C-x` dispatchers. Workaround: lowercase `C-c g`/`C-c m` work everywhere; in Meow normal state use the capital aliases `SPC G`/`SPC M` (bound in `meow-leader-define-key`) or route via `SPC c g g`.

## Layout

- Gallium split keyboard with home-row arrows on a layer. Directional bindings use `<left>/<down>/<up>/<right>`, not h/j/k/l. (Meow normal state still uses Meow's default h/j/k/l motions — separate concern.)

## Deferred

- **Populate empty maps** (`my-search-map`, `my-eval-map`, `my-toggle-map` partial). The prefix, which-key label, and Meow mirror are all wired — just add `my/bind` lines. `my-org-map` now holds `consult-org-heading`; `my-notes-map` is fully populated (see [Notes](#notes-c-c-n)).
- **Re-enable session map**. `my-session-map` (`C-c j`) and its easysession binds are commented out in `dl-keymap.el`. Uncomment if the easysession workflow is back in play, otherwise drop the which-key label too.
- **Migrate package `:bind` clauses** into the prefix structure as you touch each file: `dl-consult.el`, `dl-embark.el`, `dl-motion.el`, `dl-search.el`, `dl-fold.el`.
- **Hydras**. Package installed, no hydras yet. Window resize is the natural first one — bind under `C-c w` once defined.
- **`C-c t` collision watch**. `multi-vterm` and shpool now live at `C-c m`, but the toggle map is empty — when populating it, mind the existing `C-c t C-c t` / `C-c t C-h` use-package conventions some major modes still grab.
- **`which-key-idle-delay`**. Currently `1e6` (off). Drop to `0.5` if you want exploration popups.
