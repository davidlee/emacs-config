;;; dl-denote-promote.el --- Promote a subtree to a durable denote note -*- lexical-binding: t; -*-

;; One-keystroke promotion (SL-013): the subtree at point becomes a durable
;; denote note in a curated class dir, leaving a level-preserving stub heading
;; that links to the new note.  Wraps `denote-org-extract-org-subtree' rather
;; than reimplementing its title/keyword/date derivation.
;;
;; Bound to `C-c n p' in `core/dl-keymap.el'.

(require 'dl-notes-paths)
(require 'org)

(use-package denote-org
  :commands (denote-org-extract-org-subtree))

(declare-function denote-org-extract-org-subtree "denote-org")
(declare-function denote-retrieve-filename-identifier "denote")

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

;;;###autoload
(defun my/denote-promote-subtree ()
  "Promote the Org subtree at point to a durable denote note.
Prompt for a curated class dir (`my/denote-promote-targets'), extract the
subtree into a new denote note there via `denote-org-extract-org-subtree',
save it, and leave a level-preserving stub heading at the origin linking the
new note.  Quitting the prompt aborts before any mutation, so the origin
buffer is left untouched."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not an Org buffer"))
  (when (org-before-first-heading-p)
    (user-error "Point is not within a subtree"))
  (let* ((targets my/denote-promote-targets)
         (label   (completing-read "Promote to: " targets nil t))
         (dir     (or (cdr (assoc label targets))
                      (user-error "No target directory for %S" label)))
         (origin  (current-buffer))
         (level   (org-current-level))
         (heading (org-get-heading t t t t))
         (marker  (copy-marker (org-entry-beginning-position))))
    ;; Extract leaves the new note buffer current, possibly unsaved
    ;; (`denote-save-buffers' defaults nil), so save it and read the ID from
    ;; its filename — the title comes from the pre-call HEADING, not disk.
    (let* ((note-buffer
            (let ((denote-prompts nil)
                  (denote-directory dir))
              (denote-org-extract-org-subtree)
              (current-buffer)))
           (id (denote-retrieve-filename-identifier
                (buffer-file-name note-buffer))))
      (with-current-buffer note-buffer
        (save-buffer))
      (with-current-buffer origin
        (goto-char marker)
        (insert (my/denote-promote--stub level id heading) "\n"))
      (set-marker marker nil)
      (switch-to-buffer origin))))

(provide 'dl-denote-promote)
;;; dl-denote-promote.el ends here
