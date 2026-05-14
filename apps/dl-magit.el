;;; dl-magit.el --- magit config -*- lexical-binding: t; -*-

(use-package magit
  :bind (("C-x g" . magit-status)))

(use-package diff-hl
  :hook ((prog-mode text-mode) . diff-hl-mode)
  :config
  (require 'diff-hl-flydiff)
  (diff-hl-flydiff-mode))

(use-package git-modes)

(use-package transient)

;; get diff mode for commits
(use-package git-commit
  :ensure nil
  :mode ("/COMMIT_EDITMSG\\'" . git-commit-mode))

;; (setq ediff-diff-options "")
;; (setq ediff-custom-diff-options "-u")
;; (setq ediff-window-setup-function 'ediff-setup-windows-plain)
;; (setq ediff-split-window-function 'split-window-vertically)

(provide 'dl-magit)
