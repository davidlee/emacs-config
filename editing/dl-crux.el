;;; dl-crux.el --- crux -*- lexical-binding: t; -*-

(use-package crux
  ;;:defer t
  :config
  ;;  (global-set-key [remap smart-kill] #'crux-smart-kill-line)
  (global-set-key [remap move-beginning-of-line] #'crux-move-beginning-of-line)
  (global-set-key (kbd "C-c O") #'crux-open-with)
  (global-set-key [(shift return)] #'crux-smart-open-line)
  (global-set-key (kbd "C-M-j") #'crux-top-join-line)
  (global-set-key (kbd "C-<backspace>") #'crux-kill-line-backward)
  (global-set-key [remap keyboard-quit] #'crux-keyboard-quit-dwim))

(provide 'dl-crux)
;;; dl-crux.el ends here
