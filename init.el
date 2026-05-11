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

;; DEV
(require 'dl-eglot)
(require 'dl-treesit)


;; Completion
(require 'dl-completion) ; mostly vanilla emacs completion

;; VOMPECCC
(require 'dl-vertico)    ; better minibuffer UI
(require 'dl-orderless)  ; fuzzy / flexible matching
(require 'dl-marginalia) ; completion metadata
(require 'dl-prescient)  ; frequency sorting
(require 'dl-embark)     ; actions on search results
(require 'dl-consult)    ; Search/navigation commands
(require 'dl-cape)       ; completion sources
(require 'dl-corfu)      ; in-buffer completion UI


;; Editing
(require 'dl-format)
(require 'dl-multi-edit)
(require 'dl-project)
(require 'dl-snippets)
(require 'dl-motion)
(require 'dl-persist)
(require 'dl-indent)

;; Apps
(require 'dl-slack)
(require 'dl-term)
(require 'dl-magit)
(require 'dl-term)

;; Org
(require 'dl-org)
(require 'dl-denote)

;; Language support
(require 'dl-elisp)
(require 'dl-markdown)
(require 'dl-lang-common)
(require 'dl-nix)

;; (set-face-attribute 'default nil :font "JetBrains Mono" :height 115)
(set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;; (set-frame-font "Iosevka Nerd Font Mono-12" nil t)
;; (set-frame-font "Fira Mono-12" nil t)
