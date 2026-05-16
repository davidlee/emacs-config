;;; dl-nix.el --- for nix -*- lexical-binding: t; -*-

(defconst dl-nix/flake "/home/david/flakes"
  "Path to the user's flake, evaluated by nixd for option completion.")

(defconst dl-nix/nixos-host "Sleipnir")
(defconst dl-nix/home-user "david")

(defun dl-nix/nixd-config ()
  "nixd workspace settings: package + NixOS + home-manager option completion.

Uses the flake's own nixpkgs input (not <nixpkgs>) so completion matches
what the system is actually built against.  Option exprs reference
`nixosConfigurations.<host>' and `homeConfigurations.<user>' so nixd can
type-check attribute paths under `config.*' and offer documentation."
  (let ((flake dl-nix/flake))
    `(:nixd
      (:nixpkgs
       (:expr ,(format "import (builtins.getFlake \"%s\").inputs.nixpkgs { }"
                       flake))
       :formatting
       (:command ["alejandra"])
       :options
       (:nixos
        (:expr ,(format
                 "(builtins.getFlake \"%s\").nixosConfigurations.%s.options"
                 flake dl-nix/nixos-host))
        :home-manager
        (:expr ,(format
                 "(builtins.getFlake \"%s\").homeConfigurations.%s.options"
                 flake dl-nix/home-user)))))))

(defun dl-nix/set-workspace-config ()
  (setq-local eglot-workspace-configuration (dl-nix/nixd-config)))

(use-package nix-mode
  :mode ("\\.nix\\'" "\\.nix.in\\'")
  :hook (nix-mode . dl-nix/set-workspace-config))

(use-package nix-drv-mode
  :ensure nix-mode
  :mode "\\.drv\\'")

(use-package nix-shell
  :ensure nix-mode
  :commands (nix-shell-unpack nix-shell-configure nix-shell-build))

(use-package nix-repl
  :ensure nix-mode
  :commands (nix-repl))

(use-package eglot
  :config
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nixd"))))

(provide 'dl-nix)
