;;; dl-denote-journal.el --- Daily / weekly journal note builders -*- lexical-binding: t; -*-

(require 'dl-notes-paths)

;; NOTE: Phase 1 kept the simple-name format while paths moved to
;; journal/ and weekly/.  Phase 3 of the notes-system plan replaces
;; these with Denote-named equivalents (likely via denote-journal-extras
;; if available in the emacs-overlay, else a rolled-own variant).

(defun my/daily-note ()
  "Open today's plain Org daily note."
  (interactive)
  (let ((file (expand-file-name
                (format-time-string "%Y-%m-%d.org")
                dl-notes-journal-dir)))
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title: " (format-time-string "%Y-%m-%d %A") "\n")
      (insert "#+filetags: :journal:\n\n")
      (insert "* Focus\n\n* Notes\n\n* Log\n"))))

(defun my/weekly-note ()
  "Open this week's plain Org weekly note."
  (interactive)
  (let ((file (expand-file-name
                (format-time-string "%G-W%V.org")
                dl-notes-weekly-dir)))
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title: " (format-time-string "Week %G-W%V") "\n")
      (insert "#+filetags: :journal:weekly:\n\n")
      (insert "* Review\n\n* Projects\n\n* Notes promoted\n\n* Next week\n"))))

(global-set-key (kbd "C-c n d") #'my/daily-note)
(global-set-key (kbd "C-c n w") #'my/weekly-note)

(provide 'dl-denote-journal)
;;; dl-denote-journal.el ends here
