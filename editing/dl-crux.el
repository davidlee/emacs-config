;;; dl-crux.el --- crux -*- lexical-binding: t; -*-

;; `crux-open-with' (`C-c f o') and `crux-kill-buffer-truename' (`C-c f p')
;; are bound via `my-file-map' in `core/dl-keymap.el'.
(use-package crux
  :bind (([remap move-beginning-of-line] . crux-move-beginning-of-line)
         ([remap keyboard-quit]          . crux-keyboard-quit-dwim)
         ("S-<return>"                   . crux-smart-open-line)
         ("C-M-j"                        . crux-top-join-line)
         ("C-<backspace>"                . crux-kill-line-backward)))

(provide 'dl-crux)
;;; dl-crux.el ends here
