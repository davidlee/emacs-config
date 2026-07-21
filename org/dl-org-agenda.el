;;; dl-org-agenda.el --- Org agenda files and commands -*- lexical-binding: t; -*-

;; Three agenda scopes — personal, work, combined — selected per
;; invocation via `org-agenda-custom-commands' rather than by mutating
;; `org-agenda-files'.  Boundary is by directory custody, not tag.
;;
;;   C-c a a   default dispatcher (combined union)
;;   C-c a p   personal-only
;;   C-c a w   work-only
;;   C-c a c   combined (explicit)
;;
;; `org-agenda-files' is set to the combined union at load time so the
;; default `C-c a a' dispatcher and any third-party code that consults
;; the variable see every operational file.
;;
;; Cross-boundary: personal notes tagged `:work-relevant:' are *not*
;; pulled into the work scope automatically — opt in by appending a
;; filtered file list to `my/org-agenda-work-files' when that pattern
;; earns its keep.
;;
;; Excluded by design (mirrors the existing personal exclusion):
;;   areas/, indexes/, references/, sources/, slips/, archive/,
;;   attachments/, intake/  (and their work/ counterparts)

(require 'dl-notes-paths)

(defvar my/org-agenda-personal-files nil
  "Operational personal Org files for agenda commands.
Recomputed by `my/org-agenda-refresh-files'.")

(defvar my/org-agenda-work-files nil
  "Operational work Org files for agenda commands.
Recomputed by `my/org-agenda-refresh-files'.")

(defvar my/org-agenda-combined-files nil
  "Union of personal + work agenda files.
Recomputed by `my/org-agenda-refresh-files'.")

(defun my/org-agenda-refresh-files ()
  "Recompute agenda file lists from the notes corpus.
Call after adding new notes if you don't want to wait for the next
restart.  Idempotent."
  (interactive)
  (cl-flet ((orgs (dir) (and (file-directory-p dir)
                             (directory-files-recursively dir "\\.org\\'"))))
    (setq my/org-agenda-personal-files
          (append (list dl-notes-inbox-file)
                  (orgs dl-notes-journal-dir)
                  (orgs dl-notes-weekly-dir)
                  (orgs dl-notes-projects-dir)))
    (setq my/org-agenda-work-files
          (append (list dl-notes-work-inbox-file)
                  (orgs dl-notes-work-journal-dir)
                  (orgs dl-notes-work-weekly-dir)
                  (orgs dl-notes-work-projects-dir)
                  (orgs dl-notes-work-meetings-dir)
                  (orgs dl-notes-work-people-dir)))
    (setq my/org-agenda-combined-files
          (append my/org-agenda-personal-files
                  my/org-agenda-work-files))
    (setq org-agenda-files my/org-agenda-combined-files)))

(my/org-agenda-refresh-files)

;; The list above is a load-time snapshot of the notes tree.  Denote
;; mints a fresh journal file each day, so by the time you open the
;; agenda or org-timeblock the snapshot is stale and today's file is
;; absent — the view silently shows nothing for today.  Refresh before
;; the entry points that consult `org-agenda-files' (the walk over the
;; operational notes dirs is sub-second and idempotent).
(defun my/org-agenda--refresh-advice (&rest _)
  "Recompute agenda file lists before an agenda/timeblock view opens."
  (my/org-agenda-refresh-files))

(dolist (fn '(org-agenda org-timeblock org-timeblock-list))
  (advice-add fn :before #'my/org-agenda--refresh-advice))

(setq org-agenda-custom-commands
  '(("p" "Personal agenda"
      ((agenda "")
        (todo "NEXT")
        (todo "STARTED")
        (todo "WAITING"))
      ((org-agenda-files my/org-agenda-personal-files)))

     ("w" "Work agenda"
       ((agenda "")
         (todo "NEXT")
         (todo "STARTED")
         (todo "WAITING"))
       ((org-agenda-files my/org-agenda-work-files)))

     ("c" "Combined agenda"
       ((agenda "")
         (todo "NEXT")
         (todo "STARTED")
         (todo "WAITING"))
       ((org-agenda-files my/org-agenda-combined-files)))))

(global-set-key (kbd "C-c a") #'org-agenda)

(provide 'dl-org-agenda)
;;; dl-org-agenda.el ends here
