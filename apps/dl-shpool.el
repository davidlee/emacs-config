;;; dl-shpool.el --- Shell Session Pooler -*- lexical-binding: t; -*-

;;
;; GHOSTEL + SHPOOL
;;
(require 'subr-x)
(require 'seq)
(declare-function ghostel-exec "ghostel" (buffer program &optional args))
(declare-function ghostel-send-string "ghostel" (string))

(defgroup dl-shpool nil
  "Persistent vterm sessions via shpool."
  :group 'terminals)

(defcustom dl-shpool-command "shpool"
  "Command used to invoke shpool."
  :type 'string)

(defcustom dl-shpool-known-sessions nil
  "Known shpool session names.

This is local session name history. It is not authoritative shpool state;
live sessions are read from `shpool list'."
  :type '(repeat string))

(defcustom dl-shpool-restore-sessions nil
  "Shpool sessions to restore with `my/shpool-restore'.

This is the intentional restore list, not every session you have ever
opened. Use `my/shpool-add-current-to-restore' to add sessions to it."
  :type '(repeat string))

(defcustom dl-shpool-auto-restore nil
  "When non-nil, restore `dl-shpool-restore-sessions' after Emacs startup."
  :type 'boolean)

(defvar my/shpool-completion-metadata
  '(metadata
     (category . shpool-session)
     (annotation-function . my/shpool-annotate-session))
  "Completion metadata for shpool session names.")

(defun my/shpool-buffer-name (name)
  "Return ghostel buffer name for shpool session NAME."
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

(defun my/shpool-candidates-with-status ()
  "Return shpool session candidates with status metadata.

Each item is (NAME . PLIST), where PLIST may contain:
  :active     non-nil when present in `shpool list'
  :remembered non-nil when present in `dl-shpool-known-sessions'
  :restore   non-nil when present in `dl-shpool-restore-sessions'."
  (let* ((live (ignore-errors (my/shpool-live-sessions)))
          (all (delete-dups
                 (append live
                   dl-shpool-known-sessions
                   dl-shpool-restore-sessions))))
    (mapcar
      (lambda (name)
        (cons name
          (list :active (member name live)
            :remembered (member name dl-shpool-known-sessions)
            :restore (member name dl-shpool-restore-sessions))))
      (sort all #'string-lessp))))

(defun my/shpool-session-candidates ()
  "Return shpool session candidate names for completion."
  (mapcar #'car (my/shpool-candidates-with-status)))

(defun my/shpool--candidate-status (candidate)
  "Return status plist for shpool completion CANDIDATE."
  (cdr (assoc candidate (my/shpool-candidates-with-status))))

(defun my/shpool--candidate-status-label (candidate)
  "Return display status label for shpool completion CANDIDATE."
  (let* ((meta (my/shpool--candidate-status candidate))
          (active (plist-get meta :active))
          (remembered (plist-get meta :remembered))
          (restore (plist-get meta :restore)))
    (cond
      ((and active restore) "active restore")
      (active "active")
      (restore "restore missing")
      (remembered "remembered")
      (t "new"))))

(defun my/shpool-annotate-session (candidate)
  "Return completion annotation for shpool session CANDIDATE.

This is exposed directly through the completion table metadata, so Vertico can
show useful annotations even if Marginalia does not pick up the custom category."
  (let ((status (my/shpool--candidate-status-label candidate)))
    (concat " " (propertize status 'face 'completions-annotations))))

(defun my/shpool--session-name-at-point ()
  "Return a plausible shpool session name from context."
  (or (when-let* ((project (project-current nil))
                   (root (project-root project)))
        (file-name-nondirectory
          (directory-file-name root)))
    (buffer-name)))

(defun my/shpool--completion-table ()
  "Return a completion table for shpool sessions."
  (let ((candidates (my/shpool-session-candidates)))
    (lambda (string pred action)
      (if (eq action 'metadata)
        my/shpool-completion-metadata
        (complete-with-action action candidates string pred)))))

(defun my/shpool-read-session-name (&optional prompt require-match)
  "Read a shpool session name with completion.

PROMPT is the prompt prefix. When REQUIRE-MATCH is non-nil, only an
existing candidate may be selected. The completion category is
`shpool-session', so Marginalia can annotate active, remembered, and
restore-listed candidates."
  (let* ((default (my/shpool--session-name-at-point))
          (input
            (completing-read
              (if default
                (format "%s (default %s): "
                  (or prompt "Shpool session")
                  default)
                (format "%s: " (or prompt "Shpool session")))
              (my/shpool--completion-table)
              nil require-match nil nil default)))
    (string-trim input)))

;; Keep Marginalia optional. Marginalia 2.x uses `marginalia-annotators'
;; for category registration.
(defvar marginalia-annotators)

(defun my/marginalia-annotate-shpool-session (candidate)
  "Annotate shpool session completion CANDIDATE."
  (concat
    (propertize " " 'display '(space :align-to center))
    (propertize (my/shpool--candidate-status-label candidate)
      'face 'marginalia-documentation)))

(defun my/shpool-marginalia-setup ()
  "Register Marginalia annotations for shpool session completion.

Call this from Marginalia's `:config' block if the automatic
`with-eval-after-load' registration does not run in your setup."
  (interactive)
  (if (boundp 'marginalia-annotators)
    (add-to-list 'marginalia-annotators
      '(shpool-session my/marginalia-annotate-shpool-session builtin none))
    (when (called-interactively-p 'interactive)
      (user-error "Marginalia has not defined `marginalia-annotators' yet"))))

(with-eval-after-load 'marginalia
  (my/shpool-marginalia-setup))

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

(defcustom dl-shpool-debug nil
  "When non-nil, log shpool commands before sending them to vterm."
  :type 'boolean)

(defun my/shpool--log-command (command)
  "Log COMMAND when `dl-shpool-debug' is non-nil."
  (when dl-shpool-debug
    (let ((buf (get-buffer-create "*shpool-debug*")))
      (with-current-buffer buf
        (goto-char (point-max))
        (insert (format "%s %s\n"
                  (format-time-string "%F %T")
                  command))))
    (message "shpool command: %s" command)))

(defun my/shpool--send-command (command)
  "Send COMMAND followed by RET to the current ghostel terminal."
  (my/shpool--log-command command)
  (ghostel-send-string (concat command "\r")))

(defun my/shpool--attach-args (name &optional force)
  "Return argv tail for `shpool attach' on session NAME.
With FORCE non-nil, include the `--force' flag."
  (append '("attach")
    (and force '("--force"))
    (list name)))

(defun my/shpool--open (name &optional force)
  "Open or create ghostel buffer for shpool session NAME.
With FORCE non-nil, force-attach via `shpool attach --force'."
  (unless (and name (not (string-empty-p name)))
    (user-error "Empty shpool session name"))
  (my/shpool--remember-session name)
  (let* ((buf-name (my/shpool-buffer-name name))
          (existing (get-buffer buf-name)))
    (if (and existing (process-live-p (get-buffer-process existing)))
      (pop-to-buffer existing)
      (let ((buf (or existing (get-buffer-create buf-name))))
        (pop-to-buffer buf)
        (ghostel-exec buf dl-shpool-command
          (my/shpool--attach-args name force))))))

(defun my/shpool (name)
  "Open or create a ghostel terminal attached to persistent shpool session NAME."
  (interactive (list (my/shpool-read-session-name)))
  (my/shpool--open name))

(defun my/shpool-force (name)
  "Open or create a ghostel terminal force-attached to persistent shpool session NAME."
  (interactive (list (my/shpool-read-session-name)))
  (my/shpool--open name t))

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
  "Rename current shpool ghostel buffer.

This does not rename the underlying shpool session. It only changes the
Emacs buffer name."
  (interactive)
  (unless (derived-mode-p 'ghostel-mode)
    (user-error "Current buffer is not a ghostel buffer"))
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
  "Detach current shpool session and kill its ghostel buffer.

This does not kill the persistent shpool session."
  (interactive)
  (let ((name (my/shpool-current-session-name)))
    (when (derived-mode-p 'ghostel-mode)
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
      (when-let ((buf (get-buffer (my/shpool-buffer-name name))))
        (kill-buffer buf))
      (my/shpool--forget-session name)
      (if (string-empty-p output)
        (message "Killed shpool session: %s" name)
        (message "Killed shpool session: %s - %s" name output)))))

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

;; Key bindings for shpool live in dl-keymap.el under my-term-map (C-c m).

(provide 'dl-shpool)
;;; dl-shpool.el ends here
