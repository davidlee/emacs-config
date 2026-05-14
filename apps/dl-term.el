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
  (defun bedrock/setup-eshell ()
    ;; Something funny is going on with how Eshell sets up its keymaps; this is
    ;; a work-around to make C-r bound in the keymap
    (keymap-set eshell-mode-map "C-r" 'consult-history))
  :hook ((eshell-mode . bedrock/setup-eshell)))

;;
;; ESHELL
;;
;; (defun eshell/sudo-open (filename)
;;   "Open a file as root in Eshell."
;;   (let ((qual-filename (if (string-match "^/" filename)
;;                          filename
;;                          (concat (expand-file-name (eshell/pwd)) "/" filename))))
;;     (switch-to-buffer
;;       (find-file-noselect
;;         (concat "/sudo::" qual-filename)))))


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
;; VTERM
;;

(use-package vterm
  :commands
  vterm
  :custom
  (vterm-kill-buffer-on-exit t)
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :after vterm
  :bind
  ( ("C-c t t" . multi-vterm)
    ("C-c t n" . multi-vterm-next)
    ("C-c t p" . multi-vterm-prev)))

(defun my/vterm-named (name)
  "Open or create a named (for NAME) vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name))))

;;
;;
;;

(use-package vterm-toggle
  :custom
  (vterm-toggle-hide-method 'delete-window)
  (vterm-toggle-fullscreen-p nil)
  :init
  (add-to-list 'display-buffer-alist
    '((lambda (buffer-or-name _)
        (let ((buffer (get-buffer buffer-or-name)))
          (equal major-mode 'vterm-mode)))
       (display-buffer-reuse-window display-buffer-at-bottom)
       (dedicated . t)
       (reusable-frames . visible)
       (window-height . 0.3))))

(defun vterm--kill-vterm-buffer-and-window (process event)
  "Kill buffer and window on vterm process termination."
  (when (not (process-live-p process))
    (let ((buf (process-buffer process)))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (kill-buffer)
          (ignore-errors (delete-window))
          (message "VTerm closed."))))))

;;
;;
;;

(global-set-key (kbd "C-c t a") #'my/shpool)          ;; attach/create by name
(global-set-key (kbd "C-c t p") #'my/shpool-project)  ;; project-named session
(global-set-key (kbd "C-c t F") #'my/shpool-force)    ;; force attach/create by name
(global-set-key (kbd "C-c t r") #'my/shpool-restore)
(global-set-key (kbd "C-c t L") #'my/shpool-list)
(global-set-key (kbd "C-c t d") #'my/shpool-detach-current)
(global-set-key (kbd "C-c t k") #'my/shpool-kill-session)
(global-set-key (kbd "C-c t +") #'my/shpool-add-current-to-restore)
(global-set-key (kbd "C-c t -") #'my/shpool-remove-from-restore)
(global-set-key (kbd "C-c t f") #'my/shpool-forget-session)

(provide 'dl-term)
;;; dl-term.el ends here
