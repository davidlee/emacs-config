;;; dl-persist-test.el --- ert tests for dl-persist autosave -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-persist RET.

(require 'ert)
(require 'dl-persist)

(ert-deftest dl-persist/buffer-churn-does-not-save ()
  "Creating and killing a scratch buffer leaves a modified file unsaved.
Completion backends (cape-dabbrev) churn temp buffers per keystroke;
autosave must not fire on that, only on real switches."
  (let* ((file (make-temp-file "dl-persist-test-"))
         (buf (find-file-noselect file)))
    (unwind-protect
        (save-window-excursion
          (switch-to-buffer buf)            ; the buffer being typed in
          (insert "unsaved")
          ;; As dabbrev does: churn from inside a temp buffer.
          (with-temp-buffer
            (kill-buffer (generate-new-buffer " *churn*")))
          (should (buffer-modified-p buf)))
      (with-current-buffer buf (set-buffer-modified-p nil))
      (kill-buffer buf)
      (delete-file file))))

(ert-deftest dl-persist/composing-buffer-not-autosaved ()
  "A with-editor session (e.g. a commit message) is never autosaved."
  (with-temp-buffer
    (setq-local buffer-file-name (make-temp-file "dl-persist-test-"))
    (unwind-protect
        (progn
          (insert "draft")
          (should (super-save-p))
          (setq-local with-editor-mode t)
          (should-not (super-save-p)))
      (delete-file buffer-file-name)
      (set-buffer-modified-p nil))))

(provide 'dl-persist-test)
;;; dl-persist-test.el ends here
