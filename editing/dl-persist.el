;;; dl-persist.el --- File Save & Revert -*- lexical-binding: t; -*-

;; File Revert

(use-package emacs
  :ensure nil
  :custom
  ;; Automatically reread from disk
  ;; if the underlying file changes
  (auto-revert-avoid-polling t)
  (auto-revert-interval 3)
  (auto-revert-check-vc-info t)
  (global-auto-revert-non-file-buffers t)
  (global-auto-revert-mode)
  ;; history & recent files
  (history-length 80)
  (save-place-mode 1)) ; dired, etc

;; eglot auto-format with error handling

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
