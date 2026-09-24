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
;; (use-package easysession
;;   :demand t ;; on startup

;;   :config
;;   ;; Keybindings live in core/dl-keymap.el under my-session-map (C-c j).

;;   ;; Save every 10 minutes
;;   (setq easysession-save-interval (* 10 60))

;;   ;; Save the current session when using `easysession-switch-to'
;;   (setq easysession-switch-to-save-session t)

;;   ;; Do not exclude the current session when switching sessions
;;   (setq easysession-switch-to-exclude-current nil)

;;   ;; Display the active session name in the mode-line lighter.
;;   ;; (setq easysession-save-mode-lighter-show-session-name t)

;;   ;; Optionally, the session name can be shown in the modeline info area:
;;   ;; (setq easysession-mode-line-misc-info t)
;;   ;; non-nil: Make `easysession-setup' load the session automatically.
;;   ;; (nil: session is not loaded automatically; the user can load it manually.)
;;   (setq easysession-setup-load-session t)

;;   ;; The `easysession-setup' function adds hooks:
;;   ;; - To enable automatic session loading during `emacs-startup-hook', or
;;   ;;   `server-after-make-frame-hook' when running in daemon mode.
;;   ;; - To save the session at regular intervals, and when Emacs exits.
;;   (easysession-setup))

;;
;;

;; File Revert


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
