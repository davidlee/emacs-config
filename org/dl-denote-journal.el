;;; dl-denote-journal.el --- Daily / weekly journal notes (Denote-named) -*- lexical-binding: t; -*-

;; Roll-own journal helpers: denote 4.1.3 ships without the
;; `denote-journal' submodule (it was split off in 4.x).  These functions
;; produce filenames in the Denote convention so they sort and search
;; alongside everything else under `dl-notes-root'.
;;
;; Daily:  journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org
;; Weekly: weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org

(require 'dl-notes-paths)

(defun my/journal--iso-monday (time)
  "Return TIME shifted back to the Monday of its ISO week."
  (let ((dow (string-to-number (format-time-string "%u" time))))
    (time-subtract time (days-to-time (1- dow)))))

(defun my/journal--today-file ()
  "Return today's Denote-named journal file path (does not create the file)."
  (let* ((now  (current-time))
         (id   (format-time-string "%Y%m%dT000000" now))
         (slug (downcase (format-time-string "%Y-%m-%d-%A" now))))
    (expand-file-name
     (format "%s--%s__journal.org" id slug)
     dl-notes-journal-dir)))

(defun my/journal--today-skeleton ()
  "Return the skeleton string for a newly-created daily journal file."
  (let ((now (current-time)))
    (concat "#+title:    " (format-time-string "%Y-%m-%d %A" now) "\n"
            "#+filetags: :journal:\n"
            "#+date:     " (format-time-string "[%Y-%m-%d %a]" now) "\n\n"
            "* Focus\n\n* Notes\n\n* Log\n")))

(defun my/journal--ensure-today ()
  "Ensure today's Denote journal file exists with the skeleton; return its path.
Used as the dynamic file target for the `j' capture template so a capture
can land in today's file even when it's the first touch of the day."
  (let ((file (my/journal--today-file)))
    (unless (file-exists-p file)
      (with-temp-buffer
        (insert (my/journal--today-skeleton))
        (write-region (point-min) (point-max) file)))
    file))

(defun my/journal-note ()
  "Open or create today's Denote-named daily journal note."
  (interactive)
  (let ((file (my/journal--today-file)))
    (find-file file)
    (when (= (point-max) 1)
      (insert (my/journal--today-skeleton)))))

(defun my/weekly-note ()
  "Open or create this week's Denote-named weekly journal note.
Identifier is anchored on the ISO-week Monday, so the file sorts to the
start of its week regardless of which day the note is first opened."
  (interactive)
  (let* ((monday (my/journal--iso-monday (current-time)))
         (id     (format-time-string "%Y%m%dT000000" monday))
         (slug   (downcase (format-time-string "%Y-w%V" monday)))
         (file (expand-file-name
                (format "%s--%s__weekly_journal.org" id slug)
                dl-notes-weekly-dir)))
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title:    " (format-time-string "Week %G-W%V" monday) "\n")
      (insert "#+filetags: :weekly:journal:\n")
      (insert "#+date:     " (format-time-string "[%Y-%m-%d %a]" monday) "\n\n")
      (insert "* Review\n\n* Projects\n\n* Notes promoted\n\n* Next week\n"))))

;; Bindings (`C-c n j', `C-c n w', `C-c n N j', `C-c n N w') live in
;; `core/dl-keymap.el' under `my-notes-map' / `my-notes-new-map'.

(provide 'dl-denote-journal)
;;; dl-denote-journal.el ends here
