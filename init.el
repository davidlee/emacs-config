;;; init.el --- Emacs init -*- lexical-binding: t; -*-
(setq debug-on-event 'sigusr2)
(setq auth-sources '("secrets:Login"))

;; CORE
(require 'dl-compile)
(require 'dl-core)
(require 'dl-notes-paths)
(require 'dl-backup)
(require 'dl-persist)
(require 'dl-keymap)
(require 'dl-policy-lint)
(require 'dl-theme)
(require 'dl-faces)
(require 'dl-interface)
(require 'dl-popups)
(require 'dl-prose)
(require 'dl-modeline)
(require 'dl-meow)
(require 'dl-help)

(require 'dl-sleipnir-doctor)

;; DEV
(require 'dl-eglot)
(require 'dl-treesit)
(require 'dl-delimiters)
(require 'dl-test)

;; Completion / VOMPECCC
(require 'dl-completion) ; vanilla emacs completion
(require 'dl-vertico)    ; better minibuffer UI
(require 'dl-orderless)  ; fuzzy / flexible matching
(require 'dl-marginalia) ; completion metadata
(require 'dl-prescient)  ; frequency sorting
(require 'dl-embark)     ; actions on search results
(require 'dl-consult)    ; Search/navigation commands
(require 'dl-consult-notes) ; per-class notes sources
(require 'dl-corfu)      ; in-buffer completions

;; Editing
(require 'dl-format)
(require 'dl-multi-edit)
(require 'dl-project)
(require 'dl-snippets)
(require 'dl-motion)
(require 'dl-search)
(require 'dl-dwim)
(require 'dl-comment)
(require 'dl-select)
(require 'dl-iedit)
(require 'dl-diagram)
(require 'dl-indent)
(require 'dl-fold)
(require 'dl-crux)
(require 'dl-move-text)

;; Org
(require 'dl-org)
(require 'dl-org-capture)
(require 'dl-org-agenda)
(require 'dl-org-links)
(require 'dl-denote)
(require 'dl-denote-templates)
(require 'dl-denote-journal)
(require 'dl-denote-promote)
(unless (eq system-type 'darwin)
  (use-package satan
    :ensure nil
    :demand t
    :custom
    (satan-notes-root "~/notes")
    (satan-journal-today
     (lambda ()
       (my/journal--ensure-today)
       (my/journal--today-file dl-notes-journal-dir "journal")))))
(require 'dl-org-ql)
(require 'dl-review)
(require 'dl-org-roam)
(require 'dl-org-gcal)

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
(require 'dl-claude)
;; (require 'dl-eaf)
(require 'dl-agent-shell)
(require 'dl-smudge)
(require 'dl-secret)
(require 'dl-gptel)
(require 'dl-minuet)
(require 'dl-eca)
(require 'dl-bough)

(require 'dl-keybind)
(require 'dl-dired)
(require 'dl-dirvish)

;; elisp: util
(require 'dl-insert-elisp-header)
(require 'dl-buffer-management)
(require 'dl-window)
(require 'dl-file-ops)

;;; init.el ends here
