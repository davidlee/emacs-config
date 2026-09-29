;;; dl-path-test.el --- ert tests for exec path assembly -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-path RET.

(require 'ert)
(require 'dl-path)

(ert-deftest dl-path/prepend-moves-existing-entries-forward ()
  "A prepended dir already in PATH moves forward rather than duplicating."
  (should (equal (dl-path-prepend '("/a" "/c") "/b:/c:/d")
                 "/a:/c:/b:/d")))

(ert-deftest dl-path/prepend-expands-tilde ()
  "Child processes take a leading tilde literally, so PATH must not hold one."
  (let ((process-environment (cons "HOME=/home/u" process-environment)))
    (should (equal (dl-path-prepend '("~/bin") "/usr/bin")
                   "/home/u/bin:/usr/bin"))))

(ert-deftest dl-path/setuid-wrappers-precede-system-profile ()
  "NixOS setuid wrappers (op, sudo) must shadow their raw sw/bin binaries."
  (let ((dirs (mapcar #'expand-file-name my/exec-dirs)))
    (should (< (seq-position dirs "/run/wrappers/bin")
               (seq-position dirs "/run/current-system/sw/bin")))))

(ert-deftest dl-path/exec-path-follows-path ()
  "`exec-path' and $PATH agree, so Emacs and its children find one binary."
  (should (equal (butlast exec-path)
                 (parse-colon-path (getenv "PATH")))))

;;; dl-path-test.el ends here
