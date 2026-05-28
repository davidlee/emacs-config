;;; dl-keybind.el --- Ergonomic global chord bindings -*- lexical-binding: t; -*-


;; Personal command families live under C-c <letter> / SPC <letter>
;; (see dl-keymap.el).  This file holds bindings that don't fit a prefix:
;; ergonomic chord shortcuts, which-key, hydra, and runtime helpers.

(use-package windmove
  :ensure nil
  :config
  (global-set-key (kbd "C-s-<left>")  #'windmove-left)
  (global-set-key (kbd "C-s-<right>") #'windmove-right)
  (global-set-key (kbd "C-s-<up>")    #'windmove-up)
  (global-set-key (kbd "C-s-<down>")  #'windmove-down))

;; Tab-bar + buffer chords.
(keymap-global-set "s-<prior>"   'tab-bar-switch-to-next-tab)
(keymap-global-set "s-<next>"    'tab-bar-switch-to-prev-tab)
(keymap-global-set "M-s-<prior>" 'switch-to-next-buffer)
(keymap-global-set "M-s-<next>"  'switch-to-prev-buffer)

(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "M-z") 'zap-up-to-char)
(global-set-key (kbd "C-x K") 'kill-current-buffer)
(global-set-key (kbd "C-x C-b") 'ibuffer)
(global-set-key (kbd "C-x C-z") 'zoom-window-zoom)

(define-key comint-mode-map (kbd "C-p") #'comint-previous-input)
(define-key comint-mode-map (kbd "C-n") #'comint-next-input)
(define-key comint-mode-map (kbd "C-w") #'backward-kill-word)

(global-set-key (kbd "C-x 2") 'split-and-follow-horizontally)
(global-set-key (kbd "C-x 3") 'split-and-follow-vertically)

;; Half-page scroll on the View bindings (emacs muscle-memory override).
(require 'view)
(global-set-key (kbd "C-v") #'View-scroll-half-page-forward)
(global-set-key (kbd "M-v") #'View-scroll-half-page-backward)

;; Buffer-local text scaling, equivalent in spirit to C-scrollwheel.
(global-set-key (kbd "C-=") #'text-scale-increase)
(global-set-key (kbd "C-+") #'text-scale-increase)
(global-set-key (kbd "C--") #'text-scale-decrease)
(global-set-key (kbd "C-0") #'text-scale-adjust)

(require 'dl-global-text-scale)
(global-set-key (kbd "C-M-=") #'my/global-text-scale-increase)
(global-set-key (kbd "C-M-+") #'my/global-text-scale-increase)
(global-set-key (kbd "C-M--") #'my/global-text-scale-increase)
(global-set-key (kbd "C-S-0") #'my/global-text-scale-reset)


(global-unset-key (kbd "C-z"))
(global-set-key (kbd "C-z")   'undo-fu-only-undo)
(global-set-key (kbd "C-S-z") 'undo-fu-only-redo)

(global-set-key (kbd "C-S-g") #'exit-minibuffer)

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
  (prefix-help-command #'embark-prefix-help-command)
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
;; Bind it to a key (example: F9)
(global-set-key (kbd "<f9>") 'toggle-maximize-buffer)

;; Fast journal capture: <f1> pops a small org buffer; C-c C-c / C-RET
;; appends a timestamped entry under today's `* Log'.  `help-command'
;; relocates to C-<f1> (C-h remains the primary help prefix).
(global-set-key (kbd "<f1>")   #'my/journal-quick-capture)
(global-set-key (kbd "C-<f1>") 'help-command)


(provide 'dl-keybind)
;;; dl-keybind.el ends here
