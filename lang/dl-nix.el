;;; dl-nix.el --- for nix -*- lexical-binding: t; -*-

(use-package nix-mode
  :mode ("\\.nix\\'" "\\.nix.in\\'"))

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
    '(nix-mode . ("nil")))) ; or nixd

(provide 'dl-nix)
