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

;;
;; VTERM + SHPOOL
;;
(require 'subr-x)

(defgroup dl-shpool nil
  "Persistent vterm sessions via shpool."
  :group 'terminals)

(defcustom dl-shpool-command "shpool"
  "Command used to invoke shpool."
  :type 'string)

(defcustom dl-shpool-known-sessions nil
  "Known shpool session names.

This list is updated by `dl/shpool' when you create or attach to
sessions interactively."
  :type '(repeat string))

(defcustom dl-shpool-restore-sessions nil
  "Shpool sessions to restore with `dl/shpool-restore'.

Unlike `dl-shpool-known-sessions', this is the intentional restore list,
not every session you have ever opened."
  :type '(repeat string))

(defcustom dl-shpool-auto-restore nil
  "When non-nil, restore `dl-shpool-restore-sessions' after Emacs startup."
  :type 'boolean)

(defun dl/shpool-buffer-name (name)
  "Return vterm buffer name for shpool session NAME."
  (format "*shpool:%s*" name))

(defun dl/shpool--session-name-at-point ()
  "Return a plausible shpool session name from context."
  (or (when-let* ((project (project-current nil))
                   (root (project-root project)))
        (file-name-nondirectory
          (directory-file-name root)))
    (buffer-name)))

(defun dl/shpool-read-session-name (&optional prompt)
  "Read a shpool session name with completion.

The default is derived from the current project when available."
  (let* ((default (dl/shpool--session-name-at-point))
          (input
            (completing-read
              (if default
                (format "%s (default %s): "
                  (or prompt "Shpool session")
                  default)
                (format "%s: " (or prompt "Shpool session")))
              dl-shpool-known-sessions
              nil nil nil nil default)))
    (string-trim input)))

(defun dl/shpool--remember-session (name)
  "Remember shpool session NAME for future completion."
  (when (and name (not (string-empty-p name)))
    (add-to-list 'dl-shpool-known-sessions name)
    (customize-save-variable
      'dl-shpool-known-sessions
      dl-shpool-known-sessions)))

(defun dl/shpool--send-command (command)
  "Send COMMAND to the current vterm and press return."
  (vterm-send-string command)
  (vterm-send-return))

(defun dl/shpool-attach-command (name)
  "Return shell command to attach to shpool session NAME.

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
  (interactive (list (dl/shpool-read-session-name)))
  (unless (and name (not (string-empty-p name)))
    (user-error "Empty shpool session name"))
  (dl/shpool--remember-session name)
  (let ((buf-name (dl/shpool-buffer-name name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name)
      (dl/shpool--send-command (dl/shpool-attach-command name)))))

(defun dl/shpool-project ()
  "Open a project-named persistent shpool session."
  (interactive)
  (let* ((project (project-current t))
          (root (project-root project))
          (name (file-name-nondirectory
                  (directory-file-name root)))
          (default-directory root))
    (dl/shpool name)))

(defun dl/shpool-rename-buffer ()
  "Rename current shpool vterm buffer.

This does not rename the underlying shpool session. It only changes the
Emacs buffer name."
  (interactive)
  (unless (derived-mode-p 'vterm-mode)
    (user-error "Current buffer is not a vterm buffer"))
  (rename-buffer
    (dl/shpool-buffer-name
      (dl/shpool-read-session-name "Rename buffer to shpool session"))
    t))

(defun dl/shpool-add-current-to-restore ()
  "Add current shpool buffer's session to `dl-shpool-restore-sessions'."
  (interactive)
  (let ((name (dl/shpool-current-session-name)))
    (add-to-list 'dl-shpool-restore-sessions name)
    (customize-save-variable
      'dl-shpool-restore-sessions
      dl-shpool-restore-sessions)
    (message "Added %s to shpool restore sessions" name)))

(defun dl/shpool-remove-from-restore (name)
  "Remove shpool session NAME from `dl-shpool-restore-sessions'."
  (interactive
    (list
      (completing-read "Remove restore session: "
        dl-shpool-restore-sessions
        nil t)))
  (setq dl-shpool-restore-sessions
    (delete name dl-shpool-restore-sessions))
  (customize-save-variable
    'dl-shpool-restore-sessions
    dl-shpool-restore-sessions)
  (message "Removed %s from shpool restore sessions" name))

(defun dl/shpool-current-session-name ()
  "Return current shpool session name based on buffer name."
  (if (string-match "\\`\\*shpool:\\(.+\\)\\*\\'"
        (buffer-name))
    (match-string 1 (buffer-name))
    (user-error "Current buffer is not a shpool buffer")))

(defun dl/shpool-detach-current ()
  "Detach current shpool session and kill its vterm buffer.

This does not kill the persistent shpool session."
  (interactive)
  (let ((name (dl/shpool-current-session-name)))
    (when (derived-mode-p 'vterm-mode)
      (dl/shpool--send-command
        (format "%s detach %s"
          dl-shpool-command
          (shell-quote-argument name))))
    (kill-buffer)))

(defun dl/shpool-kill-session (name)
  "Kill persistent shpool session NAME."
  (interactive
    (list
      (completing-read "Kill shpool session: "
        dl-shpool-known-sessions
        nil nil)))
  (unless (and name (not (string-empty-p name)))
    (user-error "Empty shpool session name"))
  (when (yes-or-no-p (format "Kill persistent shpool session %S? " name))
    (let ((buf (get-buffer-create "*shpool-command*")))
      (with-current-buffer buf
        (erase-buffer))
      (call-process dl-shpool-command nil buf nil "kill" name)
      (when-let ((vterm-buf (get-buffer (dl/shpool-buffer-name name))))
        (kill-buffer vterm-buf))
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

(defun dl/shpool-restore ()
  "Restore sessions listed in `dl-shpool-restore-sessions'."
  (interactive)
  (if dl-shpool-restore-sessions
    (dolist (name dl-shpool-restore-sessions)
      (dl/shpool name))
    (message "No shpool restore sessions configured")))

(when dl-shpool-auto-restore
  (add-hook 'emacs-startup-hook #'dl/shpool-restore))

(global-set-key (kbd "C-c t a") #'dl/shpool)          ;; attach/create by name
(global-set-key (kbd "C-c t p") #'dl/shpool-project)  ;; project-named session
(global-set-key (kbd "C-c t r") #'dl/shpool-restore)
(global-set-key (kbd "C-c t L") #'dl/shpool-list)
(global-set-key (kbd "C-c t d") #'dl/shpool-detach-current)
(global-set-key (kbd "C-c t k") #'dl/shpool-kill-session)
(global-set-key (kbd "C-c t +") #'dl/shpool-add-current-to-restore)
(global-set-key (kbd "C-c t -") #'dl/shpool-remove-from-restore)

(provide 'dl-term)
