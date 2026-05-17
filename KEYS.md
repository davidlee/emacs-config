# Keys
 Personal command interface for this Emacs config.

## Mental model

- **Leader**: `C-c <letter>` is the durable prefix. In Meow normal state, `SPC <letter>` and `h <letter>` both mirror it. `C-c f f`, `SPC f f`, and `h f f` all reach `find-file`. `h` is bound directly to `mode-specific-map` (the C-c keymap), so lowercase `g` / `m` work without the capital-letter workaround the `SPC` leader needs.
- **Editing vs. commands**: Meow normal state stays editing-focused (motions, selection, operators). Commands live under the leader.
- **Single source of truth**: prefix maps, the `my/bind` helper, the Meow leader mirror, and which-key prefix labels all live in `core/dl-keymap.el`. Package files declare commands (`:commands`) and own their mode-local maps (`:bind (:map foo-mode-map …)` in `:config`).
- **Discoverability**: `C-h` after a prefix triggers `embark-prefix-help-command`. `describe-keymap RET my-file-map RET` lists a map. `SPC ?` runs `meow-cheatsheet`. `which-key-idle-delay` is `0.3` (see `core/dl-keybind.el`); auto-popups fire after a third of a second of hesitation.

## Policy

1. **Personal global namespace.** Personal global bindings live under
   `C-c <letter>`, uppercase or lowercase. This is the Emacs
   user-reserved namespace. `C-c C-…`, `C-c <digit>`, and
   `C-c <punct>`/`C-c <symbol>` spaces are reserved by convention for
   major/minor modes and must not be used for personal global families.
   `C-c` is the durable source of truth. Modal leaders such as `SPC` and
   `h` in Meow may mirror the same maps but do not define a separate
   command grammar.

2. **Family prefixes.** A top-level `C-c <letter>` binding is a command
   family. One letter means one family. Adding a new top-level family
   is a budget decision; prefer extending an existing family or creating
   a coherent compartment.

3. **Lowercase and uppercase variants.** Inside a family, lowercase
   keys are common actions; uppercase keys are heavier, wider, or
   adjacent variants of the same mnemonic. Examples: `f f` find /
   `f S` save-as; `s s` search current scope / `s S` search wider scope.

4. **Uppercase compartments.** An uppercase key may open a compartment
   sub-prefix when it represents a real sub-domain with its own
   internal grammar. Compartments are not overflow buckets. Example:
   `n W` = work-note compartment, mirroring note verbs inside a work
   scope.

5. **Package-local bindings.** Mode-local and package-local bindings
   stay with their package configuration. The central keymap owns
   global entry points and cross-package command families, not every
   command exposed by every mode.

6. **Reserved local conventions.** Preserved: `C-c a` org-agenda,
   `C-c c` org-capture, `C-c l` org-store-link. Avoided: `C-c h` as a
   top-level family, because `h` is already the modal gateway into the
   `C-c` command space.

## Policy lint

`core/dl-policy-lint.el` enforces the rules above. It scans `mode-specific-map` for single-letter bindings and flags anything that isn't either a `my-*-map` family map or one of the reserved singletons.

- `M-x my-policy-lint` — pops `*Policy Lint*` with each offending key, its binding, and the reason (`foreign-map` / `foreign-command`).
- Silent startup check — runs from `emacs-startup-hook`; logs a single line to `*Messages*` iff violations exist, never opens a buffer.

The lint catches what `my/bind`'s collision warning can't: foreign packages that grab `C-c <letter>` from their own `:config` (the case-in-chief is `ready-player-mode` clobbering `C-c m`, fixed via `(setq ready-player-set-global-bindings nil)` in `apps/dl-dired.el`). Keep `my-policy-lint-family-maps` in sync when adding a new tier-1 prefix.

## Prefix index

