;;; dl-ediff-test.el --- ert tests for dl-ediff -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-ediff RET.

(require 'ert)
(require 'dl-ediff)
(require 'ediff)

(defun dl-ediff-test--layout ()
  "The buffers shown in the selected frame, in window order."
  (mapcar #'window-buffer (window-list nil 'nomini (frame-first-window))))

(ert-deftest dl-ediff/quit-restores-layout ()
  "Quitting a plain ediff session gives back the windows it replaced."
  (let ((a (generate-new-buffer "dl-ediff-test-a"))
        (b (generate-new-buffer "dl-ediff-test-b"))
        (other (generate-new-buffer "dl-ediff-test-other")))
    (unwind-protect
        (save-window-excursion
          (with-current-buffer a (insert "one\ntwo\n"))
          (with-current-buffer b (insert "one\nthree\n"))
          (delete-other-windows)
          (switch-to-buffer other)
          (split-window-right)
          (let ((before (dl-ediff-test--layout)))
            (with-current-buffer (ediff-buffers a b)  ; the control buffer
              (should-not (equal (dl-ediff-test--layout) before))
              (ediff-really-quit nil))
            (should (equal (dl-ediff-test--layout) before))))
      (mapc #'kill-buffer (list a b other)))))

;;; dl-ediff-test.el ends here
