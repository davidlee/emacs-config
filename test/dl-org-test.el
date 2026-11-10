;;; dl-org-test.el --- ert tests for dl-org -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-org RET.

(require 'ert)
(require 'dl-org)
(require 'hl-line)

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

(defun dl-org-test--highlighted (line)
  "The text `hl-line' would paint with point on LINE in an org buffer."
  (with-temp-buffer
    (org-mode)
    (insert line "\nnext\n")
    (goto-char (point-min))
    (pcase-let ((`(,start . ,end) (funcall hl-line-range-function)))
      (buffer-substring-no-properties start end))))

(ert-deftest dl-org/highlight-leaves-a-todo-keyword-its-own-background ()
  "The line highlight starts after the keyword: overlays repaint text properties."
  (should (equal (dl-org-test--highlighted "** TODO task") " task\n"))
  (should (equal (dl-org-test--highlighted "* DONE task") " task\n")))

(ert-deftest dl-org/highlight-covers-lines-without-a-keyword ()
  "Any other line is highlighted whole, like `hl-line' by default."
  (dolist (line '("* plain heading" "body TODO text" "* todo lowercase"))
    (should (equal (dl-org-test--highlighted line) (concat line "\n")))))

(provide 'dl-org-test)
;;; dl-org-test.el ends here
