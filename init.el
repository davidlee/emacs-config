;;; init.el --- Emacs init -*- lexical-binding: t; -*-

;; CORE
(require 'dl-compile)
(require 'dl-core)
(require 'dl-notes-paths)
(require 'dl-backup)
(require 'dl-persist)
(require 'dl-keymap)
(require 'dl-theme)
(require 'dl-font)
(require 'dl-interface)
(require 'dl-prose)
(require 'dl-modeline)
(require 'dl-meow)
(require 'dl-help)

;; DEV
(require 'dl-eglot)
(require 'dl-treesit)
(require 'dl-delimiters)

;; Completion / VOMPECCC
(require 'dl-completion) ; vanilla emacs completion
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
(require 'dl-search)

(require 'dl-indent)
(require 'dl-fold)

;; Org
(require 'dl-org)
(require 'dl-org-capture)
(require 'dl-org-agenda)
(require 'dl-org-links)
(require 'dl-denote)
(require 'dl-denote-templates)
(require 'dl-denote-journal)
(require 'dl-org-roam)

;; Language support
(require 'dl-elisp)
(require 'dl-markdown)
(require 'dl-lang-common)
(require 'dl-nix)

;; Apps
(require 'dl-term)
(require 'dl-ghostel)
(require 'dl-shpool)
(require 'dl-magit)
(require 'dl-term)
(require 'dl-claude)
(require 'dl-eaf)
(require 'dl-agent-shell)
(require 'treemacs)

(require 'dl-keybind)
;; (require 'dl-spotify)
;; (require 'dl-slack)
(require 'dl-dired)
(require 'dl-dirvish)

;; elisp: util
(require 'dl-insert-elisp-header)

;; (set-face-attribute 'default nil :font "JetBrains Mono" :height 115)
;; (set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;; (set-frame-font "Iosevka Nerd Font Mono-12" nil t)
;; (set-frame-font "Fira Mono-12" nil t)

;;; init.el ends here
