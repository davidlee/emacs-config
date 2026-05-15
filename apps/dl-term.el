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
  :commands vterm
  :custom
  (vterm-kill-buffer-on-exit t)
  :bind (:map vterm-mode-map
              ("C-c <escape>" . vterm-send-escape))
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))
;; Key bindings for multi-vterm live in dl-keymap.el under my-term-map (C-c m).

(defun my/vterm-named (name)
  "Open or create a named (for NAME) vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name))))

(use-package vterm-toggle
  :custom
  (vterm-toggle-hide-method 'delete-window)
  (vterm-toggle-fullscreen-p nil)
  :bind (([C-f1] . vterm-toggle)
         ([C-f2] . vterm-toggle-cd))
  :init
  (add-to-list 'display-buffer-alist
    '((lambda (buffer-or-name _)
        (let ((buffer (get-buffer buffer-or-name)))
          (equal major-mode 'vterm-mode)))
       (display-buffer-reuse-window display-buffer-at-bottom)
       (dedicated . t)
       (reusable-frames . visible)
       (window-height . 0.3)))
  :config
  ;; vterm-mode-map is owned by vterm; vterm-toggle (require 'vterm)s
  ;; at load time so the map exists by the time :config runs.
  (define-key vterm-mode-map [(control return)] #'vterm-toggle-insert-cd)
  (define-key vterm-mode-map (kbd "M-n")        #'vterm-toggle-forward)
  (define-key vterm-mode-map (kbd "M-p")        #'vterm-toggle-backward))

(defun vterm--kill-vterm-buffer-and-window (process event)
  "Kill buffer and window on vterm process termination."
  (when (not (process-live-p process))
    (let ((buf (process-buffer process)))
      (when (buffer-live-p buf)
        (with-current-buffer buf
          (kill-buffer)
          (ignore-errors (delete-window))
          (message "VTerm closed."))))))


(provide 'dl-term)
;;; dl-term.el ends here
