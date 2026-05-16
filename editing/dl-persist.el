;;; dl-persist.el --- File Save & Revert -*- lexical-binding: t; -*-

;; --------------------------------------------------------------------------------
;; Buffer cleanup
;;
(use-package buffer-terminator
  :custom
  (buffer-terminator-verbose nil)

  (buffer-terminator-inactivity-timeout (* 45 60)) ; 45 minutes
  (buffer-terminator-interval (* 5 60)) ; run every   5 minutes

  :config
  (buffer-terminator-mode 1))

;; --------------------------------------------------------------------------------
;; Session Management
;;
;; https://github.com/jamescherti/easysession.el
;;
(use-package easysession
  :demand t ;; on startup

  :config
  ;; Key mappings
  (global-set-key (kbd "C-c sl") #'easysession-switch-to) ; Load session
  (global-set-key (kbd "C-c ss") #'easysession-save) ; Save session
  (global-set-key (kbd "C-c sL") #'easysession-switch-to-and-restore-geometry)
  (global-set-key (kbd "C-c sr") #'easysession-rename)
  (global-set-key (kbd "C-c sR") #'easysession-reset)
  (global-set-key (kbd "C-c su") #'easysession-unload)
  (global-set-key (kbd "C-c sd") #'easysession-delete)

  ;; Save every 10 minutes
  (setq easysession-save-interval (* 10 60))

  ;; Save the current session when using `easysession-switch-to'
  (setq easysession-switch-to-save-session t)

  ;; Do not exclude the current session when switching sessions
  (setq easysession-switch-to-exclude-current nil)

  ;; Display the active session name in the mode-line lighter.
  ;; (setq easysession-save-mode-lighter-show-session-name t)

  ;; Optionally, the session name can be shown in the modeline info area:
  ;; (setq easysession-mode-line-misc-info t)
  ;; non-nil: Make `easysession-setup' load the session automatically.
  ;; (nil: session is not loaded automatically; the user can load it manually.)
  (setq easysession-setup-load-session t)

  ;; The `easysession-setup' function adds hooks:
  ;; - To enable automatic session loading during `emacs-startup-hook', or
  ;;   `server-after-make-frame-hook' when running in daemon mode.
  ;; - To save the session at regular intervals, and when Emacs exits.
  (easysession-setup))

;; File Revert


;; (use-package saveplace
;;   :init
;;   (save-place-mode 1))


(use-package emacs
  :ensure nil
  :custom
  (auto-revert-avoid-polling nil)
  (auto-revert-interval 3)
  (global-auto-revert-non-file-buffers t)
  ;; history & recent files
  (history-length 80)
  :config
  (global-auto-revert-mode 1))

;; (use-package
;;   emacs :ensure nil
;;   :custom
;;   (save-place-mode 1)                   ;
;;   (desktop-save-mode 1)
;;   (desktop-restore-frames nil)
;;   ;; Don't let desktop resurrect spell-checking — jinx is opt-in only.
;;   ;; nil handler means "skip this minor mode on restore".
;;   (desktop-minor-mode-table '((jinx-mode nil))))

;; --------------------------------------------------------------------------------
;; AUTOSAVE -- aggressively
;;
(defun my/save-buffer-on-focus-change ()
  "Save the previously current file buffer when switching buffers."
  (when-let ((buf (other-buffer (current-buffer) t)))
    (when (buffer-live-p buf)
      (with-current-buffer buf
        (my/save-buffer-if-reasonable)))))

(defun my/save-buffer-if-reasonable ()
  "Save current buffer if it is a normal modified file buffer."
  (when (and buffer-file-name
          (buffer-modified-p)
          (file-writable-p buffer-file-name)
          ;; Avoid saving remote/TRAMP buffers automatically.
          (not (file-remote-p buffer-file-name))
          ;; Avoid saving temporary/special buffers.
          (not (string-prefix-p " " (buffer-name)))
          ;; Never autosave in-progress commit messages or other
          ;; with-editor sessions; the user hasn't finished composing.
          (not (derived-mode-p 'git-commit-mode 'with-editor-mode)))
    (save-buffer)))

(defun my/save-all-file-buffers ()
  "Save all reasonable file buffers."
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (my/save-buffer-if-reasonable))))

;;; Save after idle time

(defvar my/auto-save-idle-timer nil)

(defun my/auto-save-after-idle ()
  "Save all reasonable file buffers after idle time."
  (my/save-all-file-buffers))

(setq my/auto-save-idle-timer
  (run-with-idle-timer 30 t #'my/auto-save-after-idle))

;; Autosave Aggressively
;; Save visited files on buffer/window/frame focus loss.
(add-hook 'buffer-list-update-hook #'my/save-buffer-on-focus-change)
(add-hook 'after-focus-change-function #'my/save-all-file-buffers)

;; --------------------------------------------------------------------------------
;; Eglot
;;

;; auto whitespace
;; (add-fs-to-hook 'prog-mode-hook
;;   (add-hook 'after-save-hook
;;     (fn (whitespace-cleanup))))

;; Eglot - auto-format with error handling
;;

(defun my/eglot-connected-p ()
  "Return non-nil when current buffer has a live Eglot server."
  (and (bound-and-true-p eglot--managed-mode)
    (ignore-errors
	    (eglot-current-server))))

(defun my/eglot-format-buffer-if-connected ()
  (when (my/eglot-connected-p)
    (eglot-format-buffer)))

(defun my/eglot-organize-imports-if-connected ()
  (when (my/eglot-connected-p)
    (eglot-code-action-organize-imports)))

(defun my/eglot-on-save-setup ()
  (add-hook 'before-save-hook #'my/eglot-format-buffer-if-connected nil t))

(add-hook 'eglot-managed-mode-hook #'my/eglot-on-save-setup)

(add-hook 'before-save-hook #'my/eglot-format-buffer-if-connected)
(add-hook 'before-save-hook #'my/eglot-organize-imports-if-connected)

;; --------------------------------------------------------------------------------
;; Undo / Redo
;;
(use-package undo-fu)

(use-package undo-fu-session
  :config
  (undo-fu-session-global-mode))

(use-package vundo
  :bind (("C-x u" . vundo)))

(provide 'dl-persist)
