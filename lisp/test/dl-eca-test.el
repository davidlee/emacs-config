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

;;; dl-eca-test.el ends here
