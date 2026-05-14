;;; dl-persist.el --- File Save & Revert -*- lexical-binding: t; -*-

;; File Revert

(use-package emacs
  :ensure nil
  :custom
  (auto-revert-avoid-polling nil)
  (auto-revert-interval 1)
  (global-auto-revert-non-file-buffers t)
  ;; (auto-revert-check-vc-info t)
  :config
  (global-auto-revert-mode 1))

(use-package
  emacs :ensure nil
  :custom
  ;; history & recent files
  (history-length 80)
  (save-place-mode 1)
  (desktop-save-mode 1)
  (desktop-restore-frames nil))

;; Autosave Aggressively
;; Save visited files on buffer/window/frame focus loss.
(add-hook 'buffer-list-update-hook #'my/save-buffer-on-focus-change)
(add-hook 'focus-out-hook #'my/save-all-file-buffers)

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
             (not (string-prefix-p " " (buffer-name))))
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

;; (add-hook 'before-save-hook #'my/eglot-format-buffer-if-connected)
;; (add-hook 'before-save-hook #'my/eglot-organize-imports-if-connected)

(use-package recentf
  :init
  (recentf-mode 1)
  :custom
  (recentf-max-saved-items 200))

(use-package saveplace
  :init
  (save-place-mode 1))

(use-package undo-fu)

(use-package undo-fu-session
  :config
  (undo-fu-session-global-mode))

(use-package vundo
  :bind (("C-x u" . vundo)))

(provide 'dl-persist)
