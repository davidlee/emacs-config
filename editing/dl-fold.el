;;; dl-fold.el --- Folding -*- lexical-binding: t; -*-

;; Universal folding frontend.  kirigami dispatches the standard
;; open/close/toggle commands to whichever backend the current buffer
;; uses (outline-minor-mode, hs-minor-mode, treesit-fold, org, ...),
;; so a single C-c z prefix works across modes.  Bindings live in
;; core/dl-keymap.el under `my-fold-map'.
;; https://github.com/jamescherti/kirigami.el
(use-package kirigami
  :commands (kirigami-open-fold
              kirigami-open-fold-rec
              kirigami-open-folds
              kirigami-close-fold
              kirigami-close-folds
              kirigami-toggle-fold))

(use-package outline-indent
  :commands outline-indent-minor-mode
  :custom
  (outline-indent-ellipsis " ▼"))

;; outline-minor-mode for lispy / config / docs majors.
(use-package outline
  :ensure nil
  :hook ((emacs-lisp-mode lisp-mode conf-mode markdown-mode diff-mode)
         . outline-minor-mode))

;; hs-minor-mode for classic (non-treesit) major modes.
(use-package hideshow
  :ensure nil
  :hook ((lisp-interaction-mode                                   ; scratch
          c-mode c++-mode java-mode rust-mode go-mode ruby-mode   ; systems
          js-mode typescript-mode css-mode                        ; web
          sh-mode json-mode lua-mode nxml-mode html-mode)         ; scripting / data
         . hs-minor-mode))

;; treesit-fold uses the tree-sitter syntax tree for accurate
;; structural folding (functions, classes, comments, docstrings).
;; URL: https://github.com/emacs-tree-sitter/treesit-fold
;; treesit-fold-replacement-face attrs live in `core/dl-faces.el'.
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
  :hook ((c-ts-mode c++-ts-mode java-ts-mode                    ; systems
          rust-ts-mode go-ts-mode ruby-ts-mode
          js-ts-mode typescript-ts-mode tsx-ts-mode             ; web
          css-ts-mode html-ts-mode
          bash-ts-mode cmake-ts-mode dockerfile-ts-mode         ; scripting / infra
          json-ts-mode toml-ts-mode)                            ; data
         . treesit-fold-mode))

;; Drop-in extras (kotlin, swift, elixir, zig) — add to the :hook list
;; above if/when you adopt those modes.

(provide 'dl-fold)
;;; dl-fold.el ends here
