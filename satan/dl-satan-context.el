;;; dl-satan-context.el --- Build the run input bundle -*- lexical-binding: t; -*-

;; A context function returns the input-bundle plist that gets written to
;; `bundle.json' under the run directory.  Bundle is what the harness sees;
;; it is also frozen for audit.

(require 'subr-x)
(require 'dl-notes-paths)
(require 'dl-denote-journal)

(defun dl-satan-context--read-file-or-empty (path)
  (if (file-readable-p path)
      (with-temp-buffer
        (let ((coding-system-for-read 'utf-8))
          (insert-file-contents path))
        (buffer-string))
    ""))

(defun dl-satan-context--prompt (mode-spec)
  (let ((p (plist-get mode-spec :prompt-file)))
    (dl-satan-context--read-file-or-empty p)))

(defun dl-satan-context-morning (mode-spec)
  "Bundle for the morning mode: prompt + today's note text."
  (let* ((today (progn (my/journal--ensure-today)
                       (my/journal--today-file dl-notes-journal-dir "journal"))))
    (list :prompt   (dl-satan-context--prompt mode-spec)
          :mode     (plist-get mode-spec :name)
          :date     (format-time-string "%Y-%m-%d" nil)
          :today_path today
          :today_text (dl-satan-context--read-file-or-empty today))))

(defun dl-satan-context-motd (mode-spec)
  "Bundle for the motd mode."
  (list :prompt (dl-satan-context--prompt mode-spec)
        :mode   (plist-get mode-spec :name)
        :date   (format-time-string "%Y-%m-%d" nil)))

(provide 'dl-satan-context)
;;; dl-satan-context.el ends here
