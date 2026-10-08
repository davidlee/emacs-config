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

(use-package diff-hl
  :hook ((dired-mode . diff-hl-dired-mode)
          ((prog-mode text-mode) . diff-hl-mode))
  :config
  (global-diff-hl-mode 1)
  (diff-hl-flydiff-mode 1)
  (unless (display-graphic-p)
    (diff-hl-margin-mode 1)))

(use-package git-modes
  :defer t)

(use-package ediff
  :defer t
  :custom
  (ediff-diff-options "")
  (ediff-custom-diff-options "-u")
  (ediff-window-setup-function #'ediff-setup-windows-plain)
  (ediff-split-window-function #'split-window-horizontally)
  :config
  ;; Magit restores its own layout (it clears `ediff-quit-hook' locally);
  ;; these cover plain `ediff-*' sessions.  Append, so the restore runs
  ;; after ediff's own window cleanup rather than being undone by it.
  (add-hook 'ediff-before-setup-hook #'dl-magit--ediff-save-winconf)
  (add-hook 'ediff-quit-hook #'dl-magit--ediff-restore-winconf 90)
  (add-hook 'ediff-suspend-hook #'dl-magit--ediff-restore-winconf 90))

(defvar dl-magit--ediff-winconf nil
  "Window configuration saved before the current ediff session.")

(defun dl-magit--ediff-save-winconf ()
  "Save the window configuration ediff is about to replace."
  (setq dl-magit--ediff-winconf (current-window-configuration)))

(defun dl-magit--ediff-restore-winconf ()
  "Restore the window configuration saved before ediff started."
  (when dl-magit--ediff-winconf
    (set-window-configuration dl-magit--ediff-winconf)))

(provide 'dl-magit)
