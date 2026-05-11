;;; dl-treesit.el --- Tree-sitter major modes -*- lexical-binding: t; -*-

(use-package treesit-auto
  :custom
  (treesit-auto-install nil)
  :config
  (global-treesit-auto-mode))

(use-package combobulate
  :custom
  ;; You can customize Combobulate's key prefix here.
  ;; Note that you may have to restart Emacs for this to take effect!
  (combobulate-key-prefix "C-c o")
  :hook ((prog-mode . combobulate-mode))
  ;; Amend this to the directory where you keep Combobulate's source
  ;; code.
  :load-path ("path-to-git-checkout-of-combobulate"))


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
       (python-mode)    . python-ts-mode)
    (css-mode        . css-ts-mode))
  )


(provide 'dl-treesit)
