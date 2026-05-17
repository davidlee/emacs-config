;;; dl-denote-templates.el --- Class constructors for Denote notes -*- lexical-binding: t; -*-

;; Per-class wrappers around `denote' that home each new note under the
;; right subdirectory (`dl-notes-{projects,areas,sources,slips,
;; references,indexes}-dir') and stamp a class keyword on the filename so
;; the class is encoded twice — by location *and* by tag — for fast
;; downstream filtering (org-ql / consult-notes / agenda regexes).
;;
;; UX matches plain `M-x denote': prompt for title, then prompt for
;; extra keywords (comma-separated).  The class tag is prepended
;; automatically.

(require 'dl-notes-paths)
(require 'denote)

(defun my/denote--new (class subdir)
  "Create a Denote note tagged CLASS under SUBDIR.
Prompts for title and extra keywords; CLASS is always added as the
first keyword."
  (let* ((title    (denote-title-prompt nil (format "New %s title" class)))
         (extra    (denote-keywords-prompt (format "Extra keywords for %s" class)))
         (keywords (cons class extra)))
    (denote title keywords nil subdir)))

(defun my/denote-new-project ()
  "Create a new `project' note under `dl-notes-projects-dir'."
  (interactive)
  (my/denote--new "project" dl-notes-projects-dir))

(defun my/denote-new-area ()
  "Create a new `area' note under `dl-notes-areas-dir'."
  (interactive)
  (my/denote--new "area" dl-notes-areas-dir))

(defun my/denote-new-source ()
  "Create a new `source' note under `dl-notes-sources-dir'."
  (interactive)
  (my/denote--new "source" dl-notes-sources-dir))

(defun my/denote-new-slip ()
  "Create a new `slip' note under `dl-notes-slips-dir'."
  (interactive)
  (my/denote--new "slip" dl-notes-slips-dir))

(defun my/denote-new-reference ()
  "Create a new `reference' note under `dl-notes-references-dir'."
  (interactive)
  (my/denote--new "reference" dl-notes-references-dir))

(defun my/denote-new-index ()
  "Create a new `index' note under `dl-notes-indexes-dir'."
  (interactive)
  (my/denote--new "index" dl-notes-indexes-dir))

(provide 'dl-denote-templates)
;;; dl-denote-templates.el ends here
