;;; dl-satan.el --- integration with SATAN (github.com:davidlee/satan) -*- lexical-binding: t; -*-

(defun dl-satan--compile-stale ()
  "Byte-compile SATAN sources whose .elc is missing or older.
The package loads from a git checkout, so nothing else compiles it;
interpreted, its timers stall input.  Native-comp JIT follows the .elc."
  (when-let* ((lib (locate-library "satan.el")))
    (let ((byte-compile-warnings nil))
      (dolist (el (directory-files (file-name-directory lib) t "\\.el\\'"))
        (when (file-newer-than-file-p el (byte-compile-dest-file el))
          (byte-compile-file el))))))

(unless (eq system-type 'darwin)
  (dl-satan--compile-stale)
  (use-package satan
    :ensure nil
    :demand t
    :custom
    (satan-notes-root "~/notes")
    (satan-mcp-enabled t)
    (satan-goad-enabled t)
    ;; 1Password backend (dl-secret.el, required below; resolved at call time).
    (satan-credential-function #'my/satan-credential)
    (satan-journal-today
      (lambda ()
        (my/journal--ensure-today)
        (my/journal--today-file dl-notes-journal-dir "journal")))))

(provide 'dl-satan)
;;; dl-satan.el ends here
