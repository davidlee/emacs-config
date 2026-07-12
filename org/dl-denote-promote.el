;;; dl-denote-promote.el --- Promote a subtree to a durable denote note -*- lexical-binding: t; -*-

;; One-keystroke promotion (SL-013): the subtree at point becomes a durable
;; denote note in a curated class dir, leaving a level-preserving stub heading
;; that links to the new note.  Wraps `denote-org-extract-org-subtree' rather
;; than reimplementing its title/keyword/date derivation.
;;
;; Bound to `C-c n p' in `core/dl-keymap.el'.

(require 'dl-notes-paths)

(use-package denote-org
  :commands (denote-org-extract-org-subtree))

(declare-function denote-org-extract-org-subtree "denote-org")
(declare-function denote-retrieve-filename-identifier "denote")
(declare-function denote-retrieve-front-matter-title-value "denote")
(declare-function denote-filetype-heuristics "denote")

(defvar my/denote-promote-targets
  (mapcar (lambda (dir)
            (cons (file-relative-name dir dl-notes-root) dir))
          (list dl-notes-slips-dir
                dl-notes-sources-dir
                dl-notes-references-dir
                dl-notes-projects-dir
                dl-notes-areas-dir
                dl-notes-work-slips-dir
                dl-notes-work-sources-dir
                dl-notes-work-references-dir
                dl-notes-work-projects-dir
                dl-notes-work-areas-dir))
  "Alist of (LABEL . DIR) promotion targets, labelled relative to the root.
Curated: durable class dirs only — journal/, weekly/, intake/ are not
promotion targets (design SL-013 D2).")

(defun my/denote-promote--stub (level id title)
  "Return a level-LEVEL org heading linking to denote note ID titled TITLE.
Left behind at the extraction site so the origin keeps provenance."
  (format "%s → %s"
          (make-string level ?*)
          (if (string-empty-p title)
              (format "[[denote:%s]]" id)
            (format "[[denote:%s][%s]]" id title))))

(provide 'dl-denote-promote)
;;; dl-denote-promote.el ends here
