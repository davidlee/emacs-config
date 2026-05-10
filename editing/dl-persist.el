;;; dl-persist.el --- Emacs Lisp editing setup -*- lexical-binding: t; -*-

(add-hook 'before-save-hook 'eglot-format-buffer)

(use-package recentf
  :init
  (recentf-mode 1)
  :custom
  (recentf-max-saved-items 200))

(use-package saveplace
  :init
  (save-place-mode 1))

(use-package undo-fu)

(use-package undo-fu-session
  :config
  (undo-fu-session-global-mode))

(use-package vundo
  :bind (("C-x u" . vundo)))

(provide 'dl-persist)
