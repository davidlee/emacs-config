;;; dl-search.el --- Search -*- lexical-binding: t; -*-

;; `rg-menu' lives at `C-c s g' via `my-search-map' in
;; `core/dl-keymap.el'.  `rg-enable-default-bindings' would clobber
;; `C-c s' with `rg-global-map' and break the family map; don't.
(use-package rg
  :commands (rg rg-menu rg-dwim))

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
