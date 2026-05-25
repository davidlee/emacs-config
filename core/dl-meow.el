;;; dl-meow.el --- Meow modal bindings -*- lexical-binding: t; -*-

(require 'dl-keymap)

;; Meow indicator face attrs live in `core/dl-faces.el' (with
;; `enable-theme-functions' wiring) — single source of truth for face
;; customization in this config.

(defface dl-meow-indicator-inactive
  '((t (:background "#45475a" :foreground "#7f849c" :weight bold)))
  "Face for the meow state indicator in inactive modelines.")

(defun dl-meow-indicator ()
  "Wrap `meow-indicator', greying it out in inactive modelines.
Mode-line `:eval' forms run with `selected-window' bound to the window
being drawn; lambda-line caches the truly active one in
`lambda-line--selected-window'. Mismatch ⇒ inactive."
  (let ((s (meow-indicator)))
    (if (and (stringp s)
          (not (string-empty-p s))
          (boundp 'lambda-line--selected-window)
          (not (eq (selected-window) lambda-line--selected-window)))
      (propertize (substring-no-properties s)
        'face 'dl-meow-indicator-inactive)
      s)))

(use-package meow
  :custom
  (meow-use-cursor-position-hack t)
  (meow-use-clipboard t)
  (meow-goto-line-function 'consult-goto-line)
  :config
  (setq meow--kbd-delete-char "<deletechar>")
  (meow-thing-register 'angle '(regexp "<" ">") '(regexp "<" ">"))
  (add-to-list 'meow-char-thing-table '(?a . angle))
  (meow-setup)
  (meow-global-mode 1))

(use-package repeat-fu
  :ensure nil
  :vc (:url "https://codeberg.org/ideasman42/emacs-repeat-fu.git")
  :commands (repeat-fu-mode repeat-fu-execute)
  :config
  (setq repeat-fu-preset 'meow)
  :hook
  ((meow-mode)
    .
    (lambda ()
      (when (and (not (minibufferp)) (not (derived-mode-p 'special-mode)))
        (repeat-fu-mode)
        (define-key meow-normal-state-keymap (kbd "C-\\") 'repeat-fu-execute)
        (define-key meow-insert-state-keymap (kbd "C-\\") 'repeat-fu-execute)))))


;; Terminals: disable meow entirely (cleaner than `insert' state — also
;; removes the indicator / cursor face).  `derived-mode-p' catches any
;; subclass of vterm-mode / ghostel-mode too.
(defun dl-meow--disable-in-terminals ()
  (when (or (derived-mode-p 'vterm-mode) (derived-mode-p 'ghostel-mode))
    (meow-mode -1)))

(add-hook 'ghostel-mode-hook #'dl-meow--disable-in-terminals)
(add-hook 'vterm-mode-hook   #'dl-meow--disable-in-terminals)

(provide 'dl-meow)
;;; dl-meow.el ends here
