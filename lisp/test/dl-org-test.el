;;; dl-org-test.el --- ert tests for dl-org -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-org RET.

(require 'ert)
(require 'dl-org)

(ert-deftest dl-org/background-org-buffer-keeps-out-of-window ()
  "Setting up margins in an undisplayed buffer leaves the selected window alone.
Background visitors (org-alert, agenda) must not take over the window."
  (let ((shown (generate-new-buffer "dl-org-test-shown"))
        (hidden (generate-new-buffer "dl-org-test-hidden")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer shown)
          (with-current-buffer hidden (my/org-setup-margins))
          (should (eq (window-buffer) shown)))
      (mapc #'kill-buffer (list shown hidden)))))

(ert-deftest dl-org/displayed-org-buffer-gets-margins ()
  "Setting up margins in a displayed buffer applies its margins to the window."
  (let ((buf (generate-new-buffer "dl-org-test-margins")))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer buf)
          (my/org-setup-margins)
          (should (equal (window-margins) '(2 . 2))))
      (kill-buffer buf))))

(provide 'dl-org-test)
;;; dl-org-test.el ends here
