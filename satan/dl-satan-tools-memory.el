;;; dl-satan-tools-memory.el --- memory.add_candidate tool -*- lexical-binding: t; -*-

;; Stages a candidate "memory" — something the agent wants the user to
;; consider remembering — as a denote-named org file under
;; `~/notes/satan/memory/candidates/'.  Review is `find-file' for now;
;; promotion / rejection is manual.  Risk `medium': writes a durable
;; artifact (but in an isolated dir the user owns).

(require 'cl-lib)
(require 'subr-x)
(require 'dl-notes-paths)
(require 'dl-satan-tools)

(defcustom dl-satan-memory-candidates-dir
  (expand-file-name "satan/memory/candidates" dl-notes-root)
  "Directory for staged SATAN memory candidates."
  :type 'directory :group 'dl-satan)

(defun dl-satan-tools-memory--slugify (s)
  (let* ((down (downcase s))
         (clean (replace-regexp-in-string "[^a-z0-9]+" "-" down))
         (trim (replace-regexp-in-string "\\(^-+\\|-+$\\)" "" clean)))
    (if (string-empty-p trim) "untitled" trim)))

(defun dl-satan-tool/memory-add-candidate (args ctx)
  "Implements memory.add_candidate.
ARGS: (:title STR :body STR).  Refused unless TOOL-CTX `:capabilities'
includes `memory-candidate'.  Returns (ok :path P) | (error MSG)."
  (let* ((title (plist-get args :title))
         (body  (plist-get args :body))
         (run-id    (plist-get ctx :id))
         (mode-name (plist-get ctx :mode-name))
         (caps      (plist-get ctx :capabilities)))
    (cond
     ((not (memq 'memory-candidate caps))
      (cons 'error "mode lacks capability memory-candidate"))
     ((not (and (stringp title) (stringp body)))
      (cons 'error "title and body must be strings"))
     (t
      (unless (file-directory-p dl-satan-memory-candidates-dir)
        (make-directory dl-satan-memory-candidates-dir t))
      (let* ((id (format-time-string "%Y%m%dT%H%M%S" nil))
             (slug (dl-satan-tools-memory--slugify title))
             (filename (format "%s--%s__satan_memory.org" id slug))
             (path (expand-file-name filename
                                     dl-satan-memory-candidates-dir))
             (coding-system-for-write 'utf-8))
        (with-temp-file path
          (insert "#+title:      " title "\n")
          (insert "#+date:       "
                  (format-time-string "[%Y-%m-%d %a %H:%M]" nil) "\n")
          (insert "#+filetags:   :satan:memory:candidate:\n")
          (insert "#+identifier: " id "\n\n")
          (insert ":PROPERTIES:\n")
          (insert ":RUN_ID: " (or run-id "") "\n")
          (insert ":MODE: "   (or mode-name "") "\n")
          (insert ":END:\n\n")
          (insert body)
          (unless (string-suffix-p "\n" body) (insert "\n")))
        (cons 'ok (list :path path)))))))

(dl-satan-tool-register
 (list :name "memory.add_candidate"
       :description
       "Stage a candidate memory for later user review.  Use when you've \
spotted a fact or preference that future runs would benefit from \
remembering."
       :risk 'medium
       :args-schema '(title (:type string :required t)
                      body  (:type string :required t))
       :modes '("morning")
       :handler 'dl-satan-tool/memory-add-candidate))

(defun my/satan-memory-candidates ()
  "Open the SATAN memory-candidates directory in dired."
  (interactive)
  (unless (file-directory-p dl-satan-memory-candidates-dir)
    (make-directory dl-satan-memory-candidates-dir t))
  (dired dl-satan-memory-candidates-dir))

(provide 'dl-satan-tools-memory)
;;; dl-satan-tools-memory.el ends here
