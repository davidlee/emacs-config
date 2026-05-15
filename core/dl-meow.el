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

(use-package meow
  :config
  (setq meow-mode-state-list
        (append meow-mode-state-list '((vterm-mode . insert))))
  (meow-setup)
  (meow-global-mode 1)
  (dl-meow--apply-indicator-faces)
  (add-hook 'enable-theme-functions #'dl-meow--apply-indicator-faces))

(defun my-disable-meow-in-terminal ()
  (when (or (derived-mode-p 'vterm-mode) (derived-mode-p 'ghostel-mode))
    (meow-mode -1)))

(add-hook 'ghostel-mode-hook #'my-disable-meow-in-terminal)
(add-hook 'vterm-mode-hook   #'my-disable-meow-in-terminal)

(provide 'dl-meow)
;;; dl-meow.el ends here
