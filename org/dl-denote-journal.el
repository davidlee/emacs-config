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

(defun my/journal-note ()
  "Open or create today's Denote-named daily journal note."
  (interactive)
  (let* ((now (current-time))
         (id   (format-time-string "%Y%m%dT000000" now))
         (slug (downcase (format-time-string "%Y-%m-%d-%A" now)))
         (file (expand-file-name
                (format "%s--%s__journal.org" id slug)
                dl-notes-journal-dir)))
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title:    " (format-time-string "%Y-%m-%d %A" now) "\n")
      (insert "#+filetags: :journal:\n")
      (insert "#+date:     " (format-time-string "[%Y-%m-%d %a]" now) "\n\n")
      (insert "* Focus\n\n* Notes\n\n* Log\n"))))

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

;; Retire the Phase 1/2 `C-c n d` daily binding in favour of `C-c n j`.
(define-key global-map (kbd "C-c n d") nil)
(global-set-key (kbd "C-c n j") #'my/journal-note)
(global-set-key (kbd "C-c n w") #'my/weekly-note)

(provide 'dl-denote-journal)
;;; dl-denote-journal.el ends here
