(use-package nix-mode
  :ensure t
  :mode "\\.nix\\'")

(use-package eglot
  :config
  (add-to-list 'eglot-server-programs
               '(nix-mode . ("nil")))) ; or nixd
