;;; dl-eca-test.el --- ert tests for the jailed eca launch -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-eca RET.

(require 'ert)
(require 'dl-eca)

(ert-deftest dl-eca/runs-from-first-root ()
  "The jail binds its cwd, so the server starts in the first workspace root."
  (should (equal (dl-eca--run-in-first-root '("jailed-eca" "server")
                                            '("/tmp/proj/"))
                 '("env" "-C" "/tmp/proj/" "jailed-eca" "server"))))

(ert-deftest dl-eca/refuses-roots-containing-home ()
  "A root at or above ~ would hand the jail read-write access to all of home."
  (dolist (root (list "~" "~/" (file-name-directory
                                (directory-file-name (expand-file-name "~")))
                      "/"))
    (should-error (dl-eca--run-in-first-root '("jailed-eca" "server")
                                             (list root))
                  :type 'user-error)))

(ert-deftest dl-eca/without-roots-uses-default-directory ()
  "No roots: the jail binds `default-directory', so the same rules apply."
  (let ((default-directory "/tmp/proj/"))
    (should (equal (dl-eca--run-in-first-root '("jailed-eca") nil)
                   '("env" "-C" "/tmp/proj/" "jailed-eca"))))
  (let ((default-directory "~/"))
    (should-error (dl-eca--run-in-first-root '("jailed-eca") nil)
                  :type 'user-error)))

(ert-deftest dl-eca/toggle-switches-launch-settings ()
  "Toggling the jail swaps the server command, wrapper and pid probe together."
  (let ((vars '(dl-eca-jailed eca-custom-command
                eca-process-wrapper-function eca-send-process-id)))
    (let ((saved (mapcar #'default-value vars)))
      (unwind-protect
          (progn
            (customize-set-variable 'dl-eca-jailed t)
            (dl-eca-toggle-jail)
            (should-not dl-eca-jailed)
            (should (equal eca-custom-command '("op" "run" "--" "eca" "server")))
            (should-not eca-process-wrapper-function)
            (should eca-send-process-id)
            (dl-eca-toggle-jail)
            (should (equal eca-custom-command '("jailed-eca" "server")))
            (should (eq eca-process-wrapper-function #'dl-eca--run-in-first-root))
            (should-not eca-send-process-id))
        (cl-mapc #'set-default vars saved)))))

;;; dl-eca-test.el ends here
