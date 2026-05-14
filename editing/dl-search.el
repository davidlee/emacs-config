;;; dl-search.el --- Search -*- lexical-binding: t; -*-

(use-package rg
  :config
  (rg-enable-default-bindings)) ; https://github.com/dajva/rg.el

(use-package visual-regexp-steroids
  :bind
  ( ("C-c q r" . vr/replace)
    ("C-c q q" . vr/query-replace)
    ("C-r"     . vr/isearch-backward)
    ("C-s"     . vr/isearch-forward)
    ))

(use-package deadgrep)
(global-set-key (kbd "<f3>") #'deadgrep)

(provide 'dl-search)
;;; dl-search.el ends here
