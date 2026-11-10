;;; dl-elisp-test.el --- ert tests for Elisp editing setup -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-elisp RET.

;;; Code:

(require 'ert)
(require 'dl-elisp)

(defun dl-elisp-test--backends-visiting (file)
  "Flymake backends of an `emacs-lisp-mode' buffer visiting FILE."
  (with-temp-buffer
    (setq buffer-file-name (expand-file-name file dl-lint--root))
    (delay-mode-hooks (emacs-lisp-mode))
    (run-mode-hooks 'emacs-lisp-mode-hook)
    (prog1 flymake-diagnostic-functions
      (setq buffer-file-name nil))))

(ert-deftest dl-elisp/flymake-skips-byte-compile-where-lint-does ()
  "Flymake's byte-compile check is off in init.el and on in modules."
  (let ((emacs-lisp-mode-hook (list #'dl-elisp--skip-excluded-byte-compile)))
    (should-not (memq #'elisp-flymake-byte-compile
                      (dl-elisp-test--backends-visiting "init.el")))
    (should (memq #'elisp-flymake-byte-compile
                  (dl-elisp-test--backends-visiting "core/dl-path.el")))))

(provide 'dl-elisp-test)
;;; dl-elisp-test.el ends here
