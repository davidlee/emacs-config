;;; dl-term.el --- terminals -*- lexical-binding: t; -*-

;;
;; EAT
;;

(use-package eat
  :custom
  (eat-term-name "xterm")
  (eat-eshell-mode)                     ; use Eat to handle term codes in program output
  (eat-eshell-visual-command-mode))     ; commands like less will be handled by Eat

;; `eshell-mode-map' is defined in `esh-mode', not `eshell'.
(use-package esh-mode
  :ensure nil
  :bind (:map eshell-mode-map ("C-r" . consult-history)))

(defun eshell-other-window ()
  "Create or visit an eshell buffer."
  (interactive)
  (if (not (get-buffer "*eshell*"))
    (progn
      (split-window-sensibly (selected-window))
      (other-window 1)
      (eshell))
    (switch-to-buffer-other-window "*eshell*")))

;;
;; GHOSTEL (replaces vterm / multi-vterm / vterm-toggle)
;;
;; Ghostel package itself is installed in apps/dl-ghostel.el.
;; Key bindings for ghostel live in dl-keymap.el under my-term-map (C-c m).

(defun my/ghostel-named (name)
  "Open or create a ghostel terminal buffer named for NAME."
  (interactive "sGhostel name: ")
  (let ((ghostel-buffer-name (format "*ghostel:%s*" name)))
    (ghostel)))

(defun my/ghostel-here ()
  "Open a fresh ghostel terminal at the current `default-directory'."
  (interactive)
  (ghostel '(4)))

(add-to-list 'display-buffer-alist
  '((major-mode . ghostel-mode)
     (display-buffer-reuse-mode-window display-buffer-at-bottom)
     (dedicated . t)
     (reusable-frames . visible)
     (window-height . 0.3)))

(provide 'dl-term)
;;; dl-term.el ends here
