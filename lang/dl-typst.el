;;; dl-typst.el --- typst -*- lexical-binding: t; -*-

;; `:mode' is load-bearing: typst-ts-mode's generated autoloads call
;; `define-compilation-mode' before compile.el is loaded, so the file
;; aborts part-way and its own `auto-mode-alist' entry and the
;; `typst-ts-mode' autoload never run.
(use-package typst-ts-mode
  :mode ("\\.typ\\'" . typst-ts-mode)
  :custom
  (typst-ts-indent-offset 2)
  (typst-ts-enable-raw-blocks-highlight t))

(provide 'dl-typst)
;;; dl-typst.el ends here
