
;;; dl-core.el --- basic setup -*- lexical-binding: t; -*-
(use-package compile-angel
  :demand t
  :config
  ;; Set `compile-angel-verbose' to nil to disable compile-angel messages.
  ;; (When set to nil, compile-angel won't show which file is being compiled.)
  (setq compile-angel-verbose t)

  ;; Uncomment the line below to compile automatically when an Elisp file is saved
  ;; (add-hook 'emacs-lisp-mode-hook #'compile-angel-on-save-local-mode)

  ;; The following directive prevents compile-angel from compiling your init
  ;; files. If you choose to remove this push to `compile-angel-excluded-files'
  ;; and compile your pre/post-init files, ensure you understand the
  ;; implications and thoroughly test your code. For example, if you're using
  ;; the `use-package' macro, you'll need to explicitly add:
  ;; (eval-when-compile (require 'use-package))
  ;; at the top of your init file.
  (push "/init.el" compile-angel-excluded-files)
  (push "/early-init.el" compile-angel-excluded-files)

  ;; A global mode that compiles .el files before they are loaded
  ;; using `load' or `require'.
  (compile-angel-on-load-mode 1))

(require 'package-vc)

(use-package emacs
  :ensure nil
  :custom
  ;; performance
  (gc-cons-threshold 50000000)
  (large-file-warning-threshold 100000000)
  (load-prefer-newer t) ; new bytecode pls
  (initial-major-mode 'fundamental-mode)
  (bidi-paragraph-direction 'left-to-right)

  (sentence-end-double-space nil) ; no

  ;; Identity
  (user-full-name "David Lee")
  (user-email-address "dav@davlee.com")

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
  ;; (ediff-window-setup-function 'ediff-setup-windows-plain)

  :config
  ;; don't warn when loading stuff from custom-vars.el
  (load custom-file 'noerror 'nomessage)

  (windmove-default-keybindings '(ctrl shift))
  :init
  (server-start)) ; emacsclient

;; Show the help buffer after startup
;; (add-hook 'after-init-hook 'help-quick))

(autoload 'zap-up-to-char "misc"
  "Kill up to, but not including ARGth occurrence of CHAR." t)

(use-package which-key
  :ensure nil
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (which-key-show-early-on-C-h t)
  (which-key-idle-delay 1e6)
  (which-key-idle-secondary-delay 0.05)
  :config
  (which-key-mode))

(use-package direnv
  :config
  (direnv-mode))

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

(provide 'dl-core)
;;; dl-core.el ends here
