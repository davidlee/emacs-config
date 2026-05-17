;;; dl-treesit.el --- Tree-sitter major modes -*- lexical-binding: t; -*-

;; Defensive remap: if anything invokes a classic mode (e.g. `yaml-mode'
;; from a binding or `auto-mode-alist' entry we don't control), route it
;; to the tree-sitter variant. `treesit-auto' handles file-extension
;; routing for the common case.
(setq major-mode-remap-alist
  '((yaml-mode       . yaml-ts-mode)
     (bash-mode       . bash-ts-mode)
     (js2-mode        . js-ts-mode)
     (typescript-mode . typescript-ts-mode)
     (json-mode       . json-ts-mode)
     (css-mode        . css-ts-mode)
     (python-mode     . python-ts-mode)))

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
