;;; dl-project.el --- projects / QOL  -*- lexical-binding: t; -*-
;;; Commentary: none

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
  :ensure nil
  :custom
  (when (>= emacs-major-version 30) 
    (project-vc-extra-root-markers '(".project" ".projectile" "flake.nix" "package.json" "go.mod" "Cargo.toml"))
    (project-mode-line t))         ; show project name in modeline
  :config
  
  (defvar my/project-root-markers
    '(".project" ".projectile" "flake.nix")
    "Files that mark a directory as a project root.")

  ;; This seems necessary to avoid ~/.git taking priority -
  ;; which leads to beachballing, as you'd expect
  ;; it'd be nice if there were a simpler way
  (defun my/project-try-local (dir)
    "Detect a project root by looking for explicit project markers above DIR."
    (when-let ((root
                 (cl-some
                   (lambda (marker)
                     (locate-dominating-file dir marker))
                   my/project-root-markers)))
      (cons 'local root)))

  (cl-defmethod project-root ((project (head local)))
    (cdr project))
  ;; ensure it's before project-try-vc in the list of functions
  (add-hook 'project-find-functions #'my/project-try-local -100))


;;
;;
;;

(use-package project-x
  :ensure nil
  :vc (:url "https://github.com/vmargb/project-x.git")
  :after project
  :config
  (setq project-x-local-identifier
    '(".project" ".project.el" "flake.nix" "package.json" "go.mod" "Cargo.toml"))
  (setq project-x-save-interval 600)
  (project-x-mode 1))


(use-package otpp
  :ensure nil
  :vc (:url "https://github.com/abougouffa/one-tab-per-project.git")
  :after project
  :config
  ;; Enable `otpp-mode` globally
  (otpp-mode 1)
  ;; If you want to advice the commands in `otpp-override-commands`
  ;; to be run in the current's tab (so, current project's) root directory
  (otpp-override-mode 1))

;;
(use-package diredfl
  :hook (dired-mode . diredfl-mode))

(provide 'dl-project)
;;; dl-project.el ends here
