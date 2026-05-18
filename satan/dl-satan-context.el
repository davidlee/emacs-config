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

(defcustom dl-satan-self-edit-root
  (expand-file-name "satan" user-emacs-directory)
  "Root directory whose source is included in self-edit bundles."
  :type 'directory :group 'dl-satan)

(defcustom dl-satan-self-edit-source-regexp
  "\\.\\(el\\|py\\|txt\\|md\\)\\'"
  "Regexp matching filenames included in self-edit bundles."
  :type 'regexp :group 'dl-satan)

(defcustom dl-satan-self-edit-exclude-regexp
  "\\(\\.elc\\'\\|\\.original\\.md\\'\\|/test/.*\\.\\(local\\|secret\\)\\.\\)"
  "Regexp matching files to skip in self-edit bundles."
  :type 'regexp :group 'dl-satan)

(defun dl-satan-context-self-edit--list-files (root)
  "Return absolute paths of source files under ROOT, sorted."
  (let ((all (directory-files-recursively
              root dl-satan-self-edit-source-regexp nil nil)))
    (sort (cl-remove-if
           (lambda (p)
             (string-match-p dl-satan-self-edit-exclude-regexp p))
           all)
          #'string<)))

(defun dl-satan-context-self-edit (mode-spec)
  "Bundle for the self-edit mode: prompt + every source file under
`dl-satan-self-edit-root', each as (:path REL :content STR)."
  (let* ((root dl-satan-self-edit-root)
         (files (dl-satan-context-self-edit--list-files root))
         (sources
          (mapcar (lambda (f)
                    (list :path    (file-relative-name f user-emacs-directory)
                          :content (dl-satan-context--read-file-or-empty f)))
                  files)))
    (list :prompt  (dl-satan-context--prompt mode-spec)
          :mode    (plist-get mode-spec :name)
          :date    (format-time-string "%Y-%m-%d" nil)
          :sources sources)))

(provide 'dl-satan-context)
;;; dl-satan-context.el ends here
