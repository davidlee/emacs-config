;;; dl-buffer-management.le --- buffer management utils -*- lexical-binding: t; -*-

(defun toggle-maximize-buffer ()
  "Maximize the current buffer or restore the previous layout."
  (interactive)
  (if (= 1 (length (window-list)))
      (jump-to-register :maximize)
    (progn
      (window-configuration-to-register :maximize)
      (delete-other-windows))))

;; Bind it to a key (example: F9)
(global-set-key (kbd "<f9>") 'toggle-maximize-buffer)

(provide 'dl-buffer-management)
;;; dl-buffer-management.le ends here
