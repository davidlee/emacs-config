;;; dl-checkout.el --- Packages loaded from git checkouts -*- lexical-binding: t; -*-

;;; Commentary:

;; Some packages here come straight from a git checkout rather than an
;; archive or a system package manager.  Nothing else compiles those, so
;; their sources would load interpreted; this module keeps their `.elc'
;; files up to date at startup.

;;; Code:

(defun dl-checkout-compile-stale (library)
  "Byte-compile LIBRARY's sources whose .elc is missing or older.
LIBRARY is a library file name such as \"satan.el\", resolved with
`locate-library'; every `.el' beside it is compiled, not LIBRARY alone.
The package loads from a git checkout, so nothing else compiles it;
interpreted, its timers stall input.  Native-comp JIT follows the .elc."
  ;; Not while compiling another file (Flymake, `just lint'): that
  ;; compiler binds where .elc files go, and must not write any.
  (unless (bound-and-true-p byte-compile-current-file)
    (when-let* ((lib (locate-library library)))
      (let ((byte-compile-warnings nil))
        (dolist (el (directory-files (file-name-directory lib) t "\\.el\\'"))
          (when (file-newer-than-file-p el (byte-compile-dest-file el))
            (byte-compile-file el)))))))

(provide 'dl-checkout)
;;; dl-checkout.el ends here
