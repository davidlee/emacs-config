;;; dl-fold.el --- Folding -*- lexical-binding: t; -*-

;; https://github.com/jamescherti/kirigami.el
(use-package kirigami)
(global-set-key (kbd "C-c z o") 'kirigami-open-fold)     ; Open fold at point
(global-set-key (kbd "C-c z O") 'kirigami-open-fold-rec) ; Open fold recursively
(global-set-key (kbd "C-c z r") 'kirigami-open-folds)    ; Open all folds
(global-set-key (kbd "C-c z c") 'kirigami-close-fold)    ; Close fold at point
(global-set-key (kbd "C-c z m") 'kirigami-close-folds)   ; Close all folds
(global-set-key (kbd "C-c z a") 'kirigami-toggle-fold)   ; Toggle fold at point


(use-package outline-indent
  :commands outline-indent-minor-mode
  :custom
  (outline-indent-ellipsis " ▼"))

(add-hook 'emacs-lisp-mode-hook #'outline-minor-mode)
(add-hook 'lisp-interaction-mode-hook #'hs-minor-mode) ; scratch
(add-hook 'lisp-mode-hook #'outline-minor-mode)
(add-hook 'conf-mode-hook #'outline-minor-mode)
(add-hook 'markdown-mode-hook #'outline-minor-mode)
(add-hook 'diff-mode-hook #'outline-minor-mode)

;; Systems and General Purpose
(add-hook 'c-mode-hook #'hs-minor-mode)
(add-hook 'c++-mode-hook #'hs-minor-mode)
(add-hook 'java-mode-hook #'hs-minor-mode)
(add-hook 'rust-mode-hook #'hs-minor-mode)
(add-hook 'go-mode-hook #'hs-minor-mode)
(add-hook 'ruby-mode-hook #'hs-minor-mode)

;; Web and Frontend
(add-hook 'js-mode-hook #'hs-minor-mode)
(add-hook 'typescript-mode-hook #'hs-minor-mode)
(add-hook 'css-mode-hook #'hs-minor-mode)

;; Scripting, Data, and Infrastructure
(add-hook 'sh-mode-hook #'hs-minor-mode) ; for bash/shell scripts
(add-hook 'json-mode-hook #'hs-minor-mode)
(add-hook 'lua-mode-hook #'hs-minor-mode)
(add-hook 'nxml-mode-hook #'hs-minor-mode)
(add-hook 'html-mode-hook #'hs-minor-mode) ; mhtml and html

;; Intelligent code folding by using the structural understanding of the
;; built-in tree-sitter parser. Unlike traditional folding methods that rely on
;; regular expressions or indentation, treesit-fold uses the actual syntax tree
;; of the code to accurately identify foldable regions such as functions,
;; classes, comments, and documentation strings.
;; URL: https://github.com/emacs-tree-sitter/treesit-fold
(use-package treesit-fold
  :commands (treesit-fold-close
              treesit-fold-close-all
              treesit-fold-open
              treesit-fold-toggle
              treesit-fold-open-all
              treesit-fold-mode
              global-treesit-fold-mode
              treesit-fold-open-recursively
              treesit-fold-line-comment-mode)

  :custom
  (treesit-fold-line-count-show t)
  (treesit-fold-line-count-format " ▼")

  :config
  (set-face-attribute 'treesit-fold-replacement-face nil
    :foreground "#808080"
    :box nil
    :weight 'bold))

;; Systems and General Purpose
(add-hook 'c-ts-mode-hook #'treesit-fold-mode)
(add-hook 'c++-ts-mode-hook #'treesit-fold-mode)
(add-hook 'java-ts-mode-hook #'treesit-fold-mode)
(add-hook 'rust-ts-mode-hook #'treesit-fold-mode)
(add-hook 'go-ts-mode-hook #'treesit-fold-mode)
(add-hook 'ruby-ts-mode-hook #'treesit-fold-mode)

;; Web and Frontend
(add-hook 'js-ts-mode-hook #'treesit-fold-mode)
(add-hook 'typescript-ts-mode-hook #'treesit-fold-mode)
(add-hook 'tsx-ts-mode-hook #'treesit-fold-mode)
(add-hook 'css-ts-mode-hook #'treesit-fold-mode)
(add-hook 'html-ts-mode-hook #'treesit-fold-mode)

;; Scripting and Infrastructure
(add-hook 'bash-ts-mode-hook #'treesit-fold-mode)
(add-hook 'cmake-ts-mode-hook #'treesit-fold-mode)
(add-hook 'dockerfile-ts-mode-hook #'treesit-fold-mode)

;; Data and Configuration
(add-hook 'json-ts-mode-hook #'treesit-fold-mode)
(add-hook 'toml-ts-mode-hook #'treesit-fold-mode)


;; MARKDOWN - dl-markdown.el --
;; Folding mode
(add-hook 'markdown-mode-hook #'outline-minor-mode)

;; Third-party
;; (add-hook 'kotlin-ts-mode-hook #'treesit-fold-mode)
;; (add-hook 'swift-ts-mode-hook #'treesit-fold-mode)
;; (add-hook 'elixir-ts-mode-hook #'treesit-fold-mode)
;; (add-hook 'zig-ts-mode-hook #'treesit-fold-mode)

;; Intelligent code folding by using the structural understanding of the
;; built-in tree-sitter parser. Unlike traditional folding methods that rely on
;; regular expressions or indentation, treesit-fold uses the actual syntax tree
;; of the code to accurately identify foldable regions such as functions,
;; classes, comments, and documentation strings.
;; URL: https://github.com/emacs-tree-sitter/treesit-fold
(use-package treesit-fold
  :commands (treesit-fold-close
              treesit-fold-close-all
              treesit-fold-open
              treesit-fold-toggle
              treesit-fold-open-all
              treesit-fold-mode
              global-treesit-fold-mode
              treesit-fold-open-recursively
              treesit-fold-line-comment-mode)

  :custom
  (treesit-fold-line-count-show t)
  (treesit-fold-line-count-format " ▼")

  :config
  (set-face-attribute 'treesit-fold-replacement-face nil
    :foreground "#808080"
    :box nil
    :weight 'bold))

;; Systems and General Purpose
(add-hook 'c-ts-mode-hook #'treesit-fold-mode)
(add-hook 'c++-ts-mode-hook #'treesit-fold-mode)
(add-hook 'java-ts-mode-hook #'treesit-fold-mode)
(add-hook 'rust-ts-mode-hook #'treesit-fold-mode)
(add-hook 'go-ts-mode-hook #'treesit-fold-mode)
(add-hook 'ruby-ts-mode-hook #'treesit-fold-mode)

;; Web and Frontend
(add-hook 'js-ts-mode-hook #'treesit-fold-mode)
(add-hook 'typescript-ts-mode-hook #'treesit-fold-mode)
(add-hook 'tsx-ts-mode-hook #'treesit-fold-mode)
(add-hook 'css-ts-mode-hook #'treesit-fold-mode)
(add-hook 'html-ts-mode-hook #'treesit-fold-mode)

;; Scripting and Infrastructure
(add-hook 'bash-ts-mode-hook #'treesit-fold-mode)
(add-hook 'cmake-ts-mode-hook #'treesit-fold-mode)
(add-hook 'dockerfile-ts-mode-hook #'treesit-fold-mode)

;; Data and Configuration
(add-hook 'json-ts-mode-hook #'treesit-fold-mode)
(add-hook 'toml-ts-mode-hook #'treesit-fold-mode)

;; Third-party
;; (add-hook 'kotlin-ts-mode-hook #'treesit-fold-mode)
;; (add-hook 'swift-ts-mode-hook #'treesit-fold-mode)
;; (add-hook 'elixir-ts-mode-hook #'treesit-fold-mode)
;; (add-hook 'zig-ts-mode-hook #'treesit-fold-mode)

(provide 'dl-fold)
;;; dl-fold.el ends here
