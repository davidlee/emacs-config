;;; dl-term.el --- terminals -*- lexical-binding: t; -*-

;;
;; EAT
;;

(use-package eat
  :custom
  (eat-term-name "xterm")
  (eat-eshell-mode)                     ; use Eat to handle term codes in program output
  (eat-eshell-visual-command-mode))     ; commands like less will be handled by Eat

(use-package eshell
  :init
  (defun my/setup-eshell ()
    ;; Something funny is going on with how Eshell sets up its keymaps; this is
    ;; a work-around to make C-r bound in the keymap
    (keymap-set eshell-mode-map "C-r" 'consult-history))
  :hook ((eshell-mode . my/setup-eshell)))

(defun eshell-other-window ()
  "Create or visit an eshell buffer."
  (interactive)
  (if (not (get-buffer "*eshell*"))
    (progn
      (split-window-sensibly (selected-window))
      (other-window 1)
      (eshell))
    (switch-to-buffer-other-window "*eshell*")))

(global-set-key (kbd "<s-C-return>") 'eshell-other-window)

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

(defun my/ghostel-toggle ()
  "Pop to a ghostel buffer; bury it when already selected.
Cycles via `ghostel-other' so repeated invocations walk the ghostel
buffer list. Creates a new terminal if none exist."
  (interactive)
  (if (derived-mode-p 'ghostel-mode)
    (bury-buffer)
    (let ((buf (seq-find (lambda (b)
                           (with-current-buffer b
                             (derived-mode-p 'ghostel-mode)))
                 (buffer-list))))
      (if buf (pop-to-buffer buf) (ghostel)))))

(defun my/ghostel-here ()
  "Open a fresh ghostel terminal at the current `default-directory'."
  (interactive)
  (ghostel '(4)))

(global-set-key [C-f1] #'my/ghostel-toggle)
(global-set-key [C-f2] #'my/ghostel-here)

(add-to-list 'display-buffer-alist
  '((major-mode . ghostel-mode)
     (display-buffer-reuse-mode-window display-buffer-at-bottom)
     (dedicated . t)
     (reusable-frames . visible)
     (window-height . 0.3)))

(provide 'dl-term)
;;; dl-term.el ends here
