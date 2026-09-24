;;; dl-magit.el --- magit config -*- lexical-binding: t; -*-

(declare-function ws-butler-mode "ws-butler")

(defun my/git-commit-disable-ws-butler ()
  "Keep trailing whitespace in commit-message buffers as the user typed it."
  (ws-butler-mode -1))

;; Commit buffers need all of magit loaded, not just `git-commit':
;; `magit-commit' installs the hooks that show the diff and defines
;; `magit-commit-message-buffer' (used by C-c C-d).  magit only arms
;; commit-buffer setup once loaded, so load it on idle rather than
;; waiting for `magit-status' -- otherwise a `git commit' from a
;; terminal (emacsclient as $EDITOR) gets a half-loaded buffer.
(use-package magit
  :defer 1
  :bind (("C-x g" . magit-status))
  :hook (git-commit-mode . my/git-commit-disable-ws-butler))

;; (use-package diff-hl
;;   :hook ((prog-mode text-mode) . diff-hl-mode)
;;   :config
;;   (require 'diff-hl-flydiff)
;;   (diff-hl-flydiff-mode))

(use-package git-modes
  :defer t)

(use-package ediff
  :defer t
  :custom
  (ediff-diff-options "")
  (ediff-custom-diff-options "-u")
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  (ediff-split-window-function #'split-window-vertically))

(provide 'dl-magit)
