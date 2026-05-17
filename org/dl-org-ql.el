;;; dl-org-ql.el --- org-ql install + autoloaded entry-point -*- lexical-binding: t; -*-

;; `org-ql' is the query layer used by the Phase 6 review module
;; (`dl-review.el') for inbox/intake/weekly sweeps and stale-item
;; queries.  Defer concrete saved-search/dashboard commands to that
;; module — phase 5 just installs the package so `C-c n q'
;; (`org-ql-find', bound in `core/dl-keymap.el') resolves.

(require 'dl-notes-paths)

(use-package org-ql
  :commands (org-ql-find org-ql-search org-ql-view))

(defun my/org-ql-find-here ()
  "Run `org-ql-find' against the current buffer only.
File-scoped counterpart to corpus-wide `org-ql-find' bound at C-c n q."
  (interactive)
  (org-ql-find (list (current-buffer))))

(provide 'dl-org-ql)
;;; dl-org-ql.el ends here
