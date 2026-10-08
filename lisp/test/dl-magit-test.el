;;; dl-magit-test.el --- ert tests for dl-magit ediff setup -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-magit RET.

(require 'ert)
(require 'dl-magit)
(require 'ediff)

(defun dl-magit-test--layout ()
  "The buffers shown in the selected frame, in window order."
  (mapcar #'window-buffer (window-list nil 'nomini (frame-first-window))))

(ert-deftest dl-magit/ediff-quit-restores-layout ()
  "Quitting a plain ediff session gives back the windows it replaced."
  (let ((a (generate-new-buffer "dl-magit-test-a"))
        (b (generate-new-buffer "dl-magit-test-b"))
        (other (generate-new-buffer "dl-magit-test-other")))
    (unwind-protect
        (save-window-excursion
          (with-current-buffer a (insert "one\ntwo\n"))
          (with-current-buffer b (insert "one\nthree\n"))
          (delete-other-windows)
          (switch-to-buffer other)
          (split-window-right)
          (let ((before (dl-magit-test--layout)))
            (with-current-buffer (ediff-buffers a b)  ; the control buffer
              (should-not (equal (dl-magit-test--layout) before))
              (ediff-really-quit nil))
            (should (equal (dl-magit-test--layout) before))))
      (mapc #'kill-buffer (list a b other)))))

;;; dl-magit-test.el ends here
