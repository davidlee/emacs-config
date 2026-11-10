;;; dl-lint-test.el --- ert tests for the elisp lint gate -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-lint RET.

;;; Code:

(require 'ert)
(require 'dl-lint)

(defmacro dl-lint-test--with-fixture (var source &rest body)
  "Bind VAR to a temporary .el file holding SOURCE, then run BODY."
  (declare (indent 2))
  `(let ((,var (make-temp-file "dl-lint-fixture-" nil ".el")))
     (unwind-protect
         (progn
           (with-temp-file ,var
             (insert ";;; f.el --- f -*- lexical-binding: t; -*-\n" ,source))
           ,@body)
       (delete-file ,var))))

(ert-deftest dl-lint/clean-file-has-no-diagnostics ()
  "A file that compiles cleanly reports nothing."
  (dl-lint-test--with-fixture file "(defun f-clean () 1)\n"
    (should (null (dl-lint-diagnostics file)))))

(ert-deftest dl-lint/warning-reports-its-line ()
  "A byte-compiler warning reports the line it is on."
  (dl-lint-test--with-fixture file "\n\n(defun f-unused () (let ((x 1)) 2))\n"
    (let ((diagnostics (dl-lint-diagnostics file)))
      (should (= (length diagnostics) 1))
      (pcase-let ((`(,line ,level ,message) (car diagnostics)))
        (should (= line 4))
        (should (eq level :warning))
        (should (string-match-p "Unused lexical variable" message))))))

(ert-deftest dl-lint/diagnostics-sort-by-line ()
  "Diagnostics come back in source order."
  (dl-lint-test--with-fixture file
      "(defun f-a () (f-undefined-a))\n(defun f-b () (let ((y 1)) 2))\n"
    (let ((lines (mapcar #'car (dl-lint-diagnostics file))))
      (should (equal lines (sort (copy-sequence lines) #'<))))))

(ert-deftest dl-lint/format-is-compiler-style ()
  "A diagnostic formats as FILE:LINE: LEVEL: MESSAGE."
  (should (equal (dl-lint-format "core/x.el" '(12 :warning "bad thing"))
                 "core/x.el:12: warning: bad thing")))

(ert-deftest dl-lint/format-keeps-one-line ()
  "A multi-line message stays on one line, so each line is one diagnostic."
  (should (equal (dl-lint-format "x.el" '(1 :error "first\n  second"))
                 "x.el:1: error: first second")))

(ert-deftest dl-lint/excludes-files-it-cannot-or-should-not-check ()
  "init.el and generated themes are not checked; modules are."
  (let ((root dl-dirs-root))
    (dolist (file '("init.el" "themes/noctalia-theme.el"))
      (should (dl-lint-excluded-p (expand-file-name file root))))
    (dolist (file '("core/dl-path.el" "early-init.el" "test/init.el"))
      (should-not (dl-lint-excluded-p (expand-file-name file root))))))

(provide 'dl-lint-test)
;;; dl-lint-test.el ends here
