;;; dl-crux.el --- crux -*- lexical-binding: t; -*-

(use-package crux
  ;;:defer t
  :config
  ;;  (global-set-key [remap smart-kill] #'crux-smart-kill-line)
  (global-set-key [remap move-beginning-of-line] #'crux-move-beginning-of-line)
  ;; `crux-open-with' is bound at `C-c f o' via `my-file-map' in `core/dl-keymap.el'.
  (global-set-key [(shift return)] #'crux-smart-open-line)
  (global-set-key (kbd "C-M-j") #'crux-top-join-line)
  (global-set-key (kbd "C-<backspace>") #'crux-kill-line-backward)
  (global-set-key [remap keyboard-quit] #'crux-keyboard-quit-dwim))

(provide 'dl-crux)
;;; dl-crux.el ends here
