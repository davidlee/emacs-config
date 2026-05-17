# Changelog

Notable changes to this Emacs config. Loosely dated; not versioned.

## 2026-05-17 — notes system overhaul, Phase 2 (module decomposition)

Pure refactor: split `org/dl-org.el` into focused modules. No behaviour
change — every binding, template, advice, and var resolves the same as
before.

**New modules** (all under `org/`, all tracked via git so the Nix flake
parser picks them up):

- `dl-org-capture.el` — capture templates (7: `i/f/j/P/r/p/L`),
  `my/capture-body`, `my/capture-entry`, `my/sanitize-link-description`,
  `my/org-capture-delete-client-frame` + the
  `my/org-capture-delete-frame-on-finalize` flag, advice on
  `org-capture-finalize`/`kill`, and the `C-c c` global binding.
- `dl-org-agenda.el` — `org-agenda-files` (now derived from
  `dl-notes-*` constants), `C-c a` global binding. Custom agenda
  commands land here in Phase 5.
- `dl-org-links.el` — `C-c l` (`org-store-link`). Home for the Phase 4
  consolidated `C-c n l/i/o/g` link namespace.
- `dl-denote-journal.el` — `my/daily-note`, `my/weekly-note`, and their
  `C-c n d/w` bindings. Home for the Phase 3 Denote-named rewrite.

**Slimmed `dl-org.el`**: keeps org defaults (directory, todo keywords,
tag-alist, log-done, return-follows-link, speed-commands), org-modern
and org-bullets styling, and the mode-hook spacing tweak. Everything
else moved out.

**init.el load order** (in section `;; Org`):

```
(require 'dl-org)
(require 'dl-org-capture)
(require 'dl-org-agenda)
(require 'dl-org-links)
(require 'dl-denote)
(require 'dl-denote-journal)
(require 'dl-org-roam)
```

