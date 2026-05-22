;;; dl-denote-templates.el --- Class constructors for Denote notes -*- lexical-binding: t; -*-

;; Per-class wrappers around `denote' that home each new note under the
;; right subdirectory (`dl-notes-{projects,areas,sources,slips,
;; references,indexes}-dir' for personal, `dl-notes-work-*-dir' for
;; work) and stamp class keyword(s) on the filename so the class is
;; encoded twice — by location *and* by tag — for fast downstream
;; filtering (org-ql / consult-notes / agenda regexes).
;;
;; Work constructors prepend two keywords (`work' + class), so a
;; meeting note ends up with `:work:meeting:' in `#+filetags:'.
;;
;; UX matches plain `M-x denote': prompt for title, then prompt for
;; extra keywords (comma-separated).  Class keywords are prepended
;; automatically.

(require 'dl-notes-paths)
(require 'denote)

(defun my/denote--new (class-or-classes subdir &optional file-type)
  "Create a Denote note tagged CLASS-OR-CLASSES under SUBDIR.
CLASS-OR-CLASSES is a single class string or a list of class strings;
in either case the class keyword(s) are prepended to the user's extras.
FILE-TYPE, when non-nil, overrides `denote-file-type' (e.g. `markdown-yaml')."
  (let* ((base     (if (listp class-or-classes) class-or-classes
                     (list class-or-classes)))
         (label    (mapconcat #'identity base "/"))
         (title    (denote-title-prompt nil (format "New %s title" label)))
         (extra    (denote-keywords-prompt (format "Extra keywords for %s" label)))
         (keywords (append base extra)))
    (denote title keywords file-type subdir)))

;; Personal class constructors.

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

(defun my/denote-new-reference-markdown ()
  "Create a new markdown `reference' note under `dl-notes-references-dir'.
Filename and YAML front matter follow Denote conventions so the file is
indexed and rename/retag commands work in-place."
  (interactive)
  (my/denote--new "reference" dl-notes-references-dir 'markdown-yaml))

(defun my/denote-new-index ()
  "Create a new `index' note under `dl-notes-indexes-dir'."
  (interactive)
  (my/denote--new "index" dl-notes-indexes-dir))

;; Work class constructors — two keywords (`work' + class), under
;; `dl-notes-work-*-dir'.

(defun my/denote-new-work-project ()
  "Create a new `work/project' note under `dl-notes-work-projects-dir'."
  (interactive)
  (my/denote--new '("work" "project") dl-notes-work-projects-dir))

(defun my/denote-new-work-area ()
  "Create a new `work/area' note under `dl-notes-work-areas-dir'."
  (interactive)
  (my/denote--new '("work" "area") dl-notes-work-areas-dir))

(defun my/denote-new-work-source ()
  "Create a new `work/source' note under `dl-notes-work-sources-dir'."
  (interactive)
  (my/denote--new '("work" "source") dl-notes-work-sources-dir))

(defun my/denote-new-work-slip ()
  "Create a new `work/slip' note under `dl-notes-work-slips-dir'."
  (interactive)
  (my/denote--new '("work" "slip") dl-notes-work-slips-dir))

(defun my/denote-new-work-reference ()
  "Create a new `work/reference' note under `dl-notes-work-references-dir'."
  (interactive)
  (my/denote--new '("work" "reference") dl-notes-work-references-dir))

(defun my/denote-new-work-index ()
  "Create a new `work/index' note under `dl-notes-work-indexes-dir'."
  (interactive)
  (my/denote--new '("work" "index") dl-notes-work-indexes-dir))

(defun my/denote-new-work-meeting ()
  "Create a new `work/meeting' note under `dl-notes-work-meetings-dir'."
  (interactive)
  (my/denote--new '("work" "meeting") dl-notes-work-meetings-dir))

(defun my/denote-new-work-person ()
  "Create a new `work/person' note under `dl-notes-work-people-dir'."
  (interactive)
  (my/denote--new '("work" "person") dl-notes-work-people-dir))

(provide 'dl-denote-templates)
;;; dl-denote-templates.el ends here
