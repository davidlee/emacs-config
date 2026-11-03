;;; dl-declare-test.el --- ert tests for declare-function generation -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-declare RET.

(require 'ert)
(require 'dl-declare)

(ert-deftest dl-declare/extracts-unique-sorted-functions-from-warnings ()
  "Only \"not known to be defined\" warnings count; repeats collapse."
  (should (equal (dl-declare-undefined-functions
                  '("the function ‘zeta’ is not known to be defined."
                    "reference to free variable ‘foo’"
                    "the function ‘alpha’ is not known to be defined."
                    "the function `zeta' is not known to be defined."))
                 '(alpha zeta))))

(ert-deftest dl-declare/form-names-the-defining-file ()
  "A loaded function is declared against the file that defines it."
  (should (equal (dl-declare-form 'project-find-file)
                 "(declare-function project-find-file \"project\")")))

(ert-deftest dl-declare/form-flags-unknown-definition ()
  "A function defined nowhere gets a FIXME rather than a guessed file."
  (should (string-match-p
           "FIXME"
           (dl-declare-form 'dl-declare-test--no-such-function))))

(provide 'dl-declare-test)
;;; dl-declare-test.el ends here
