;;; dl-term.el --- terminals -*- lexical-binding: t; -*-

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
  ( ("C-c t t" . multi-vterm)
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
(require 'subr-x)
(require 'seq)

(defgroup dl-shpool nil
  "Persistent vterm sessions via shpool."
  :group 'terminals)

(defcustom dl-shpool-command "shpool"
  "Command used to invoke shpool."
  :type 'string)

(defcustom dl-shpool-known-sessions nil
  "Known shpool session names.

This list is updated by `my/shpool' when you create or attach to
sessions interactively. It is only a local completion cache; live
sessions are also read from `shpool list'."
  :type '(repeat string))

(defcustom dl-shpool-restore-sessions nil
  "Shpool sessions to restore with `my/shpool-restore'.

Unlike `dl-shpool-known-sessions', this is the intentional restore list,
not every session you have ever opened. Use `my/shpool-add-current-to-restore'
to add sessions to it."
  :type '(repeat string))

(defcustom dl-shpool-auto-restore nil
  "When non-nil, restore `dl-shpool-restore-sessions' after Emacs startup."
  :type 'boolean)

(defun my/shpool-buffer-name (name)
  "Return vterm buffer name for shpool session NAME."
  (format "*shpool:%s*" name))

(defun my/shpool--command-output (&rest args)
  "Return output from running `dl-shpool-command' with ARGS.

Captures stderr as well as stdout so CLI failures are visible from
Emacs."
  (string-trim
    (shell-command-to-string
      (concat
        (mapconcat #'shell-quote-argument
          (cons dl-shpool-command args)
          " ")
        " 2>&1"))))

(defun my/shpool--list-output ()
  "Return raw output from `shpool list'."
  (my/shpool--command-output "list"))

(defun my/shpool-live-sessions ()
  "Return live shpool session names from `shpool list'.

This parser treats the first field of each non-empty, non-header line as
the session name."
  (let ((output (my/shpool--list-output)))
    (seq-filter
      (lambda (session)
        (and (not (string-empty-p session))
          (not (member session '("name" "NAME" "session" "SESSION")))))
      (mapcar
        (lambda (line)
          (car (split-string (string-trim line) "[[:space:]]+" t)))
        (split-string output "\n" t)))))

(defun my/shpool-session-candidates ()
  "Return shpool session candidates for completion.

This merges live sessions from shpool with locally remembered sessions
and restore-listed sessions."
  (sort
    (delete-dups
      (append (ignore-errors (my/shpool-live-sessions))
        dl-shpool-known-sessions
        dl-shpool-restore-sessions))
    #'string-lessp))

(defun my/shpool--session-name-at-point ()
  "Return a plausible shpool session name from context."
  (or (when-let* ((project (project-current nil))
                   (root (project-root project)))
        (file-name-nondirectory
          (directory-file-name root)))
    (buffer-name)))

(defun my/shpool-read-session-name (&optional prompt)
  "Read a shpool session name, asking PROMPT, with completion.

Existing live and remembered sessions are offered as completions, but
new names are allowed because this command is also used to create
sessions. The default is derived from the current project when available."
  (let* ((default (my/shpool--session-name-at-point))
          (candidates (my/shpool-session-candidates))
          (input
            (completing-read
              (if default
                (format "%s (default %s): "
                  (or prompt "Shpool session")
                  default)
                (format "%s: " (or prompt "Shpool session")))
              candidates
              nil nil nil nil default)))
    (string-trim input)))

(defun my/shpool--remember-session (name)
  "Remember shpool session NAME for future completion."
  (when (and name (not (string-empty-p name)))
    (add-to-list 'dl-shpool-known-sessions name)
    (customize-save-variable
      'dl-shpool-known-sessions
      dl-shpool-known-sessions)))

(defun my/shpool--forget-session (name)
  "Remove NAME from local shpool session registries."
  (setq dl-shpool-known-sessions
    (delete name dl-shpool-known-sessions))
  (setq dl-shpool-restore-sessions
    (delete name dl-shpool-restore-sessions))
  (customize-save-variable
    'dl-shpool-known-sessions
    dl-shpool-known-sessions)
  (customize-save-variable
    'dl-shpool-restore-sessions
    dl-shpool-restore-sessions))

(defun my/shpool--send-command (command)
  "Send COMMAND to the current vterm and press return."
  (vterm-send-string command)
  (vterm-send-return))

(defun my/shpool-attach-command (name)
  "Return shell command to attach to shpool session NAME.

If the old Emacs died without detaching cleanly, attach can fail because
shpool still thinks another client is attached. In that case, detach once
and retry attach.

The `-D' flag assumes the shpool daemon is already running, for example
via a systemd user service."
  (format "%s attach %s -D || (%s detach %s; %s attach %s)"
    dl-shpool-command
    (shell-quote-argument name)
    dl-shpool-command
    (shell-quote-argument name)
    dl-shpool-command
    (shell-quote-argument name)))

(defun my/shpool (name)
  "Open or create a vterm attached to persistent shpool session NAME."
  (interactive (list (my/shpool-read-session-name)))
  (unless (and name (not (string-empty-p name)))
    (user-error "Empty shpool session name"))
  (my/shpool--remember-session name)
  (let ((buf-name (my/shpool-buffer-name name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name)
      (my/shpool--send-command (my/shpool-attach-command name)))))

(defun my/shpool-project ()
  "Open a project-named persistent shpool session."
  (interactive)
  (let* ((project (project-current t))
          (root (project-root project))
          (name (file-name-nondirectory
                  (directory-file-name root)))
          (default-directory root))
    (my/shpool name)))

(defun my/shpool-current-session-name ()
  "Return current shpool session name based on buffer name."
  (if (string-match "\\`\\*shpool:\\(.+\\)\\*\\'"
        (buffer-name))
    (match-string 1 (buffer-name))
    (user-error "Current buffer is not a shpool buffer")))

(defun my/shpool-rename-buffer ()
  "Rename current shpool vterm buffer.

This does not rename the underlying shpool session. It only changes the
Emacs buffer name."
  (interactive)
  (unless (derived-mode-p 'vterm-mode)
    (user-error "Current buffer is not a vterm buffer"))
  (rename-buffer
    (my/shpool-buffer-name
      (my/shpool-read-session-name "Rename buffer to shpool session"))
    t))

(defun my/shpool-add-current-to-restore ()
  "Add current shpool buffer's session to `dl-shpool-restore-sessions'."
  (interactive)
  (let ((name (my/shpool-current-session-name)))
    (add-to-list 'dl-shpool-restore-sessions name)
    (add-to-list 'dl-shpool-known-sessions name)
    (customize-save-variable
      'dl-shpool-restore-sessions
      dl-shpool-restore-sessions)
    (customize-save-variable
      'dl-shpool-known-sessions
      dl-shpool-known-sessions)
    (message "Added %s to shpool restore sessions" name)))

(defun my/shpool-remove-from-restore (name)
  "Remove shpool session NAME from `dl-shpool-restore-sessions'."
  (interactive
    (list
      (if dl-shpool-restore-sessions
        (completing-read "Remove restore session: "
          dl-shpool-restore-sessions
          nil t)
        (user-error "No shpool restore sessions configured"))))
  (setq dl-shpool-restore-sessions
    (delete name dl-shpool-restore-sessions))
  (customize-save-variable
    'dl-shpool-restore-sessions
    dl-shpool-restore-sessions)
  (message "Removed %s from shpool restore sessions" name))

(defun my/shpool-detach-current ()
  "Detach current shpool session and kill its vterm buffer.

This does not kill the persistent shpool session."
  (interactive)
  (let ((name (my/shpool-current-session-name)))
    (when (derived-mode-p 'vterm-mode)
      (my/shpool--send-command
        (format "%s detach %s"
          dl-shpool-command
          (shell-quote-argument name))))
    (kill-buffer)))

(defun my/shpool-kill-session (name)
  "Kill persistent shpool session NAME and remove it from local registries."
  (interactive
    (list
      (completing-read "Kill shpool session: "
        (my/shpool-session-candidates)
        nil t)))
  (unless (and name (not (string-empty-p name)))
    (user-error "Empty shpool session name"))
  (when (yes-or-no-p (format "Kill persistent shpool session %S? " name))
    (let ((output (my/shpool--command-output "kill" name)))
      (when-let ((vterm-buf (get-buffer (my/shpool-buffer-name name))))
        (kill-buffer vterm-buf))
      (my/shpool--forget-session name)
      (if (string-empty-p output)
        (message "Killed shpool session: %s" name)
        (message "Killed shpool session: %s -- %s" name output)))))

(defun my/shpool-forget-session (name)
  "Forget local record of shpool session NAME.

This does not kill the real shpool session."
  (interactive
    (list
      (completing-read "Forget local shpool session: "
        (sort
          (delete-dups
            (append dl-shpool-known-sessions
              dl-shpool-restore-sessions))
          #'string-lessp)
        nil t)))
  (my/shpool--forget-session name)

  (message "Forgot local shpool session: %s" name))

(defun my/shpool-list ()
  "Show `shpool list` output."
  (interactive)
  (let ((buf (get-buffer-create "*shpool-list*"))
         (output (my/shpool--list-output)))
    (with-current-buffer buf
      (read-only-mode -1)
      (erase-buffer)
      (insert output)
      (unless (bolp)
        (insert "\n"))
      (goto-char (point-min))
      (special-mode))
    (pop-to-buffer buf)))

(defun my/shpool-restore ()
  "Restore sessions listed in `dl-shpool-restore-sessions'."
  (interactive)
  (if dl-shpool-restore-sessions
    (dolist (name dl-shpool-restore-sessions)
      (my/shpool name))
    (message "No shpool restore sessions configured")))

(when dl-shpool-auto-restore
  (add-hook 'emacs-startup-hook #'my/shpool-restore))

(global-set-key (kbd "C-c t a") #'my/shpool)          ;; attach/create by name
(global-set-key (kbd "C-c t p") #'my/shpool-project)  ;; project-named session
(global-set-key (kbd "C-c t r") #'my/shpool-restore)
(global-set-key (kbd "C-c t L") #'my/shpool-list)
(global-set-key (kbd "C-c t d") #'my/shpool-detach-current)
(global-set-key (kbd "C-c t k") #'my/shpool-kill-session)
(global-set-key (kbd "C-c t +") #'my/shpool-add-current-to-restore)
(global-set-key (kbd "C-c t -") #'my/shpool-remove-from-restore)
(global-set-key (kbd "C-c t f") #'my/shpool-forget-session)

(provide 'dl-term)
;;; dl-term.el ends here
