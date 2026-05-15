;;; dl-meow.el --- Meow modal bindings -*- lexical-binding: t; -*-

(require 'dl-keymap)

(use-package meow
  :config
  (setq meow-mode-state-list
        (append meow-mode-state-list '((vterm-mode . insert))))
  (meow-setup)
  (meow-global-mode 1))

(defun my-disable-meow-in-terminal ()
  (when (or (derived-mode-p 'vterm-mode) (derived-mode-p 'ghostel-mode))
    (meow-mode -1)))

(add-hook 'ghostel-mode-hook #'my-disable-meow-in-terminal)
(add-hook 'vterm-mode-hook   #'my-disable-meow-in-terminal)

(provide 'dl-meow)
;;; dl-meow.el ends here
