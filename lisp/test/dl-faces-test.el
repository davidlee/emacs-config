;;; dl-faces-test.el --- ert tests for dl-faces -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-faces RET.

(require 'ert)
(require 'org)                        ; dl-faces sets org faces at load
(require 'dl-faces)

(ert-deftest dl-faces/line-numbers-pad-the-text-while-shown ()
  "Text is prefixed off the line numbers only while they are displayed."
  (with-temp-buffer
    (display-line-numbers-mode 1)
    (should (equal line-prefix " "))
    (should (equal wrap-prefix " "))
    (display-line-numbers-mode -1)
    (should-not line-prefix)
    (should-not wrap-prefix)))

(ert-deftest dl-faces/line-number-faces-survive-theme-recalc ()
  "Line-number alignment settings outlive a theme recalculation of the faces.
Themes (and `spacious-padding') recalc faces on new frames; ad-hoc
`set-face-attribute' edits are wiped, mismatching the two faces' families."
  (my/apply-line-number-faces)
  (let ((family (my/font-role 'line-number)))
    (dolist (face '(line-number line-number-current-line))
      (custom-theme-recalc-face face)
      (should (equal (face-attribute face :family nil) family))
      (should (eq (face-attribute face :weight nil) 'regular)))))

(provide 'dl-faces-test)
;;; dl-faces-test.el ends here
