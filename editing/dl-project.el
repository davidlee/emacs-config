;;; dl-project.el --- projects / QOL  -*- lexical-binding: t; -*-
;;; Commentary: none

;; Auto parenthesis matching in code buffers.
(add-hook 'prog-mode-hook #'electric-pair-mode)

(use-package project
  :ensure nil
  :custom
  ;; Stop the root climb at a marker so a dir inside ~/.git isn't the
  ;; whole home repo, while keeping the VC backend (git ls-files). A
  ;; non-VC fallback lists via `find -L', which crawls symlinked
  ;; .direnv flake inputs and hangs.
  (project-vc-extra-root-markers
   '(".project" ".projectile" "flake.nix" "package.json" "go.mod" "Cargo.toml"))
  (project-mode-line t))           ; show project name in modeline


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

(provide 'dl-project)
;;; dl-project.el ends here
