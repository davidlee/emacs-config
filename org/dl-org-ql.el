;;; dl-org-ql.el --- org-ql install + notes-scoped entry points -*- lexical-binding: t; -*-

;; `org-ql' queries Org headings.  Its own commands scope to the current
;; buffer (`org-ql-find') or prompt for a scope (`org-ql-search'), so
;; the notes commands here fix the scope to a compartment of the corpus:
;;
;;   C-c n q    my/org-ql-find-notes        jump to a heading, personal notes
;;   C-c n Q    my/org-ql-search-notes      results buffer, personal notes
;;   C-c n V    org-ql-view                 saved views (`org-ql-views')
;;   C-c n W q  my/org-ql-find-work-notes   jump to a heading, work notes
;;   C-c o q    my/org-ql-find-here         jump to a heading, this buffer
;;
;; The review module (`dl-review.el') also builds its reports on org-ql.

(require 'dl-notes-paths)

(use-package org-ql
  :commands (org-ql-find org-ql-search org-ql-view))

(defvar my/org-ql-search-history nil
  "Queries entered at `my/org-ql-search-notes'.")

(defun my/org-ql--personal-files ()
  "Org files in the personal compartment: the notes outside work/."
  (dl-notes-org-files dl-notes-root dl-notes-work-dir))

(defun my/org-ql-find-notes ()
  "Jump to a heading anywhere in the personal notes."
  (interactive)
  (org-ql-find (my/org-ql--personal-files)))

(defun my/org-ql-find-work-notes ()
  "Jump to a heading anywhere in the work notes."
  (interactive)
  (org-ql-find (dl-notes-org-files dl-notes-work-dir)))

(defun my/org-ql-search-notes (query)
  "Show the personal-notes headings matching QUERY in a results buffer.
QUERY is a plain or sexp org-ql query."
  (interactive (list (read-string "Query: " nil 'my/org-ql-search-history)))
  (org-ql-search (my/org-ql--personal-files) query :title "Personal notes"))

(defun my/org-ql-find-here ()
  "Jump to a heading in the current buffer."
  (interactive)
  (org-ql-find (list (current-buffer))))

(provide 'dl-org-ql)
;;; dl-org-ql.el ends here
