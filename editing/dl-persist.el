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
;; Revisiting: point restore, auto-revert
;;
(use-package saveplace
  :init
  (save-place-mode 1))

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

;; --------------------------------------------------------------------------------
;; AUTOSAVE -- aggressively
;;
;; Save every modified file buffer on window buffer switch, frame focus
;; loss, and 30s idle.  Switches come from `window-buffer-change-functions',
;; so temp-buffer churn (dabbrev, completion preview) never triggers a save.
(defun my/autosave-composing-p ()
  "Non-nil in an in-progress commit message or other with-editor session."
  (or (bound-and-true-p git-commit-mode)
    (bound-and-true-p with-editor-mode)))

(use-package super-save
  :ensure t
  :custom
  (super-save-all-buffers t)
  (super-save-auto-save-when-idle t)
  (super-save-idle-duration 30)
  (super-save-remote-files nil)
  :config
  (add-to-list 'super-save-predicates
    (lambda () (not (my/autosave-composing-p))) t)
  (super-save-mode +1))

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
