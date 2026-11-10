;;; dl-buffer-management.el --- buffer management utils -*- lexical-binding: t; -*-

(defun toggle-maximize-buffer ()
  "Maximize the current buffer or restore the previous layout."
  (interactive)
  (if (= 1 (length (window-list)))
      (jump-to-register :maximize)
    (progn
      (window-configuration-to-register :maximize)
      (delete-other-windows))))

;;;; User-buffer cycling
;; Skip *foo* and dired buffers when stepping through `buffer-list'.
;; Adapted from ergoemacs / lambda-emacs `lem-user-buffer-q'.

(defun my/user-buffer-p ()
  "Non-nil if current buffer is a \"user buffer\".
Buffers whose name starts with `*' and dired buffers are excluded."
  (and (not (string-prefix-p "*" (buffer-name)))
       (not (derived-mode-p 'dired-mode))))

(defun my/next-user-buffer ()
  "Switch to the next buffer for which `my/user-buffer-p' is non-nil."
  (interactive)
  (next-buffer)
  (let ((i 0))
    (while (and (not (my/user-buffer-p)) (< i 20))
      (next-buffer)
      (setq i (1+ i)))))

(defun my/previous-user-buffer ()
  "Switch to the previous buffer for which `my/user-buffer-p' is non-nil."
  (interactive)
  (previous-buffer)
  (let ((i 0))
    (while (and (not (my/user-buffer-p)) (< i 20))
      (previous-buffer)
      (setq i (1+ i)))))

(defun my/tmp-buffer ()
  "Create a timestamped scratch buffer in the current major mode."
  (interactive)
  (let ((mode major-mode)
        (name (format-time-string "tmp-%Y%m%dT%H%M%S")))
    (switch-to-buffer (get-buffer-create name))
    (funcall mode)))

(provide 'dl-buffer-management)
;;; dl-buffer-management.el ends here
