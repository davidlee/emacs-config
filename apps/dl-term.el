;;; dl-term.el --- terminals -*- lexical-binding: t; -*-


(setq dl-shpool-sessions '("main" "claude"))
(setq dl-shpool-auto-restore nil)
                                        ; (setq dl-shpool-auto-restore t)

;;
;; EAT
;;

(use-package eat
  :ensure t
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
(defun eshell/sudo-open (filename)
  "Open a file as root in Eshell."
  (let ((qual-filename (if (string-match "^/" filename)
                         filename
                         (concat (expand-file-name (eshell/pwd)) "/" filename))))
    (switch-to-buffer
      (find-file-noselect
        (concat "/sudo::" qual-filename)))))


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
  :ensure t
  :commands vterm
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :ensure t
  :after vterm
  :bind
  (("C-c t t" . multi-vterm)
    ("C-c t n" . multi-vterm-next)
    ("C-c t p" . multi-vterm-prev)))

;; (defun my/vterm-named (name)
;;   "Open or create a named vterm buffer."
;;   (interactive "sVTerm name: ")
;;   (let ((buf-name (format "*vterm:%s*" name)))
;;     (if (get-buffer buf-name)
;;       (pop-to-buffer buf-name)
;;       (let ((vterm-buffer-name buf-name))
;;         (vterm)))))

;; (global-set-key (kbd "C-c t s")
;;                 (lambda () (interactive) (my/vterm-named "server")))

;; (global-set-key (kbd "C-c t c")
;;                 (lambda () (interactive) (my/vterm-named "claude")))

;; (global-set-key (kbd "C-c t l")
;;                 (lambda () (interactive) (my/vterm-named "logs")))


(defun my/vterm-named (name)
  "Open or create a named vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
        (pop-to-buffer buf-name)
      (vterm buf-name))))

;;
;; VTERM + SHPOOL
;;

(defgroup dl-shpool nil
  "Persistent vterm sessions via shpool."
  :group 'terminals)

(defcustom dl-shpool-command "shpool"
  "Command used to invoke shpool."
  :type 'string)

(defcustom dl-shpool-sessions
  '("main" "claude" "server" "logs")
  "Named shpool sessions to restore."
  :type '(repeat string))

(defcustom dl-shpool-auto-restore nil
  "When non-nil, restore `dl-shpool-sessions' after Emacs startup."
  :type 'boolean)

(defun dl/shpool-buffer-name (name)
  "Return vterm buffer name for shpool session NAME."
  (format "*shpool:%s*" name))

(defun dl/shpool--send-command (command)
  "Send COMMAND to the current vterm and press return."
  (vterm-send-string command)
  (vterm-send-return))

(defun dl/shpool-attach-command (name)
  "Return shell command to attach to shpool session NAME.

`shpool attach NAME` creates/attaches to a named persistent session.
If the old Emacs died without detaching cleanly, attach can fail because
shpool still thinks another client is attached. In that case, detach once
and retry attach."
  (format "%s attach %s || (%s detach %s; %s attach %s)"
    dl-shpool-command
    (shell-quote-argument name)
    dl-shpool-command
    (shell-quote-argument name)
    dl-shpool-command
    (shell-quote-argument name)))

(defun dl/shpool (name)
  "Open or create a vterm attached to persistent shpool session NAME."
  (interactive
   (list
    (completing-read "Shpool session: "
                     dl-shpool-sessions
                     nil nil nil nil
                     "main")))
  (let ((buf-name (dl/shpool-buffer-name name)))
    (if (get-buffer buf-name)
        (pop-to-buffer buf-name)
      (vterm buf-name)
      (dl/shpool--send-command (dl/shpool-attach-command name)))))

(defun dl/shpool-main ()
  "Open the main shpool session."
  (interactive)
  (dl/shpool "main"))

(defun dl/shpool-claude ()
  "Open the claude shpool session."
  (interactive)
  (dl/shpool "claude"))

(defun dl/shpool-server ()
  "Open the server shpool session."
  (interactive)
  (dl/shpool "server"))

(defun dl/shpool-logs ()
  "Open the logs shpool session."
  (interactive)
  (dl/shpool "logs"))

(defun dl/shpool-restore ()
  "Restore all configured shpool vterm buffers."
  (interactive)
  (dolist (name dl-shpool-sessions)
    (dl/shpool name)))

(defun dl/shpool-kill-buffer-and-detach ()
  "Detach the current shpool session if this is a shpool vterm buffer, then kill it.

This only detaches the client. It does not kill the persistent shpool
session."
  (interactive)
  (let ((buf (current-buffer)))
    (if-let* ((name (and (string-match "\\`\\*shpool:\\(.+\\)\\*\\'"
                           (buffer-name buf))
                      (match-string 1 (buffer-name buf)))))
      (progn
        (when (derived-mode-p 'vterm-mode)
          (dl/shpool--send-command
            (format "%s detach %s"
              dl-shpool-command
              (shell-quote-argument name))))
        (kill-buffer buf))
      (user-error "Current buffer is not a shpool vterm buffer"))))

(defun dl/shpool-kill-session (name)
  "Kill persistent shpool session NAME."
  (interactive
    (list
      (completing-read "Kill shpool session: "
        dl-shpool-sessions
        nil nil nil nil
        "main")))
  (when (yes-or-no-p (format "Kill persistent shpool session %S? " name))
    (let ((buf (get-buffer-create "*shpool-command*")))
      (with-current-buffer buf
        (erase-buffer))
      (call-process dl-shpool-command nil buf nil "kill" name)
      (message "Killed shpool session: %s" name))))

(defun dl/shpool-list ()
  "Show `shpool list` output."
  (interactive)
  (let ((buf (get-buffer-create "*shpool-list*")))
    (with-current-buffer buf
      (read-only-mode -1)
      (erase-buffer)
      (call-process dl-shpool-command nil buf nil "list")
      (goto-char (point-min))
      (special-mode))
    (pop-to-buffer buf)))

(defun dl/project-shpool ()
  "Open a project-named persistent shpool session."
  (interactive)
  (let* ((project (project-current t))
          (root (project-root project))
          (name (file-name-nondirectory
                  (directory-file-name root)))
          (default-directory root))
    (dl/shpool name)))



(when dl-shpool-auto-restore
  (add-hook 'emacs-startup-hook #'dl/shpool-restore))

;; BINDINGS
;; Persistent terminals.
(global-set-key (kbd "C-c t m") #'dl/shpool-main)
(global-set-key (kbd "C-c t c") #'dl/shpool-claude)
(global-set-key (kbd "C-c t s") #'dl/shpool-server)
(global-set-key (kbd "C-c t l") #'dl/shpool-logs)

;; Session management.
(global-set-key (kbd "C-c t a") #'dl/shpool)
(global-set-key (kbd "C-c t r") #'dl/shpool-restore)
(global-set-key (kbd "C-c t L") #'dl/shpool-list)
(global-set-key (kbd "C-c t d") #'dl/shpool-kill-buffer-and-detach)

(global-set-key (kbd "C-c p t") #'dl/project-shpool)

(provide 'dl-term)
