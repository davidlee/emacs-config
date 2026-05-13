;;; dl-orderless.el --- Orderless config -*- lexical-binding: t; -*-

(use-package orderless
  :custom
  (completion-styles '(orderless basic))
  (completion-category-overrides '((file (styles partial-completion))))
  (completion-pcm-leading-wildcard t)) ;; Emacs 31: partial-completion behaves like substring

(provide 'dl-orderless)
