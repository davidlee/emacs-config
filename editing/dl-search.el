;;; dl-search.el --- Search -*- lexical-binding: t; -*-

;; `rg-menu' lives at `C-c s g' via `my-search-map' in
;; `core/dl-keymap.el'.  `rg-enable-default-bindings' would clobber
;; `C-c s' with `rg-global-map' and break the family map; don't.
(use-package rg
  :commands (rg rg-menu rg-dwim))

;; Global `vr/query-replace' / `vr/replace' live in `my-search-map'
;; (`C-c s q' / `C-c s Q') via `core/dl-keymap.el'.  Isearch chords stay
;; here because they shadow the Emacs isearch globals, not personal keys.
(use-package visual-regexp-steroids
  :commands (vr/replace vr/query-replace)
  :bind
  (("C-r" . vr/isearch-backward)
    ("C-s" . vr/isearch-forward)
    ("C-S-s" . isearch-forward)
    ;;("C-S-r" . ) ;; isearch-backward?
    ))

(use-package deadgrep)
(global-set-key (kbd "<f3>") #'deadgrep)

(provide 'dl-search)
;;; dl-search.el ends here
