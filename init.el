;;; init.el --- Emacs init -*- lexical-binding: t; -*-

;;;
;;; load custom packages
;;;



;; CORE
(require 'dl-core)
(require 'dl-backup-dir)
(require 'dl-interface)
(require 'dl-theme)
(require 'dl-help)

;; Completion
(require 'dl-completion) ; the basics
(require 'dl-vertico)    ; the UI
(require 'dl-orderless)  ;

;; Motion


;; Editing
(require 'dl-format)
(require 'dl-multi-edit)
(require 'dl-project)
; (require 'dl-snippets)
(require 'dl-motion)

;; Apps
;;(require 'dl-slack)
(require 'dl-term)
(require 'dl-magit)
(require 'dl-term)

;; Language support
(require 'dl-lsp)
(require 'dl-treesit)
(require 'dl-elisp)

;; (set-face-attribute 'default nil :font "JetBrains Mono" :height 115)
(set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;; (set-frame-font "Iosevka Nerd Font Mono-12" nil t)
;; (set-frame-font "Fira Mono-12" nil t)
