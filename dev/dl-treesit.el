;;; dl-treesit.el --- Tree-sitter major modes -*- lexical-binding: t; -*-

(use-package treesit-auto
  :custom
  (treesit-auto-install t)
  :config
  (setq treesit-auto-langs
    '(python javascript typescript tsx
       go gomod gowork
       rust zig nix ruby
       bash json yaml toml
       css html dockerfile sql lua
       elixir heex terraform hcl
       make cmake markdown
       gitcommit proto
       r julia awk
       clojure java kotlin))
  (treesit-auto-add-to-auto-mode-alist 'all)
  (global-treesit-auto-mode))

(provide 'dl-treesit)
