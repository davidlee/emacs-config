;;; dl-meow.el --- Meow modal bindings -*- lexical-binding: t; -*-

(require 'dl-keymap)

(defun dl-meow--apply-indicator-faces (&rest _)
  "Paint meow state indicators as coloured blocks.
Re-applied after theme load so rotating themes can't clobber them."
  (pcase-dolist (`(,face ,bg) '((meow-normal-indicator "#a6e3a1")
                                (meow-insert-indicator "#f38ba8")
                                (meow-motion-indicator "#89b4fa")
                                (meow-keypad-indicator "#f9e2af")
                                (meow-beacon-indicator "#cba6f7")))
    (set-face-attribute face nil
                        :background bg :foreground "black" :weight 'bold)))

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
  (meow-global-mode 1)
  (dl-meow--apply-indicator-faces)
  (add-hook 'enable-theme-functions #'dl-meow--apply-indicator-faces))

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
