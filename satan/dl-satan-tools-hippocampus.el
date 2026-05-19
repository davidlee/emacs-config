;;; dl-satan-tools-hippocampus.el --- hippocampus_write tool -*- lexical-binding: t; -*-

;; The hippocampus is SATAN's self-curated memory.  Entries are denote-named
;; org files written into `~/notes/satan/hippocampus/'.  SATAN owns the
;; directory: write is auto-applied, no candidate / confirmed ceremony.
;; Risk `low' — the user can grep, edit, or delete files directly.

(require 'cl-lib)
(require 'subr-x)
(require 'dl-notes-paths)
(require 'dl-satan-tools)

(defcustom dl-satan-hippocampus-dir
  (expand-file-name "satan/hippocampus" dl-notes-root)
  "Directory holding SATAN hippocampus entries."
  :type 'directory :group 'dl-satan)

(defun dl-satan-tools-hippocampus--slugify (s)
  (let* ((down (downcase s))
         (clean (replace-regexp-in-string "[^a-z0-9]+" "-" down))
         (trim (replace-regexp-in-string "\\(^-+\\|-+$\\)" "" clean)))
    (if (string-empty-p trim) "untitled" trim)))

(defun dl-satan-tool/hippocampus-write (args ctx)
  "Implements hippocampus_write.
ARGS: (:title STR :body STR).  Refused unless TOOL-CTX `:capabilities'
includes `hippocampus-write'.  Returns (ok :path P) | (error MSG)."
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
        (cons 'ok (list :path path)))))))

(dl-satan-tool-register
 (list :name "hippocampus_write"
       :risk 'low
       :args-schema '(title (:type string :required t)
                      body  (:type string :required t))
       :modes '("morning")
       :handler 'dl-satan-tool/hippocampus-write))

(defun my/satan-hippocampus ()
  "Open the SATAN hippocampus directory in dired."
  (interactive)
  (unless (file-directory-p dl-satan-hippocampus-dir)
    (make-directory dl-satan-hippocampus-dir t))
  (dired dl-satan-hippocampus-dir))

(provide 'dl-satan-tools-hippocampus)
;;; dl-satan-tools-hippocampus.el ends here
