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

(defun dl-satan-context-now (&optional time)
  "Return the canonical `:now' plist for TIME (default `current-time').
Every bundle includes this so the model has consistent date/time/tz
framing regardless of mode.  Keys: :iso_date, :weekday, :iso_week,
:time, :tz_offset, :tz_name."
  (let ((time (or time (current-time))))
    (list :iso_date  (format-time-string "%Y-%m-%d" time)
          :weekday   (format-time-string "%A"       time)
          :iso_week  (format-time-string "%G-W%V"   time)
          :time      (format-time-string "%H:%M"    time)
          :tz_offset (format-time-string "%z"       time)
          :tz_name   (format-time-string "%Z"       time))))

(defun dl-satan-context-morning (mode-spec)
  "Bundle for the morning mode: prompt + today's note text."
  (let* ((today (progn (my/journal--ensure-today)
                       (my/journal--today-file dl-notes-journal-dir "journal"))))
    (list :prompt     (dl-satan-context--assemble-prompt mode-spec)
          :mode       (plist-get mode-spec :name)
          :now        (dl-satan-context-now)
          :today_path today
          :today_text (dl-satan-context--read-file-or-empty today))))

(defun dl-satan-context-motd (mode-spec)
  "Bundle for the motd mode."
  (list :prompt (dl-satan-context--assemble-prompt mode-spec)
        :mode   (plist-get mode-spec :name)
        :now    (dl-satan-context-now)))

(defun dl-satan-context-tick (mode-spec)
  "Bundle for a tick mode.  Same shape as motd."
  (list :prompt (dl-satan-context--assemble-prompt mode-spec)
        :mode   (plist-get mode-spec :name)
        :now    (dl-satan-context-now)))

(defcustom dl-satan-self-edit-mech-roots
  (list (expand-file-name "satan" user-emacs-directory))
  "Roots whose source is included in the `self-edit-mech' bundle.
Mech = the broker / handlers / harness / tests — Emacs-side
machinery that runs the SATAN protocol."
  :type '(repeat directory) :group 'dl-satan)

(defcustom dl-satan-self-edit-mind-roots
  (list (expand-file-name "satan/prompts" (or (bound-and-true-p dl-notes-root)
                                              (expand-file-name "~/notes")))
        (expand-file-name "satan/system"  (or (bound-and-true-p dl-notes-root)
                                              (expand-file-name "~/notes")))
        (expand-file-name "satan/tools"   (or (bound-and-true-p dl-notes-root)
                                              (expand-file-name "~/notes"))))
  "Roots whose source is included in the `self-edit-mind' bundle.
Mind = mode prompts, the system scaffold, tool descriptions —
model-facing text under `~/notes/satan/' that shapes behaviour."
  :type '(repeat directory) :group 'dl-satan)

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
  (let ((all (and (file-directory-p root)
                  (directory-files-recursively
                   root dl-satan-self-edit-source-regexp nil nil))))
    (sort (cl-remove-if
           (lambda (p)
             (string-match-p dl-satan-self-edit-exclude-regexp p))
           all)
          #'string<)))

(defun dl-satan-context-self-edit (mode-spec)
  "Bundle for a self-edit mode: prompt + every source file under each
root in MODE-SPEC's `:source-roots' list, each as
\(:path ABBREVIATED :content STR).  Paths are abbreviated with `~/'
so the model sees `~/notes/satan/...' / `~/.emacs.d/satan/...' rather
than long relative dotwalks."
  (let* ((roots (or (plist-get mode-spec :source-roots)
                    (let ((var (plist-get mode-spec :source-roots-var)))
                      (and (symbolp var) (boundp var) (symbol-value var)))))
         (files (cl-loop for root in roots
                         append (dl-satan-context-self-edit--list-files root)))
         (sources
          (mapcar (lambda (f)
                    (list :path    (abbreviate-file-name f)
                          :content (dl-satan-context--read-file-or-empty f)))
                  files)))
    (list :prompt  (dl-satan-context--assemble-prompt mode-spec)
          :mode    (plist-get mode-spec :name)
          :now     (dl-satan-context-now)
          :roots   (mapcar #'abbreviate-file-name roots)
          :sources sources)))

(provide 'dl-satan-context)
;;; dl-satan-context.el ends here
