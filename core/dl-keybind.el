;;; dl-keybind.el --- keys -*- lexical-binding: t; -*-

;; GUI + PGUP / PGDN -- next / prev buffer
;;
;(global-set-key (kbd "s-<prior>") 'switch-to-prev-buffer)
;(global-set-key (kbd "s-<next>") 'switch-to-next-buffer)

(keymap-global-set "s-<prior>" 'switch-to-prev-buffer)
(keymap-global-set "s-<next>" 'switch-to-next-buffer)

(provide 'dl-keybind)
;;; dl-keybind.el ends here
