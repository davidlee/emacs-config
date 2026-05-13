;;; init.el --- Emacs init -*- lexical-binding: t; -*-

;; add load paths
(seq-do
  (lambda (dir) (add-to-list 'load-path (expand-file-name dir user-emacs-directory)))
  '("lisp" "core" "editing" "completion" "apps" "org" "dev" "lang"
     "checkout/combobulate")) ; git checkouts

;;; load custom packages

;; CORE
(require 'dl-core)
(require 'dl-backup-dir)
(require 'dl-interface)
(require 'dl-theme)
(require 'dl-font)
(require 'dl-keybind)
(require 'dl-help)

;; DEV
(require 'dl-eglot)
(require 'dl-treesit)
(require 'dl-delimiters)

;; Completion
(require 'dl-completion) ; mostly vanilla emacs completion

;; VOMPECCC
(require 'dl-vertico)    ; better minibuffer UI
(require 'dl-orderless)  ; fuzzy / flexible matching
(require 'dl-marginalia) ; completion metadata
(require 'dl-prescient)  ; frequency sorting
(require 'dl-embark)     ; actions on search results
(require 'dl-consult)    ; Search/navigation commands
(require 'dl-corfu)      ; in-buffer completions

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
(require 'dl-dirvish)

;; Org
(require 'dl-org)
(require 'dl-denote)
(require 'dl-org-roam)

;; Language support
(require 'dl-elisp)
(require 'dl-markdown)
(require 'dl-lang-common)
(require 'dl-nix)

;; (set-face-attribute 'default nil :font "JetBrains Mono" :height 115)
;; (set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;; (set-frame-font "Iosevka Nerd Font Mono-12" nil t)
;; (set-frame-font "Fira Mono-12" nil t)
