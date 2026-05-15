# Keys
 Personal command interface for this Emacs config.

## Mental model

- **Leader**: `C-c <letter>` is the durable prefix. In Meow normal state, `SPC <letter>` mirrors it. `C-c f f` and `SPC f f` both reach `find-file`.
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
| `C-c g` | `my-git-map`    | git (Meow alias: `SPC G` — see Gotchas) |
| `C-c o` | `my-org-map`    | org / open *(empty)* |
| `C-c t` | `my-toggle-map` | toggles *(empty)* |
| `C-c e` | `my-eval-map`   | eval / elisp *(empty)* |
| `C-c m` | `my-term-map`   | multi-vterm + shpool (Meow alias: `SPC M` — see Gotchas) |
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

- **Populate empty maps** (`my-search-map`, `my-org-map`, `my-eval-map`). The prefix, which-key label, and Meow mirror are all wired — just add `my/bind` lines.
- **Migrate package `:bind` clauses** into the prefix structure as you touch each file: `dl-consult.el`, `dl-embark.el`, `dl-motion.el`, `dl-search.el`, `dl-fold.el`.
- **Hydras**. Package installed, no hydras yet. Window resize is the natural first one — bind under `C-c w` once defined.
- **`C-c t` collision watch**. `multi-vterm` and shpool now live at `C-c m`, but the toggle map is empty — when populating it, mind the existing `C-c t C-c t` / `C-c t C-h` use-package conventions some major modes still grab.
- **`which-key-idle-delay`**. Currently `1e6` (off). Drop to `0.5` if you want exploration popups.
