;;; dl-keybind.el --- keys -*- lexical-binding: t; -*-

;; GUI + PGUP / PGDN -- next / prev buffer
;;

(keymap-global-set "s-<prior>" 'switch-to-prev-buffer)
(keymap-global-set "s-<next>" 'switch-to-next-buffer)

(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "C-x C-b") 'ibuffer)
(global-set-key (kbd "M-z") 'zap-up-to-char)

(global-set-key (kbd "C-s") 'isearch-forward-regexp)
(global-set-key (kbd "C-r") 'isearch-backward-regexp)
(global-set-key (kbd "C-M-s") 'isearch-forward)
(global-set-key (kbd "C-M-r") 'isearch-backward)

(provide 'dl-keybind)

;;; dl-keybind.el ends here
