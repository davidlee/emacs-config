;;; dl-project.el --- projects / QOL  -*- lexical-binding: t; -*-

(use-package emacs
  :config
  ;; Treesitter config

  ;; Tell Emacs to prefer the treesitter mode You'll want to run the
  ;; command `M-x treesit-install-language-grammar' before editing.
  (setq major-mode-remap-alist
    '((yaml-mode . yaml-ts-mode)
       (bash-mode . bash-ts-mode)
       (js2-mode . js-ts-mode)
       (typescript-mode . typescript-ts-mode)
       (json-mode . json-ts-mode)
       (css-mode . css-ts-mode)
       (python-mode . python-ts-mode)))
  :hook
  ;; Auto parenthesis matching
  ((prog-mode . electric-pair-mode)))

(use-package project
  :custom
  (when (>= emacs-major-version 30)
    (project-mode-line t)))         ; show project name in modeline

(use-package diredfl
  :hook (dired-mode . diredfl-mode))

(use-package dired-subtree
  :after dired
  :bind (:map dired-mode-map
          ("TAB" . dired-subtree-toggle)))

(use-package nerd-icons)

(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(provide 'dl-project)
