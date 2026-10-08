;;; dl-keybind.el --- Ergonomic global chord bindings -*- lexical-binding: t; -*-


;; Personal command families live under C-c <letter> / SPC <letter>
;; (see dl-keymap.el).  This file holds bindings that don't fit a prefix:
;; ergonomic chord shortcuts, which-key, hydra, and runtime helpers.

(use-package windmove
  :ensure nil
  :bind (("C-M-<left>"  . windmove-left)
         ("C-M-<up>"    . windmove-up)
         ("C-M-<down>"  . windmove-down)
         ("C-M-<right>" . windmove-right)))

;; Keys without an owning `use-package' live here, as `bind-keys'
;; (KEYS.md R2), so `describe-personal-keybindings' lists them.

;; Tab chords: C-PgUp/PgDn walk tab-bar tabs (layouts), as in ghostty;
;; M-PgUp/PgDn and s-{ / s-} do too.  C-M-PgUp/PgDn walk this window's
;; tab-line (buffers).  Super+PgUp/PgDn belong to the compositor (umbriel
;; workspaces).  These shadow Emacs defaults:
;;   C-PgUp/PgDn  `scroll-right' / `scroll-left'          (still C-x > / C-x <)
;;   M-PgUp/PgDn  `scroll-other-window-down' / `-window' (still C-M-S-v / C-M-v)
;; ghostel lets them through via `ghostel-keymap-exceptions'
;; (apps/dl-ghostel.el).
(bind-keys
  ("C-<prior>"   . tab-bar-switch-to-prev-tab)
  ("C-<next>"    . tab-bar-switch-to-next-tab)
  ("M-<prior>"   . tab-bar-switch-to-prev-tab)
  ("M-<next>"    . tab-bar-switch-to-next-tab)
  ("C-M-<prior>" . tab-line-switch-to-prev-tab)
  ("C-M-<next>"  . tab-line-switch-to-next-tab)
  ("s-{"         . tab-bar-switch-to-prev-tab)
  ("s-}"         . tab-bar-switch-to-next-tab))

(bind-keys
  ("M-/"     . hippie-expand)
  ("C-;"     . iedit-mode)
  ("M-z"     . zap-up-to-char)
  ("M-Q"     . my/unfill-paragraph)     ; `dl-prose.el'
  ("C-x K"   . kill-current-buffer)
  ("C-x C-b" . ibuffer)
  ("C-x C-z" . zoom-window-zoom)
  ("C-x 2"   . split-and-follow-horizontally)
  ("C-x 3"   . split-and-follow-vertically)
  ;; Universal Emacs muscle memory for dired-jump; C-x C-n repurposed
  ;; from the dropped dired-sidebar binding to dirvish-side.
  ("C-x C-j" . dired-jump)
  ("C-x C-n" . dirvish-side)
  ("C-z"     . undo-fu-only-undo)
  ("C-S-z"   . undo-fu-only-redo)
  ("C-S-g"   . exit-minibuffer)
  ("C-s-<return>" . eshell-other-window)) ; `dl-term.el'

;; Org entry points: the reserved `C-c <letter>' singletons (KEYS.md).
(bind-keys
  ("C-c a" . org-agenda)
  ("C-c c" . org-capture)
  ("C-c l" . org-store-link))

(bind-keys :map comint-mode-map
  ("C-p" . comint-previous-input)
  ("C-n" . comint-next-input)
  ("C-w" . backward-kill-word))

;; Half-page scroll on the View bindings (emacs muscle-memory override).
(require 'view)
(bind-keys
  ("C-v" . View-scroll-half-page-forward)
  ("M-v" . View-scroll-half-page-backward))

;; Buffer-local text scaling, equivalent in spirit to C-scrollwheel.
;; `C-=' / `C--' belong to expreg (`dl-multi-edit.el'); zoom pairs the
;; shifted keys: `C-+' in, `C-_' out (`C-/' still undoes).
;; Global scaling: `global-text-scale-adjust' reads its direction from
;; the invoking key's last event (`-' out, `0' reset, else in).
(bind-keys
  ("C-+"   . text-scale-increase)
  ("C-_"   . text-scale-decrease)
  ("C-0"   . text-scale-adjust)
  ("C-M-=" . global-text-scale-adjust)
  ("C-M-+" . global-text-scale-adjust)
  ("C-M--" . global-text-scale-adjust)
  ("C-S-0" . global-text-scale-adjust))

;; Hydras for repeatable, sticky subinterfaces.  Eagerly loaded so
;; `defhydra' is in scope when downstream files (`dl-keymap.el')
;; reference the generated `…/body' entry points.
(use-package hydra
  :demand t
  :config
  (defhydra hydra-window-resize (:hint nil)
    "
Window resize: _<left>_/_<right>_ width  _<up>_/_<down>_ height  _=_ balance  _q_ quit"
    ("<left>"  shrink-window-horizontally)
    ("<right>" enlarge-window-horizontally)
    ("<up>"    enlarge-window)
    ("<down>"  shrink-window)
    ("="       balance-windows)
    ("q"       nil :exit t)))

(use-package which-key
  :ensure nil
  :custom
  (which-key-show-early-on-C-h t)
  (which-key-idle-delay 0.3) ; 1e6
  (which-key-idle-secondary-delay 0.05)
  :config
  (which-key-mode))

(defun my/keymap-bindings (keymap)
  "Return a list of bindings in KEYMAP."
  (let (bindings)
    (map-keymap
      (lambda (event binding)
        (push
          (cons
            (key-description (vector event))
            binding)
          bindings))
      keymap)
    (nreverse bindings)))


;; Discovery cheatsheet:
;;   C-h k        describe-key
;;   C-h b        describe-bindings
;;   C-h m        describe-mode
;;   C-h w        where-is
;;   C-h f        describe-function
;;   C-h v        describe-variable
;;   M-x describe-keymap
;;   M-x which-key-show-keymap
;;   M-x where-is

(require 'dl-buffer-management)

;; Function keys.  Fast journal capture: <f1> pops a small org buffer;
;; C-c C-c / C-RET appends a timestamped entry under today's `* Log'.
;; Help stays on C-h; C-<f1> is `popterm-toggle' (apps/dl-ghostel.el).
;;   f2 - view menu (needs work)    f3 - start macro
;;   f4 - end or call macro         f10 - collides w/ WM
(bind-keys
  ("<f1>"   . my/journal-quick-capture)
  ("C-<f2>" . my/ghostel-here)          ; `dl-term.el'
  ("<f5>"   . deadgrep)
  ("<f9>"   . toggle-maximize-buffer))

(provide 'dl-keybind)
;;; dl-keybind.el ends here
