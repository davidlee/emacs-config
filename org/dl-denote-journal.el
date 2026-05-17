;;; dl-denote-journal.el --- Daily / weekly journal notes (Denote-named) -*- lexical-binding: t; -*-

;; Roll-own journal helpers: denote 4.1.3 ships without the
;; `denote-journal' submodule (it was split off in 4.x).  These functions
;; produce filenames in the Denote convention so they sort and search
;; alongside everything else under `dl-notes-root'.
;;
;; Personal:
;;   Daily:  journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org
;;   Weekly: weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org
;;
;; Work:
;;   Daily:  work/journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__work_journal.org
;;   Weekly: work/weekly/<monday-id>--YYYY-w<NN>__work_weekly_journal.org
;;
;; All variants share `my/journal--today-file', `my/journal--week-file',
;; `my/journal--day-skeleton', `my/journal--week-skeleton' parameterised
;; by directory, suffix, and filetags.  The 0-arg `*-ensure-today'
;; functions are stable entry points the capture templates can name.

(require 'dl-notes-paths)

(defun my/journal--iso-monday (time)
  "Return TIME shifted back to the Monday of its ISO week."
  (let ((dow (string-to-number (format-time-string "%u" time))))
    (time-subtract time (days-to-time (1- dow)))))

(defun my/journal--today-file (dir suffix)
  "Return today's Denote-named journal file path under DIR with SUFFIX.
SUFFIX is the bit between `__' and `.org', e.g. \"journal\" or \"work_journal\"."
  (let* ((now  (current-time))
         (id   (format-time-string "%Y%m%dT000000" now))
         (slug (downcase (format-time-string "%Y-%m-%d-%A" now))))
    (expand-file-name
     (format "%s--%s__%s.org" id slug suffix)
     dir)))

(defun my/journal--week-file (dir suffix)
  "Return this week's Denote-named weekly file path under DIR with SUFFIX.
Identifier is anchored on the ISO-week Monday."
  (let* ((monday (my/journal--iso-monday (current-time)))
         (id     (format-time-string "%Y%m%dT000000" monday))
         (slug   (downcase (format-time-string "%Y-w%V" monday))))
    (expand-file-name
     (format "%s--%s__%s.org" id slug suffix)
     dir)))

(defun my/journal--day-skeleton (tags)
  "Return the skeleton string for a newly-created daily journal file.
TAGS is the `#+filetags:' line value (e.g. \":journal:\")."
  (let ((now (current-time)))
    (concat "#+title:    " (format-time-string "%Y-%m-%d %A" now) "\n"
            "#+filetags: " tags "\n"
            "#+date:     " (format-time-string "[%Y-%m-%d %a]" now) "\n\n"
            "* Focus\n\n* Notes\n\n* Log\n")))

(defun my/journal--week-skeleton (tags)
  "Return the skeleton string for a newly-created weekly journal file.
TAGS is the `#+filetags:' line value (e.g. \":weekly:journal:\")."
  (let ((monday (my/journal--iso-monday (current-time))))
    (concat "#+title:    " (format-time-string "Week %G-W%V" monday) "\n"
            "#+filetags: " tags "\n"
            "#+date:     " (format-time-string "[%Y-%m-%d %a]" monday) "\n\n"
            "* Review\n\n* Projects\n\n* Notes promoted\n\n* Next week\n")))

(defun my/journal--ensure-file (file skeleton)
  "Ensure FILE exists with SKELETON contents; return its path."
  (unless (file-exists-p file)
    (with-temp-buffer
      (insert skeleton)
      (write-region (point-min) (point-max) file)))
  file)

(defun my/journal--open (file skeleton)
  "Open FILE; if empty, insert SKELETON."
  (find-file file)
  (when (= (point-max) 1)
    (insert skeleton)))

;; Personal entry points.

(defun my/journal--ensure-today ()
  "Ensure today's personal journal exists; return its path.
Stable 0-arg entry point for the `j' capture template."
  (my/journal--ensure-file
   (my/journal--today-file dl-notes-journal-dir "journal")
   (my/journal--day-skeleton ":journal:")))

(defun my/journal-note ()
  "Open or create today's Denote-named personal daily journal note."
  (interactive)
  (my/journal--open
   (my/journal--today-file dl-notes-journal-dir "journal")
   (my/journal--day-skeleton ":journal:")))

(defun my/weekly-note ()
  "Open or create this week's Denote-named personal weekly journal note."
  (interactive)
  (my/journal--open
   (my/journal--week-file dl-notes-weekly-dir "weekly_journal")
   (my/journal--week-skeleton ":weekly:journal:")))

;; Work entry points.

(defun my/work-journal--ensure-today ()
  "Ensure today's work journal exists; return its path.
Stable 0-arg entry point for the `w j' capture template."
  (my/journal--ensure-file
   (my/journal--today-file dl-notes-work-journal-dir "work_journal")
   (my/journal--day-skeleton ":work:journal:")))

(defun my/work-journal-note ()
  "Open or create today's Denote-named work daily journal note."
  (interactive)
  (my/journal--open
   (my/journal--today-file dl-notes-work-journal-dir "work_journal")
   (my/journal--day-skeleton ":work:journal:")))

(defun my/work-weekly-note ()
  "Open or create this week's Denote-named work weekly journal note."
  (interactive)
  (my/journal--open
   (my/journal--week-file dl-notes-work-weekly-dir "work_weekly_journal")
   (my/journal--week-skeleton ":work:weekly:journal:")))

;; Bindings (`C-c n j', `C-c n w', `C-c n W j', `C-c n W w', etc.) live
;; in `core/dl-keymap.el' under `my-notes-map' and `my-notes-work-map'.

(provide 'dl-denote-journal)
;;; dl-denote-journal.el ends here
