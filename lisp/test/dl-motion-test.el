;;; dl-motion-test.el --- ert tests for dl-motion jump list -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-motion RET.

(require 'ert)
(require 'dl-motion)

(defmacro dl-motion-test--with-jump-buffer (&rest body)
  "Run BODY in a selected text buffer far longer than `dogears-position-delta'.
Dogears state is isolated and the mode enabled."
  (declare (indent 0))
  `(let ((dogears-mode t)
         (dogears-list nil)
         (dogears-position 0))
     (with-temp-buffer
       (save-window-excursion
         (switch-to-buffer (current-buffer))
         (text-mode)
         (dotimes (i 50) (insert (format "line %d\n" i)))
         (goto-char (point-min))
         ,@body))))

(defun dl-motion-test--jump-to-end ()
  "A jump command: move to the end of the buffer."
  (interactive)
  (goto-char (point-max)))

(ert-deftest dl-motion/jump-records-origin-and-destination ()
  "A wrapped jump dogears both where it left and where it landed,
so `dogears-back' returns to the origin."
  (dl-motion-test--with-jump-buffer
    (dl-motion--dogear-jump #'dl-motion-test--jump-to-end)
    (should (= (length dogears-list) 2))
    (dogears-back)
    (should (= (point) (point-min)))))

(ert-deftest dl-motion/jump-not-recorded-when-mode-off ()
  "With `dogears-mode' disabled, wrapped jumps leave no trace."
  (dl-motion-test--with-jump-buffer
    (let ((dogears-mode nil))
      (dl-motion--dogear-jump #'dl-motion-test--jump-to-end))
    (should (null dogears-list))))

(provide 'dl-motion-test)
;;; dl-motion-test.el ends here
