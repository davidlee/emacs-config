;;; dl-notes-paths.el --- Notes paths and directory constants -*- lexical-binding: t; -*-

;; Single source of truth for where the notes corpus lives.
;; Required early (before dl-org and friends) so downstream modules
;; can derive their paths from these constants instead of re-expanding
;; "~/notes" everywhere.
;;
;; Layout — see NOTES.md for the architecture:
;;
;;   ~/notes/                  personal corpus root
;;     {inbox.org,intake,journal,weekly,projects,areas,sources,slips,
;;      references,indexes,attachments,archive}/
;;     work.org                work dashboard (curated; not a sink)
;;     work/                   work compartment (mirrors the class taxonomy
;;                             + meetings/ + people/)

(defconst dl-notes-root (expand-file-name "~/notes")
  "Root of the notes corpus.")

(defun my/notes-path (&rest segments)
  "Return SEGMENTS joined under `dl-notes-root'."
  (apply #'expand-file-name
         (mapconcat #'identity segments "/")
         (list dl-notes-root)))

;; Personal compartment.
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

;; Work compartment.
(defconst dl-notes-work-file              (my/notes-path "work.org"))
(defconst dl-notes-work-dir               (my/notes-path "work"))
(defconst dl-notes-work-inbox-file        (expand-file-name "inbox.org"   dl-notes-work-dir))
(defconst dl-notes-work-intake-dir        (expand-file-name "intake"      dl-notes-work-dir))
(defconst dl-notes-work-journal-dir       (expand-file-name "journal"     dl-notes-work-dir))
(defconst dl-notes-work-weekly-dir        (expand-file-name "weekly"      dl-notes-work-dir))
(defconst dl-notes-work-meetings-dir      (expand-file-name "meetings"    dl-notes-work-dir))
(defconst dl-notes-work-people-dir        (expand-file-name "people"      dl-notes-work-dir))
(defconst dl-notes-work-projects-dir      (expand-file-name "projects"    dl-notes-work-dir))
(defconst dl-notes-work-areas-dir         (expand-file-name "areas"       dl-notes-work-dir))
(defconst dl-notes-work-sources-dir       (expand-file-name "sources"     dl-notes-work-dir))
(defconst dl-notes-work-references-dir    (expand-file-name "references"  dl-notes-work-dir))
(defconst dl-notes-work-slips-dir         (expand-file-name "slips"       dl-notes-work-dir))
(defconst dl-notes-work-indexes-dir       (expand-file-name "indexes"     dl-notes-work-dir))
(defconst dl-notes-work-attachments-dir   (expand-file-name "attachments" dl-notes-work-dir))
(defconst dl-notes-work-archive-dir       (expand-file-name "archive"     dl-notes-work-dir))

(defun my/notes-ensure-dirs ()
  "Create any missing notes directories.  Idempotent; safe at load time."
  (interactive)
  (dolist (dir (list dl-notes-intake-dir dl-notes-journal-dir
                     dl-notes-weekly-dir dl-notes-projects-dir
                     dl-notes-areas-dir dl-notes-sources-dir
                     dl-notes-slips-dir dl-notes-indexes-dir
                     dl-notes-references-dir dl-notes-attachments-dir
                     dl-notes-archive-dir
                     dl-notes-work-dir dl-notes-work-intake-dir
                     dl-notes-work-journal-dir dl-notes-work-weekly-dir
                     dl-notes-work-meetings-dir dl-notes-work-people-dir
                     dl-notes-work-projects-dir dl-notes-work-areas-dir
                     dl-notes-work-sources-dir dl-notes-work-references-dir
                     dl-notes-work-slips-dir dl-notes-work-indexes-dir
                     dl-notes-work-attachments-dir dl-notes-work-archive-dir))
    (unless (file-directory-p dir)
      (make-directory dir t))))

(my/notes-ensure-dirs)

(provide 'dl-notes-paths)
;;; dl-notes-paths.el ends here
