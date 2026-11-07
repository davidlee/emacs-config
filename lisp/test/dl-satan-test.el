;;; dl-satan-test.el --- ert tests for dl-satan -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-satan RET.

(require 'ert)

(defun dl-satan-test--configured-p (guix-p)
  "Return non-nil if dl-satan configures SATAN when `dl-guix-system-p' is GUIX-P.
Runs in a fresh Emacs with SATAN stubbed: here, loading it would start it."
  (let* ((form (prin1-to-string
                `(progn
                   (setq load-prefer-newer t)
                   (require 'dl-guix)
                   (fset 'dl-guix-system-p (lambda () ,guix-p))
                   (provide 'satan)
                   (provide 'malebolge-mail)
                   (require 'dl-satan)
                   (princ (if (boundp 'malebolge-mail-plans-directory)
                              "configured" "skipped")))))
         (output (with-output-to-string
                   (with-current-buffer standard-output
                     (call-process (expand-file-name invocation-name invocation-directory)
                                   nil t nil "-Q" "--batch"
                                   "-L" (file-name-directory (locate-library "dl-guix"))
                                   "-L" (file-name-directory (locate-library "dl-satan"))
                                   "--eval" form)))))
    (string-suffix-p "configured" output)))

(ert-deftest dl-satan/configures-off-guix ()
  "Nix hosts keep SATAN."
  (should (dl-satan-test--configured-p nil)))

(ert-deftest dl-satan/skips-on-guix ()
  "SATAN and Malebolge are built with Nix, so Guix leaves them out."
  (should-not (dl-satan-test--configured-p t)))

(provide 'dl-satan-test)
;;; dl-satan-test.el ends here
