;;; dl-magit.el --- magit config -*- lexical-binding: t; -*-

(use-package magit
  :bind (("C-x g" . magit-status)))

(use-package diff-hl
  :hook ((prog-mode text-mode) . diff-hl-mode)
  :config
  (require 'diff-hl-flydiff)
  (diff-hl-flydiff-mode))

(use-package git-modes)

(use-package transient :ensure t)

(provide 'dl-magit)
