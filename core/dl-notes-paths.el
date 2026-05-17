;;; dl-notes-paths.el --- Notes paths and directory constants -*- lexical-binding: t; -*-

;; Single source of truth for where the notes corpus lives.
;; Required early (before dl-org and friends) so downstream modules
;; can derive their paths from these constants instead of re-expanding
;; "~/notes" everywhere.

(defconst dl-notes-root (expand-file-name "~/notes")
  "Root of the notes corpus.")

(defun my/notes-path (&rest segments)
  "Return SEGMENTS joined under `dl-notes-root'."
  (apply #'expand-file-name
         (mapconcat #'identity segments "/")
         (list dl-notes-root)))

(defconst dl-notes-inbox-file       (my/notes-path "inbox.org"))
(defconst dl-notes-intake-dir       (my/notes-path "intake"))
(defconst dl-notes-journal-dir      (my/notes-path "journal"))
(defconst dl-notes-weekly-dir       (my/notes-path "weekly"))
(defconst dl-notes-projects-dir     (my/notes-path "projects"))
(defconst dl-notes-areas-dir        (my/notes-path "areas"))
(defconst dl-notes-sources-dir      (my/notes-path "sources"))
(defconst dl-notes-slips-dir        (my/notes-path "slips"))
(defconst dl-notes-indexes-dir      (my/notes-path "indexes"))
(defconst dl-notes-references-dir   (my/notes-path "references"))
(defconst dl-notes-attachments-dir  (my/notes-path "attachments"))
(defconst dl-notes-archive-dir      (my/notes-path "archive"))

(provide 'dl-notes-paths)
;;; dl-notes-paths.el ends here
