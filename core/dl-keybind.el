;;; dl-keybind.el --- keys -*- lexical-binding: t; -*-

;; GUI + PGUP / PGDN -- next / prev buffer
;;

(keymap-global-set "s-<prior>" 'switch-to-next-buffer)
(keymap-global-set "s-<next>" 'switch-to-prev-buffer)

(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "C-x C-b") 'ibuffer)
(global-set-key (kbd "M-z") 'zap-up-to-char)

(global-set-key (kbd "C-s") 'isearch-forward-regexp)
(global-set-key (kbd "C-r") 'isearch-backward-regexp)
(global-set-key (kbd "C-M-s") 'isearch-forward)
(global-set-key (kbd "C-M-r") 'isearch-backward)

(use-package expand-region)

(provide 'dl-keybind)

;; look at: god-mode // meow-mode


;;; dl-keybind.el ends here