**Modules deferred** rather than created empty (per "no half-finished
implementations"):

- `dl-denote-templates.el` — class constructors (`my/denote-new-project`
  etc). Phase 3/4 when they have content.
- `dl-org-ql.el` / `dl-citar.el` — Phase 5, when the packages land.
- `dl-review.el` — Phase 6.
- `dl-writing.el` — `core/dl-prose.el` already covers prose/spelling
  cleanly; the plan's `dl-writing.el` is redundant with what exists.
  Keeping `dl-prose.el` where it is.

**Known pre-existing bug** (left untouched, flagged for later):
`org-modern`'s `use-package` block uses `:after` followed by `add-hook`
calls — `:after` takes a package list, not body forms, so the hooks
never get added. `org-modern-mode` is currently not actually enabled on
`org-mode-hook`. Fix: change `:after` to `:config` (or `:hook`). Not
part of Phase 2's "no behaviour change" promise.

**Touched:** `init.el`, `org/dl-org.el` (slimmed), 4 new modules under
`org/`.

## 2026-05-17 — notes system overhaul, Phase 1 (paths + dirs + TODO)

First slice of the notes-system overhaul plan
(`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). No new packages, no
module decomposition — just the substrate.

**Filesystem.** `~/notes` was a symlink to `~/tasks/00_inbox/`; promoted
in place: `rm` the symlink, `mv ~/tasks/00_inbox ~/notes`. Reorganised
inside the new real `~/notes/`:

- Created `intake/ journal/ weekly/ projects/ areas/ sources/ slips/
  indexes/ references/ attachments/ archive/`.
- `_archived/` → `archive/`, `assets/` → `attachments/`, `context/` →
  `references/` (the two LLM research markdowns land here; will need
  `:reference:llm:untrusted:` tags on review per the plan).
- 5 daily files in `2026/YYYY-MM-DD.org` → renamed to Denote-style
  `YYYYMMDDT000000--yyyy-mm-dd-weekday__journal.org` under `journal/`.
- Deleted empty placeholders (`indices/`, `notes/`, `refs/`, `writing/`)
  whose names don't match the new vocab. `projects/` was already
  on-name; kept.
- 6 root-level Denote notes left at root — homing into class subdirs is
  Phase 7 triage (content, not config).
- `.git/`, `.gitignore`, `.org-roam.db` preserved via the bulk dir
  move. Corpus history intact.
- `~/tasks/{10_daily, 20_weekly, 30_projects, 40_areas, 50_notes,
  90_archive}` left untouched — legacy parking, separate triage.

**New module: `core/dl-notes-paths.el`.** Single source of truth for
notes paths. Defines `dl-notes-root`, `dl-notes-inbox-file`, and
per-class dir constants (`dl-notes-{intake,journal,weekly,projects,
areas,sources,slips,indexes,references,attachments,archive}-dir`), plus
`my/notes-path` for joining segments under root. Required early in
`init.el` (after `dl-core`).

**Downstream rewires** (replace string literals with constants):

- `org/dl-org.el`: `org-directory`, `org-default-notes-file`,
  `org-agenda-files`, all capture-template file paths, and
  `my/daily-note`/`my/weekly-note` now derive from `dl-notes-*`. Daily
  and weekly point at the new `journal/`/`weekly/` dirs but keep the
  simple `YYYY-MM-DD.org` / `YYYY-WNN.org` naming for now — Denote-named
  rewrite is Phase 3. Agenda dropped the (gone) `writing/` and added
  `weekly/`. Duplicate `(global-set-key "C-c c" #'org-capture)` (had
  shadowed itself at L130) removed.
- `org/dl-denote.el`: `denote-directory` → `dl-notes-root`.
- `org/dl-org-roam.el`: `org-roam-directory` → `(file-truename
  dl-notes-root)`. Roam stays wired but unused (separate
  acceleration layer per the plan; not the primary navigator).

**TODO state expansion.** Old: `TODO NEXT WAIT | DONE CANCELLED`. New:
`TODO NEXT STARTED WAITING(w@/!) | DONE(d!) CANCELED(c@) MOVED(m@)`.
Logging triggers added (`!` for done, `@` for waiting/canceled/moved).
One existing match (`work.org:5` had `** WAIT`) swept via `sed` to
`WAITING`. `CANCELLED` → `CANCELED` rename had no matches.

**Touched:** `core/dl-notes-paths.el` (new — tracked via git so the Nix
flake parser sees it), `init.el`, `org/dl-org.el`, `org/dl-denote.el`,
`org/dl-org-roam.el`, plus the filesystem migration outside the repo.

Phases 2-7 (module decomposition, Denote-based journaling, capture
template rework + keymap consolidation, org-ql/consult-notes/citar,
review workflow, root-note triage) remain.

## 2026-05-16 — org-protocol capture from Firefox

Wired up [sprig/org-capture-extension](https://github.com/sprig/org-capture-extension)
end-to-end. Three bugs found en route:

- **Desktop handler used `%F` (files) instead of `%u` (URL)**, so the
  Emacs-provided `emacsclient.desktop` silently dropped the
  `org-protocol://` URI and created a blank frame. New
  `~/.local/share/applications/org-protocol.desktop` (tracked via the
  sparse `~/` worktree) handles the scheme with `%u`, `--create-frame`,
  `--no-wait`.
- **`(concat org-directory "protocol.org")`** produced
  `~/notesprotocol.org`. Replaced with `expand-file-name`.
- **Duplicate template key `p`**: "Project task" shadowed "Protocol"
  (assoc returns first match). Renamed Project task to `P`.

Templates corrected to use the org-protocol plist keys (`%:link`,
`%:description`) instead of `%u` (which is the inactive timestamp, not
the URL) and `%c` (clipboard pollution).

Two improvements from the sprig README, with safety tweaks:

- **`my/sanitize-link-description`** replaces `[` `]` in the `L`
  template's description so ArXiv-style titles don't break the
  `[[link][desc]]` syntax.
- **Auto-close the emacsclient frame** after `org-capture-finalize` /
  `org-capture-kill`.  Uses a boolean flag set by the template (cleaner
  than sprig's counter) and guards with `(frame-parameter nil 'client)`
  + `(cdr (frame-list))` so manual `C-c c p` from the main frame is
  safe and the last frame is never deleted.  Refile is covered by the
  finalize advice — refile calls finalize internally.

**Touched:** `org/dl-org.el`, `~/.local/share/applications/org-protocol.desktop`.

## 2026-05-16 — session leader + meow `h` as C-c, autosave hook fix

Two related cleanups around the leader system.

**`my-session-map` (`C-c j` / `SPC j` / `h j`).** Easysession's defaults
were `C-c s*`, which `define-key` silently descended into `my-search-map`
(squatting in the search namespace). Moved them onto their own prefix
with which-key labels and meow leader mirror, via `my/bind`:

```
C-c j s   save           C-c j r   rename
C-c j l   load           C-c j R   reset
C-c j L   load+geometry  C-c j u   unload
                         C-c j d   delete
```

**Meow normal `h` → `mode-specific-map`.** Bound `h` directly to the C-c
keymap, so `h f f`, `h j s` etc. work from normal state as a third path
alongside `C-c` and `SPC`. Bonus over `SPC`: lowercase `g` / `m` work
without the capital workaround (no meow-keypad in the way). Dropped
`meow-left` — home-row arrows live on a layer.

**Autosave bug.** `(add-hook 'after-focus-change-function …)` was wrong
— that variable holds a single function (`#'ignore` advised by
`blink-cursor--rescan-frames`), not a hook list. `add-hook` cons'd the
function onto the existing advised form, producing an uncallable list and
spamming `Invalid function:` on every focus event. Replaced with
`add-function :after`, arity-tolerant via a `&rest _` wrapper.

**Touched:** `core/dl-keymap.el`, `editing/dl-persist.el`, `KEYS.md`.

## 2026-05-16 — file manager: dired/dirvish + yazi/broot wrappers

Consolidated the file-management stack on Dired + Dirvish, with Yazi and
Broot reachable as ghostel terminals that hand a path back to Emacs on
exit. Single home for everything under `my-file-map` (`C-c f` / `SPC f`):
`d` dired-jump, `D` dirvish, `t` dirvish-side, `F` project-find-file, `p`
project-switch, `y` yazi, `b` broot. Existing `f/s/S/r` kept.

Retired `dired-preview`, `dired-sidebar`, `nerd-icons-dired`, `dired-subtree`,
plus a duplicate `recentf` block in `editing/dl-persist.el` and the stray
`("C-c f" . dirvish-dwim)` bind that was shadowing the prefix. `C-x C-n`
moved from `dired-sidebar-toggle-sidebar` to `dirvish-side`.

Yazi uses `--cwd-file`, Broot uses `--outcmd` (parses the `cd PATH` line —
use **alt-enter** to fire `:cd`). Sentinel kills the ghostel buffer on exit.

See `FILE_MANAGER.md` for the full layout and the traps hit along the way
(missing `(require 'dl-dirvish)` in `init.el`, `lexical-binding` cookie on
the wrong line).

**Touched:** `apps/dl-dired.el`, `apps/dl-dirvish.el`, `core/dl-keymap.el`,
`core/dl-interface.el`, `editing/dl-project.el`, `editing/dl-persist.el`,
`init.el`.

## 2026-05-16 — nixd over nil, with flake-aware completion

Switched the Nix LSP from `nil` to `nixd` and fed it workspace settings so it
can evaluate the flake at `~/flakes`:

- `nixpkgs.expr` resolves to the flake's own nixpkgs input → completion for
  real package attrs (`pkgs.<TAB>`).
- `options.nixos` → `nixosConfigurations.Sleipnir.options` (option completion
  + docs under `config.*` in NixOS modules).
- `options.home-manager` → `homeConfigurations.david.options` (same for HM
  modules).
- `formatting.command` → `alejandra`, matching the flake's treefmt.

Hostname and HM user are hardcoded constants in `lang/dl-nix.el`. First
completion in a session is slow (full flake eval); subsequent calls are
cached. Activate with `M-x eglot-reconnect` in a `.nix` buffer.

**Touched:** `lang/dl-nix.el`.

## 2026-05-16 — vterm → ghostel

Replaced the vterm/multi-vterm/vterm-toggle stack with [ghostel](https://github.com/dakra/ghostel)
(libghostty-vt). Shpool session management (`apps/dl-shpool.el`) was ported to
ghostel's API in the same change — `shpool attach` is now spawned directly via
`ghostel-exec` instead of "open vterm, then send `exec shpool attach NAME`".

**Touched:** `apps/dl-term.el`, `apps/dl-shpool.el`, `core/dl-keymap.el`.

### Recovery — restoring vterm

To roll back, drop ghostel and reinstate the three blocks below in
`apps/dl-term.el`, plus the old `my-term-map` bindings in `core/dl-keymap.el`.

`apps/dl-term.el` (was the entire ghostel section):

```elisp
(use-package vterm
  :commands vterm
  :custom
  (vterm-kill-buffer-on-exit t)
  :bind (:map vterm-mode-map
          ("C-c <escape>" . vterm-send-escape))
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))

(defun my/vterm-named (name)
  "Open or create a named (for NAME) vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name))))

(use-package vterm-toggle
  :custom
  (vterm-toggle-hide-method 'delete-window)
  (vterm-toggle-fullscreen-p nil)
  :bind (([C-f1] . vterm-toggle)
          ([C-f2] . vterm-toggle-cd))
  :init
  (add-to-list 'display-buffer-alist
    '((lambda (buffer-or-name _)
        (let ((buffer (get-buffer buffer-or-name)))
          (equal major-mode 'vterm-mode)))
       (display-buffer-reuse-window display-buffer-at-bottom)
       (dedicated . t)
       (reusable-frames . visible)
       (window-height . 0.3)))
  :config
  (define-key vterm-mode-map [(control return)] #'vterm-toggle-insert-cd)
  (define-key vterm-mode-map (kbd "M-n")        #'vterm-toggle-forward)
  (define-key vterm-mode-map (kbd "M-p")        #'vterm-toggle-backward))
```

`core/dl-keymap.el` — replace the current `ghostel`/`ghostel-other` lines:

```elisp
(my/bind my-term-map "t" #'multi-vterm      "vterm")
(my/bind my-term-map "n" #'multi-vterm-next "vterm-next")
(my/bind my-term-map "P" #'multi-vterm-prev "vterm-prev")
```

`apps/dl-shpool.el` — shpool used to `(vterm buf-name)` then send
`exec shpool attach NAME\n` via `vterm-send-string` + `vterm-send-return`.
Mode checks were `'vterm-mode'`. Git history at this commit's parent has the
full pre-port version if needed.
