;;; init.el --- Emacs init -*- lexical-binding: t; -*-

(defvar my/lisp-dirs
  '("lisp" "core" "editing" "completion" "apps" "org" "dev" "lang")
  "My own Lisp directories, relative to `user-emacs-directory'.")

(defvar my/checkout-lisp-dirs
  '("checkout/example")
  "External checkout Lisp directories, relative to `user-emacs-directory'.")

(defun my/expand-emacs-dir (dir)
  "Expand DIR relative to `user-emacs-directory' as a directory path."
  (file-name-as-directory
    (expand-file-name dir user-emacs-directory)))

(defun my/add-load-path-dir (dir)
  "Add DIR under `user-emacs-directory' to `load-path'."
  (add-to-list 'load-path (my/expand-emacs-dir dir)))

(defun my/trust-lisp-dir (dir)
  "Add DIR under `user-emacs-directory' to `trusted-content'."
  (add-to-list 'trusted-content (my/expand-emacs-dir dir)))

;; Load both my code and external checkouts.
(mapc #'my/add-load-path-dir
  (append my/lisp-dirs my/checkout-lisp-dirs))

;; Trust only my own code.
(mapc #'my/trust-lisp-dir my/lisp-dirs)

;; Ensure Emacs loads the most recent byte-compiled files.
(setq load-prefer-newer t)

;;; load custom packages

;; CORE
(require 'dl-core)
(require 'dl-backup)
(require 'dl-interface)
(require 'dl-theme)
(require 'dl-font)
(require 'dl-keybind)
;; (require 'dl-god)
(require 'dl-meow)
(require 'dl-help)
(require 'dl-prose)

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
(require 'dl-term)
(require 'dl-magit)
(require 'dl-term)
;; (require 'dl-slack)
;; (require 'dl-dirvish)

;; Org
(require 'dl-org)
(require 'dl-denote)
(require 'dl-org-roam)

;; Language support
(require 'dl-elisp)
(require 'dl-markdown)
(require 'dl-lang-common)
(require 'dl-nix)

;; elisp: util
(require 'dl-insert-elisp-header)

;; (set-face-attribute 'default nil :font "JetBrains Mono" :height 115)
;; (set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;; (set-frame-font "Iosevka Nerd Font Mono-12" nil t)
;; (set-frame-font "Fira Mono-12" nil t)

;;; init.el ends here
