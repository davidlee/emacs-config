;;; dl-core.el --- basic setup -*- lexical-binding: t; -*-

;; https://github.com/rougier/nano-emacs/blob/master/nano-defaults.el

(require 'package-vc)

(use-package emacs
  :ensure nil
  :custom
  ;; performance
  (gc-cons-threshold 50000000)
  (large-file-warning-threshold 100000000)
  (load-prefer-newer t) ; new bytecode pls
  (initial-major-mode 'fundamental-mode)
  (initial-scratch-message "")
  (bidi-paragraph-direction 'left-to-right)

  (sentence-end-double-space nil) ; no

  ;; Identity
  (user-full-name "David Lee")
  (user-mail-address "dav@davlee.com")

  ;; put custom vars from configurators somewhere other than my init.el
  (custom-file (locate-user-emacs-file "custom-vars.el"))

  (standard-indent 2) ; this is the way

  ;; better defaults
  (save-interprogram-paste-before-kill t)
  (apropos-do-all t)
  (mouse-yank-at-point t)
  (require-final-newline t)
  (visible-bell t)
  (load-prefer-newer t)
  (backup-by-copying t)
  (frame-inhibit-implied-resize t)
  (read-file-name-completion-ignore-case t)
  (read-buffer-completion-ignore-case t)
  (completion-ignore-case t)
  (confirm-kill-processes nil)
  (use-short-answers t)
  ;; (ediff-window-setup-function 'ediff-setup-windows-plain)

  :config
  ;; don't warn when loading stuff from custom-vars.el
  (load custom-file 'noerror 'nomessage)

  :init
  (server-start)
  (require 'org-protocol)) ; emacsclient

;; Show the help buffer after startup
;; (add-hook 'after-init-hook 'help-quick))

(autoload 'zap-up-to-char "misc"
  "Kill up to, but not including ARGth occurrence of CHAR." t)

(use-package wgrep)

(require 'uniquify)
(setopt uniquify-buffer-name-style 'forward)

(use-package atomic-chrome
  :config
  (setq atomic-chrome-extension-type-list '(ghost-text))
  (setq atomic-chrome-default-major-mode 'markdown-mode)
  (setq atomic-chrome-buffer-open-style 'frame)
  (setq atomic-chrome-enable-auto-update t)
  (setq atomic-chrome-enable-bidirectional-edit t)
  (atomic-chrome-start-server))

;; Avoid Corfu/ispell crashing GhostText buffers.
;; (defun my-atomic-chrome-setup ()
;;   (setq-local completion-at-point-functions
;;     (remove #'ispell-completion-at-point
;;       completion-at-point-functions)))

;; (add-hook 'atomic-chrome-edit-mode-hook #'my-atomic-chrome-setup)

;; Optional, only if you have this file:
;;(when (file-exists-p "/usr/share/dict/words")
;;  (setq ispell-alternate-dictionary "/usr/share/dict/words"))

(defun load-init ()
  (interactive)
  (load-file (expand-file-name "init.el" user-emacs-directory)))

;; /tmp/emacs.XXXX/ for temp files
(defconst emacs-tmp-dir
  (expand-file-name (format "emacs.%d" (user-uid)) temporary-file-directory))
(setq backup-directory-alist
  `((".*" . ,emacs-tmp-dir)))
(setq auto-save-file-name-transforms
  `((".*" ,emacs-tmp-dir t)))
(setq auto-save-list-file-prefix
  emacs-tmp-dir)

(defun dl-core--make-parent-directory-maybe (filename &optional _wildcards)
  "Create parent directory of FILENAME if it doesn't exist."
  (unless (file-exists-p filename)
    (let ((dir (file-name-directory filename)))
      (unless (file-exists-p dir)
        (make-directory dir t)))))

(advice-add 'find-file :before #'dl-core--make-parent-directory-maybe)

(provide 'dl-core)
;;; dl-core.el ends here
