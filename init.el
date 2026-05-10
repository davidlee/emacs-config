;;; init.el --- Emacs init -*- lexical-binding: t; -*-

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   help
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Show the help buffer after startup
(add-hook 'after-init-hook 'help-quick)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Load my packages
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "core" user-emacs-directory))
;(add-to-list 'load-path (expand-file-name "completion" user-emacs-directory))
;(add-to-list 'load-path (expand-file-name "editing" user-emacs-directory))
;(add-to-list 'load-path (expand-file-name "lang" user-emacs-directory))
;(add-to-list 'load-path (expand-file-name "apps" user-emacs-directory))

(require 'dl-core)
(require 'dl-interface)
(require 'dl-completion)
(require 'dl-theme)
(require 'dl-backup-dir)

;; RAINBOW DELIMETERS
;(use-package rainbow-delimiters
;  :ensure t
;  :hook (prog-mode . rainbow-delimiters-mode))


;(push '(menu-bar-lines . 0) default-frame-alist)
;(push '(tool-bar-lines . 0) default-frame-alist)
;(push '(vertical-scroll-bars) default-frame-alist)


