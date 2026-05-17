;;; dl-file-ops.el --- File-on-disk helpers -*- lexical-binding: t; -*-

;; Commands for acting on the file backing the current buffer.
;; Bindings live in `core/dl-keymap.el' (`my-file-map').

(defun my/delete-current-buffer-file ()
  "Delete the file backing the current buffer and kill the buffer.
With no file, just kill the buffer."
  (interactive)
  (let ((file (buffer-file-name))
        (buf  (current-buffer)))
    (if (not (and file (file-exists-p file)))
        (kill-current-buffer)
      (when (yes-or-no-p (format "Delete file %s? " file))
        (delete-file file t)
        (kill-buffer buf)
        (message "Deleted %s" file)))))

(defun my/move-file ()
  "Write the current buffer to a new location and delete the old file."
  (interactive)
  (let ((old (buffer-file-name)))
    (call-interactively #'write-file)
    (when (and old (not (string= old (buffer-file-name))))
      (delete-file old)
      (message "Moved %s -> %s" old (buffer-file-name)))))

(provide 'dl-file-ops)
;;; dl-file-ops.el ends here
