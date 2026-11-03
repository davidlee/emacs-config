;;; dl-faces-test.el --- ert tests for dl-faces -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-faces RET.

(require 'ert)
(require 'org)                        ; dl-faces sets org faces at load
(require 'dl-faces)

(ert-deftest dl-faces/hidden-prog-buffer-keeps-out-of-window ()
  "A hidden buffer entering a `prog-mode' (e.g. a formatter scratch) never
takes over the selected window."
  (let ((shown (generate-new-buffer "dl-faces-test-shown"))
        (hidden (generate-new-buffer " dl-faces-test-hidden")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer shown)
          (with-current-buffer hidden (my/gutter-padding-mode 1))
          (should (eq (window-buffer) shown)))
      (mapc #'kill-buffer (list shown hidden)))))

(ert-deftest dl-faces/displayed-buffer-gets-gutter-padding ()
  "Enabling gutter padding in a displayed buffer applies it to the window."
  (let ((buf (generate-new-buffer "dl-faces-test-gutter")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer buf)
          (my/gutter-padding-mode 1)
          (should (equal (window-margins) '(1))))
      (kill-buffer buf))))

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
