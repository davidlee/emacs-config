;;; dl-satan-context.el --- Build the run input bundle -*- lexical-binding: t; -*-

;; A context function returns the input-bundle plist that gets written to
;; `bundle.json' under the run directory.  Bundle is what the harness sees;
;; it is also frozen for audit.

(require 'subr-x)
(require 'dl-notes-paths)
(require 'dl-denote-journal)

(defcustom dl-satan-system-scaffold-file
  (expand-file-name "satan/system/scaffold.txt" dl-notes-root)
  "Shared system-prompt scaffold prepended to every mode prompt.
Canonical text lives under `~/notes/satan/system/'; dotfiles must
not be the source of truth for behavioural framing."
  :type 'file :group 'dl-satan)

(defun dl-satan-context--read-file-or-empty (path)
  "Return contents of PATH, or empty string if missing.
Use for optional context (e.g. today's note) — never for required
model-facing text; use `dl-satan-context--read-required' for that."
  (if (file-readable-p path)
      (with-temp-buffer
        (let ((coding-system-for-read 'utf-8))
          (insert-file-contents path))
        (buffer-string))
    ""))

(defun dl-satan-context--read-required (path)
  "Return contents of PATH; signal if missing.
Use for canonical model-facing text where silent emptiness would be
a misconfiguration: mode prompts, the system scaffold."
  (unless (file-readable-p path)
    (error "SATAN: required model-facing file missing: %s" path))
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents path))
    (buffer-string)))

(defun dl-satan-context--assemble-prompt (mode-spec)
  "Return MODE-SPEC's assembled system prompt: scaffold + mode prompt.
Both halves are required; missing files signal an error so a run
cannot start with degraded behavioural framing."
  (let* ((prompt-path (plist-get mode-spec :prompt-file))
         (scaffold (string-trim-right
                    (dl-satan-context--read-required
                     dl-satan-system-scaffold-file)))
         (prompt (string-trim-right
                  (dl-satan-context--read-required prompt-path))))
    (concat scaffold "\n\n" prompt)))

(defun dl-satan-context-morning (mode-spec)
  "Bundle for the morning mode: prompt + today's note text."
  (let* ((today (progn (my/journal--ensure-today)
                       (my/journal--today-file dl-notes-journal-dir "journal"))))
    (list :prompt   (dl-satan-context--assemble-prompt mode-spec)
          :mode     (plist-get mode-spec :name)
          :date     (format-time-string "%Y-%m-%d" nil)
          :today_path today
          :today_text (dl-satan-context--read-file-or-empty today))))

(defun dl-satan-context-motd (mode-spec)
  "Bundle for the motd mode."
  (list :prompt (dl-satan-context--assemble-prompt mode-spec)
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
    (list :prompt  (dl-satan-context--assemble-prompt mode-spec)
          :mode    (plist-get mode-spec :name)
          :date    (format-time-string "%Y-%m-%d" nil)
          :sources sources)))

(provide 'dl-satan-context)
;;; dl-satan-context.el ends here
