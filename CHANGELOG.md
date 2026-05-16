# Changelog

Notable changes to this Emacs config. Loosely dated; not versioned.

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
