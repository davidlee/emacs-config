;;; dl-satan-tools-hippocampus.el --- hippocampus_write tool -*- lexical-binding: t; -*-

;; The hippocampus is SATAN's self-curated memory.  Entries are denote-named
;; org files written into `~/notes/satan/hippocampus/'.  SATAN owns the
;; directory: write is auto-applied, no candidate / confirmed ceremony.
;; Risk `low' — the user can grep, edit, or delete files directly.

(require 'cl-lib)
(require 'subr-x)
(require 'dl-notes-paths)
(require 'dl-satan-tools)
(require 'dl-satan-memory-grammar)
(require 'dl-satan-memory-canon)
(require 'dl-satan-memory-evidence)
(require 'dl-satan-memory-store)

(defcustom dl-satan-hippocampus-dir
  (expand-file-name "satan/hippocampus" dl-notes-root)
  "Directory holding SATAN hippocampus entries."
  :type 'directory :group 'dl-satan)

(defun dl-satan-tools-hippocampus--slugify (s)
  (let* ((down (downcase s))
         (clean (replace-regexp-in-string "[^a-z0-9]+" "-" down))
         (trim (replace-regexp-in-string "\\(^-+\\|-+$\\)" "" clean)))
    (if (string-empty-p trim) "untitled" trim)))

(defun dl-satan-tools-hippocampus--mode-str (raw)
  (cond ((null raw) nil)
        ((symbolp raw) (symbol-name raw))
        ((stringp raw) raw)
        (t (format "%s" raw))))

(defun dl-satan-tools-hippocampus--cross-ref (title path tool-ctx)
  "Mark an `auto_rule' observation trace cross-referencing the
hippocampus PATH (§10.7 of memory.design.md).  Soft failure: any
substrate error is logged and does not affect the caller."
  (condition-case err
      (let* ((mode-str (dl-satan-tools-hippocampus--mode-str
                        (plist-get tool-ctx :mode-name)))
             (canon-ctx
              (list :current_grammar_version
                    dl-satan-memory-grammar-current-version
                    :mode_name mode-str
                    :time_now (or (plist-get tool-ctx :time-now)
                                  (format-time-string "%Y-%m-%dT%T%:z"))
                    :run_id (plist-get tool-ctx :id)
                    :run_started_at (plist-get tool-ctx :run-started-at)))
             (slug (dl-satan-tools-hippocampus--slugify title))
             (raw-hints (list :topic (list slug)))
             (evidence (dl-satan-memory-evidence-assemble
                        canon-ctx
                        (list :run_started_at
                              (plist-get canon-ctx :run_started_at))))
             (canon (dl-satan-memory-canon-canonicalize-from-raw
                     evidence raw-hints canon-ctx))
             (handles (plist-get canon :handles))
             (sources (plist-get canon :handle_sources))
             (normalized (plist-get canon :normalized))
             (gv (plist-get canon-ctx :current_grammar_version))
             (handle-rows
              (mapcar (lambda (h)
                        (list :handle h
                              :source (cdr (assoc h sources))
                              :grammar_version gv))
                      handles))
             (metadata
              (list :evidence evidence
                    :hints raw-hints
                    :normalized_hints (or normalized '())
                    :ctx canon-ctx
                    :hippocampus_path (abbreviate-file-name path)
                    :truncated_at (plist-get evidence :truncated_at)))
             (result
              (dl-satan-memory-store-mark
               :kind "observation"
               :trace-origin "auto_rule"
               :source (format "hippocampus_write@%s"
                               (or mode-str "unknown"))
               :observed-start-at (plist-get evidence :window_start_at)
               :observed-end-at   (plist-get evidence :window_end_at)
               :payload (format "hippocampus entry: %s" title)
               :grammar-version gv
               :metadata-json metadata
               :handles handle-rows)))
        (pcase result
          (`(ok . ,tid) tid)
          (`(error . ,msg)
           (message "hippocampus cross-ref skipped: %s" msg)
           nil)))
    (error
     (message "hippocampus cross-ref error: %s"
              (error-message-string err))
     nil)))

(defun dl-satan-tool/hippocampus-write (args ctx)
  "Implements hippocampus_write.
ARGS: (:title STR :body STR).  Refused unless TOOL-CTX `:capabilities'
includes `hippocampus-write'.  Returns (ok :path P) | (error MSG).
When `memory-write' is also present, emits an `auto_rule' observation
trace cross-referencing PATH (§10.7); cross-ref errors are soft."
  (let* ((title (plist-get args :title))
         (body  (plist-get args :body))
         (run-id    (plist-get ctx :id))
         (mode-str  (plist-get ctx :mode-name))
         (caps      (plist-get ctx :capabilities)))
    (cond
     ((not (memq 'hippocampus-write caps))
      (cons 'error "mode lacks capability hippocampus-write"))
     ((not (and (stringp title) (stringp body)))
      (cons 'error "title and body must be strings"))
     (t
      (unless (file-directory-p dl-satan-hippocampus-dir)
        (make-directory dl-satan-hippocampus-dir t))
      (let* ((id (format-time-string "%Y%m%dT%H%M%S" nil))
             (slug (dl-satan-tools-hippocampus--slugify title))
             (filename (format "%s--%s__satan_hippocampus.org" id slug))
             (path (expand-file-name filename
                                     dl-satan-hippocampus-dir))
             (coding-system-for-write 'utf-8))
        (with-temp-file path
          (insert "#+title:      " title "\n")
          (insert "#+date:       "
                  (format-time-string "[%Y-%m-%d %a %H:%M]" nil) "\n")
          (insert "#+filetags:   :satan:hippocampus:\n")
          (insert "#+identifier: " id "\n\n")
          (insert ":PROPERTIES:\n")
          (insert ":RUN_ID: " (or run-id "") "\n")
          (insert ":MODE: "   (or mode-str "") "\n")
          (insert ":END:\n\n")
          (insert body)
          (unless (string-suffix-p "\n" body) (insert "\n")))
        (when (memq 'memory-write caps)
          (dl-satan-tools-hippocampus--cross-ref title path ctx))
        (cons 'ok (list :path path)))))))

(dl-satan-tool-register
 (list :name "hippocampus_write"
       :risk 'low
       :args-schema '(title (:type string :required t)
                      body  (:type string :required t))
       :handler 'dl-satan-tool/hippocampus-write))

(defun my/satan-hippocampus ()
  "Open the SATAN hippocampus directory in dired."
  (interactive)
  (unless (file-directory-p dl-satan-hippocampus-dir)
    (make-directory dl-satan-hippocampus-dir t))
  (dired dl-satan-hippocampus-dir))

(provide 'dl-satan-tools-hippocampus)
;;; dl-satan-tools-hippocampus.el ends here
