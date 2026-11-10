;;; dl-gptel-macher.el --- macher workspace detection -*- lexical-binding: t; -*-

;;; Commentary:
;; $HOME is a dotfiles git repo.  project.el lists its untracked files
;; too (millions: package caches, app data), and macher builds that whole
;; list on every gptel send before trimming it to
;; `macher-context-string-max-files'.  So a buffer whose project is $HOME
;; (a gptel chat buffer in ~, say) gets no project workspace.

;;; Code:

(declare-function macher-workspace-project "macher")

(defun dl-gptel-macher-workspace-project ()
  "Like `macher-workspace-project', but never the $HOME repo."
  (require 'macher)
  (when-let* ((workspace (macher-workspace-project)))
    (unless (file-equal-p (cdr workspace) "~")
      workspace)))

(provide 'dl-gptel-macher)
;;; dl-gptel-macher.el ends here