| Prefix | Map | Purpose |
|---|---|---|
| `C-c f` | `my-file-map`    | files |
| `C-c b` | `my-buffer-map`  | buffers |
| `C-c w` | `my-window-map`  | windows (arrow keys for direction) |
| `C-c s` | `my-search-map`  | search (scope ladder — see [Search](#search-c-c-s)) |
| `C-c p` | `my-project-map` | project (project.el-aligned) |
| `C-c j` | `my-jump-map`    | jump (avy family; chord escape hatches `C-:` / `C-;` in `dl-motion.el`) |
| `C-c g` | `my-git-map`     | git (Meow alias: `SPC G` — see Gotchas) |
| `C-c n` | `my-notes-map`   | notes (sub-prefixes: `N` new, `m` manage, `v` review, `W` work). See [Notes](#notes-c-c-n) and `NOTES.md`. |
| `C-c o` | `my-org-map`     | org — cross-buffer entry points (clocking, refile, heading jump). In-buffer ops stay at Org's `C-c C-<x>`. |
| `C-c t` | `my-toggle-map`  | toggles |
| `C-c e` | `my-eval-map`    | eval / elisp (scope ladder over Elisp) |
| `C-c m` | `my-term-map`    | ghostel + shpool (Meow alias: `SPC M` — see Gotchas) |
| `C-c z` | `my-fold-map`    | fold (kirigami dispatcher — routes to outline / hs / treesit-fold) |

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
| `C-c n r` | `my-roam-map`                       | roam compartment (see [Roam](#c-c-n-r--roam)) |

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

### `C-c n r` — roam

Org-roam stays wired (db autosync + capture) but isn't the primary navigator. Bindings were lifted out of `dl-org-roam.el` to clear tier-1 `C-c r`; nothing else in the config currently calls them.

| Key | Command | |
|---|---|---|
| `C-c n r f` | `org-roam-node-find`     | find node |
| `C-c n r i` | `org-roam-node-insert`   | insert link to node |
| `C-c n r b` | `org-roam-buffer-toggle` | backlinks/refs side window |
| `C-c n r c` | `org-roam-capture`       | roam capture |
| `C-c n r s` | `org-roam-db-sync`       | re-sync DB |
| `C-c n r g` | `org-roam-graph`         | graph view |

### Agenda scope (`C-c a`)

| Key | What |
|---|---|
| `C-c a a` | default dispatcher (combined union — every operational file) |
| `C-c a p` | personal-only agenda (inbox + journal + weekly + projects) |
| `C-c a w` | work-only agenda (work inbox + journal + weekly + projects + meetings + people) |
| `C-c a c` | combined agenda (explicit form of `a`) |

## Org (`C-c o`)

Cross-buffer entry points only. In-buffer Org commands (narrow,
schedule, TODO state, table ops, export) stay at Org's own
`C-c C-<x>` — Org owns the mode-specific space.

| Key | Command | |
|---|---|---|
| `C-c o h` | `consult-org-heading` | heading jump in current buffer |
| `C-c o H` | `consult-org-heading` over `org-agenda-files` | heading jump across corpus |
| `C-c o j` | `org-clock-goto` | jump to active clock |
| `C-c o i` | `org-clock-in-last` | resume last clock |
| `C-c o O` | `org-clock-out` | close clock |
| `C-c o r` | `org-refile` | refile current heading |
| `C-c o q` | `my/org-ql-find-here` | org-ql over current buffer (file-scoped; `C-c n q` is corpus-scoped) |
| `C-c o b` | `org-switchb` | switch between open Org buffers |
| `C-c o L` | `org-insert-link-global` | insert a stored link from anywhere |

Global Org short forms (kept for muscle memory): `C-c c` capture, `C-c
l` store-link, `C-c a` agenda. The `C-c n c` / `C-c n l` namespaced
forms are aliases for discoverability.

## Search (`C-c s`)

Scope ladder. Lowercase narrows; uppercase widens. Helpers
(`my/consult-line-symbol-at-point`, `my/consult-ripgrep-prompt-dir`)
live in `completion/dl-consult.el`.

| Key | Command | Scope |
|---|---|---|
| `C-c s s` | `consult-line`                    | current buffer |
| `C-c s S` | `consult-line-multi`              | all open buffers |
| `C-c s .` | `my/consult-line-symbol-at-point` | symbol-at-point in current buffer |
| `C-c s o` | `consult-outline`                 | buffer outline |
| `C-c s i` | `consult-imenu`                   | buffer symbols |
| `C-c s I` | `consult-imenu-multi`             | project symbols |
| `C-c s r` | `consult-ripgrep`                 | project root |
| `C-c s R` | `my/consult-ripgrep-prompt-dir`   | arbitrary directory |
| `C-c s d` | `consult-find`                    | filenames under project |
| `C-c s m` | `consult-mark`                    | buffer mark ring |
| `C-c s M` | `consult-global-mark`             | global mark ring |
| `C-c s g` | `rg-menu`                         | rg.el transient dispatcher |
| `C-c s q` | `vr/query-replace`                | visual-regexp query-replace (interactive) |
| `C-c s Q` | `vr/replace`                      | visual-regexp replace (one-shot) |

Non-prefix globals (Emacs-native escape hatches, configured in
`dl-consult.el`): `M-y` yank-pop, `M-g g` goto-line, `M-s r`
ripgrep, `C-x b` switch-buffer.

`rg-enable-default-bindings` was retired in `dl-search.el` — it
clobbered `C-c s` with `rg-global-map` and broke the family map.
`rg-menu` is the dispatcher; the common path is `consult-ripgrep`
at `s r` / `s R` / `M-s r`.

## Project (`C-c p`)

Parallel family. Letters mirror `project.el`'s own `C-x p <letter>`
defaults so muscle memory between the two prefixes is identical.

| Key | Command | |
|---|---|---|
| `C-c p p` | `project-switch-project`       | switch project |
| `C-c p f` | `project-find-file`            | find file |
| `C-c p b` | `project-switch-to-buffer`     | switch buffer |
| `C-c p k` | `project-kill-buffers`         | kill all project buffers |
| `C-c p d` | `project-dired`                | dired at root |
| `C-c p D` | `project-find-dir`             | find directory |
| `C-c p c` | `project-compile`              | compile |
| `C-c p r` | `project-query-replace-regexp` | query-replace across project |
| `C-c p g` | `project-find-regexp`          | grep (xref-based) — complements `s r` |
| `C-c p v` | `project-vc-dir`               | vc-dir |
| `C-c p e` | `project-eshell`               | eshell at root |
| `C-c p s` | `project-shell`                | shell at root |
| `C-c p !` | `project-shell-command`        | one-shot shell command |

## Jump (`C-c j`)

avy family. The chord bindings in `editing/dl-motion.el` (`C-:`
`avy-goto-char`, `C-;` `avy-goto-char-timer`) are the fast paths;
this map is the discoverable surface.

| Key | Command | |
|---|---|---|
| `C-c j j` | `avy-goto-line`        | line |
| `C-c j c` | `avy-goto-char-timer`  | char (timer) |
| `C-c j 2` | `avy-goto-char-2`      | 2-char (rescued from `C-'`, now `embark-dwim`) |
| `C-c j w` | `avy-goto-word-1`      | word |
| `C-c j p` | `my/forward-or-backward-sexp` | match paren (vim `%`) |

`C-,` (was `goto-last-change`) and `C-'` (was `avy-goto-char-2`) were
reassigned to `embark-act` / `embark-dwim`. `C-.` still gives you
`goto-last-change-reverse`; rebind forward elsewhere if you miss it.

## Eval (`C-c e`)

Scope ladder over Elisp. Lowercase reads to the minibuffer; uppercase
prints/inserts into the buffer.

| Key | Command | |
|---|---|---|
| `C-c e e` | `eval-last-sexp`           | last sexp |
| `C-c e E` | `eval-print-last-sexp`     | last sexp + insert result |
| `C-c e f` | `eval-defun`               | enclosing defun |
| `C-c e r` | `eval-region`              | region |
| `C-c e b` | `eval-buffer`              | buffer |
| `C-c e i` | `ielm`                     | Elisp REPL |
| `C-c e s` | `scratch-buffer`           | jump to `*scratch*` |
| `C-c e x` | `eval-expression`          | one-shot expression (alias of `M-:`) |
| `C-c e m` | `pp-macroexpand-last-sexp` | macroexpand at point |

## File (`C-c f`)

| Key | Command | |
|---|---|---|
| `C-c f f` | `find-file`           | open file |
| `C-c f s` | `save-buffer`         | save |
| `C-c f S` | `write-file`          | save-as |
| `C-c f r` | `consult-recent-file` | recent file |
| `C-c f d` | `dired-jump`          | dired here |
| `C-c f D` | `dirvish`             | dirvish |
| `C-c f t` | `dirvish-side`        | dirvish (side tree) |
| `C-c f y` | `my/yazi-here`        | yazi |
| `C-c f b` | `my/broot-here`       | broot |
| `C-c f K` | `my/delete-current-buffer-file` | delete file on disk + kill buffer (confirm) |
| `C-c f M` | `my/move-file`        | write to new path, delete old |

Project-scoped file commands live at `C-c p` — see [Project](#project-c-c-p).
Globals: `C-x C-j` dired-jump, `C-x C-n` dirvish-side.

## Buffer (`C-c b`)

| Key | Command | |
|---|---|---|
| `C-c b b` | `consult-buffer`           | switch |
| `C-c b k` | `kill-current-buffer`      | kill |
| `C-c b i` | `ibuffer`                  | ibuffer |
| `C-c b n` | `my/next-user-buffer`      | next (skips `*…*` and dired) |
| `C-c b p` | `my/previous-user-buffer`  | prev (skips `*…*` and dired) |
| `C-c b t` | `my/tmp-buffer`            | timestamped throwaway, same major mode |

`my/user-buffer-p` in `lisp/dl-buffer-management.el` is the filter.
Meow leader also mirrors `SPC [` / `SPC ]` for flick-style cycling.
Global: `C-x b` → `consult-buffer` (in `dl-consult.el`).

## Window (`C-c w`)

Direction keys are arrow keys, not h/j/k/l — see [Layout](#layout).

| Key | Command | |
|---|---|---|
| `C-c w <left>`  | `windmove-left`        | focus left |
| `C-c w <down>`  | `windmove-down`        | focus down |
| `C-c w <up>`    | `windmove-up`          | focus up |
| `C-c w <right>` | `windmove-right`       | focus right |
| `C-c w s`       | `split-and-follow-horizontally` | split below + focus new pane |
| `C-c w v`       | `split-and-follow-vertically`   | split right + focus new pane |
| `C-c w S`       | `split-window-below`   | split below (no focus) |
| `C-c w V`       | `split-window-right`   | split right (no focus) |
| `C-c w o`       | `delete-other-windows` | keep only this window |
| `C-c w d`       | `delete-window`        | delete |
| `C-c w =`       | `balance-windows`      | balance |
| `C-c w f`       | `transpose-frame`           | swap horizontal ⇄ vertical splits (whole frame) |
| `C-c w c`       | `my/rotate-windows`         | cycle buffers forward through non-dedicated windows |
| `C-c w C`       | `my/rotate-windows-backward` | cycle buffers backward |
| `C-c w x`       | `my/window-exchange-buffer`  | swap two windows' buffers via ace-window (focus stays) |
| `C-c w P`       | `my/toggle-window-dedicated` | pin (dedicate) selected window to its buffer |
| `C-c w r`       | `hydra-window-resize/body`   | resize hydra (sticky `←/→` width, `↑/↓` height, `=` balance, `q` quit) |

`transpose-frame` is also bound chord-style at `C-x 7` (see
`core/dl-interface.el`). Split-and-follow lives in
`core/dl-interface.el`; rotate-windows live in `lisp/dl-window.el`.

## Git (`C-c g`)

`SPC g` is eaten by `meow-keypad` (C-M- dispatcher) — use `SPC G` as
the leader alias. `C-c g` always works.

| Key | Command | |
|---|---|---|
| `C-c g g` | `magit-status` | status |
| `C-c g l` | `git-link`     | shareable URL to current line |

## Term (`C-c m`)

[ghostel](https://github.com/dakra/ghostel) terminals plus shpool
session manager (`apps/dl-shpool.el`). `SPC m` is eaten by
`meow-keypad` (M- dispatcher) — use `SPC M` as the leader alias.

| Key | Command | |
|---|---|---|
| `C-c m t` | `ghostel`                  | switch / create ghostel |
| `C-c m T` | `my/ghostel-here`          | new ghostel in `default-directory` |
| `C-c m o` | `ghostel-project`          | new ghostel at project root |
| `C-c m n` | `ghostel-other`            | next ghostel buffer |
| `C-c m a` | `my/shpool`                | attach shpool session |
| `C-c m p` | `my/shpool-project`        | attach project session |
| `C-c m F` | `my/shpool-force`          | force-attach (steal) |
| `C-c m r` | `my/shpool-restore`        | restore session set |
| `C-c m L` | `my/shpool-list`           | list sessions |
| `C-c m d` | `my/shpool-detach-current` | detach |
| `C-c m k` | `my/shpool-kill-session`   | kill session |
| `C-c m +` | `my/shpool-add-current-to-restore` | add to restore set |
| `C-c m -` | `my/shpool-remove-from-restore`    | remove from restore set |
| `C-c m f` | `my/shpool-forget-session` | forget session |

## Toggle (`C-c t`)

Session knobs — display modes, editor behaviors, debug switches.
Lowercase/uppercase pairs follow the [Policy](#policy) variant rule:
`l`/`L`, `s`/`S`, `B`/`G`, `d`/`D` are buffer/global or scope variants.

| Key | Command | |
|---|---|---|
| `C-c t l` | `display-line-numbers-mode`         | line numbers (buffer) |
| `C-c t L` | `global-display-line-numbers-mode`  | line numbers (global) |
| `C-c t w` | `visual-line-mode`                  | visual-line (soft-wrap) |
| `C-c t t` | `toggle-truncate-lines`             | truncate-lines |
| `C-c t h` | `hl-line-mode`                      | highlight current line |
| `C-c t p` | `display-fill-column-indicator-mode` | fill-column indicator |
| `C-c t W` | `whitespace-mode`                   | whitespace marks |
| `C-c t r` | `read-only-mode`                    | read-only |
| `C-c t f` | `auto-fill-mode`                    | auto-fill (hard-wrap) |
| `C-c t s` | `jinx-mode`                         | spellcheck (buffer) |
| `C-c t S` | `my/jinx-global-mode`               | spellcheck (prog/text/org) |
| `C-c t c` | `my/toggle-margins`                 | margins (olivetti / vfc) |
| `C-c t V` | `variable-pitch-mode`               | variable-pitch font |
| `C-c t e` | `electric-pair-mode`                | electric-pair |
| `C-c t i` | `indent-tabs-mode`                  | tabs vs. spaces |
| `C-c t a` | `auto-revert-mode`                  | auto-revert |
| `C-c t n` | `my/narrow-or-widen-dwim`           | narrow / widen (region/defun/subtree) |
| `C-c t m` | `flymake-mode`                      | flymake |
| `C-c t d` | `toggle-debug-on-error`             | debug-on-error |
| `C-c t D` | `toggle-debug-on-quit`              | debug-on-quit |
| `C-c t T` | `consult-theme`                     | theme picker |
| `C-c t P` | `spacious-padding-mode`             | spacious padding |
| `C-c t B` | `tab-line-mode`                     | tab-line (buffer) |
| `C-c t G` | `global-tab-line-mode`              | tab-line (global) |
| `C-c t g` | `diff-hl-mode`                      | diff-hl (vcs gutter) |
| `C-c t *` | `prettify-symbols-mode`             | prettify symbols |
| `C-c t )` | `rainbow-delimiters-mode`           | rainbow delimiters |
| `C-c t R` | `rainbow-mode`                      | rainbow (color literals) |
| `C-c t =` | `aggressive-indent-mode`            | aggressive-indent |
| `C-c t E` | `my/eglot-toggle`                   | eglot start/shutdown |

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

- **More hydras**. `hydra-window-resize` (at `C-c w r`) is the first
  defhydra; the package is now loaded eagerly in `core/dl-keybind.el`.
  Future candidates: zoom (`text-scale-adjust`), error navigation
  (`flymake-goto-{next,prev}-error`), and outline traversal.
- **`C-c k` config kit**. The reserved `k` letter is earmarked for a
  Nix-aware config kit (open `~/flakes/modules/home/emacs.nix`,
  `home-manager switch`, etc.) — see `AGENTS.md` for the integration
  traps before designing this.
- **Nil-out meow keypad prefixes**. Setting
  `meow-keypad-meta-prefix nil`, `meow-keypad-ctrl-meta-prefix nil`,
  `meow-keypad-literal-prefix nil`, and `meow-keypad-start-keys nil`
  would release `SPC g` / `SPC m` (currently aliased to `SPC G` /
  `SPC M`) and let lowercase mirrors of every `C-c <letter>` family
  work uniformly under `SPC`. Cost: loses Meow's built-in
  `SPC c …` / `SPC x …` → `C-c …` / `C-x …` keypad dispatchers, and
  `SPC` becomes purely a leader with no literal-input escape.
  Revisit if keypad mode goes unused and the alias inconsistency
  keeps biting — see `Gotchas` entry above and lambda-emacs's
  `meow.local.el` for the precedent.
- **`C-c t` collision watch**. The toggle map is well-populated now, but mind the `C-c t C-c t` / `C-c t C-h` use-package conventions some major modes still grab when adding new toggles.
- **Reserved letters**. `d` (diagnostics) and `k` (config / "kit") are kept free for future tier-1 families per the [Policy](#policy) budget. Don't grab them for one-off binds.
- **Slack re-enable**. `apps/dl-slack.el` is currently uninstalled (`init.el:76` commented). If/when it returns, the global `C-c S …` family must be lifted into `core/dl-keymap.el` under a sub-prefix — see the header comment in `dl-slack.el`.
