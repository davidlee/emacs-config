;;; dl-treesit.el --- Tree-sitter major modes -*- lexical-binding: t; -*-

(use-package treesit-auto
  :custom
  (treesit-auto-install nil)
  :config
  (global-treesit-auto-mode))


(when (treesit-available-p)
  (setopt treesit-language-source-alist
          '((bash       "https://github.com/tree-sitter/tree-sitter-bash")
            (css        "https://github.com/tree-sitter/tree-sitter-css")
            (json       "https://github.com/tree-sitter/tree-sitter-json")
            (python     "https://github.com/tree-sitter/tree-sitter-python")
            (javascript "https://github.com/tree-sitter/tree-sitter-javascript")
            (typescript "https://github.com/tree-sitter/tree-sitter-typescript"
                        "master" "typescript/src")
            (tsx        "https://github.com/tree-sitter/tree-sitter-typescript"
                        "master" "tsx/src")
            (yaml       "https://github.com/ikatyang/tree-sitter-yaml")))
  (setopt major-mode-remap-alist
          '((python-mode     . python-ts-mode)
            (bash-mode       . bash-ts-mode)
            (js-mode         . js-ts-mode)
            (typescript-mode . typescript-ts-mode)
            (json-mode       . json-ts-mode)
            (yaml-mode       . yaml-ts-mode)
            (css-mode        . css-ts-mode))))

(provide 'dl-treesit)
