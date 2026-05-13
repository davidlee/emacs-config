;;; dl-motion.el --- Getting around -*- lexical-binding: t; -*-

(use-package dumb-jump
  :ensure t
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

;;(use-package avy
;;  :bind (("M-j" . avy-goto-char-timer)))

(use-package avy
  :ensure t
  :demand t
  :bind  ( ("C-:"   . avy-goto-char)
           ("C-'"   . avy-goto-char-2)
           ("C-c j" . avy-goto-line)
           ("C-;"   . avy-goto-char-timer)))

(use-package ace-window
  :bind (("M-o" . ace-window)))

(use-package goto-chg
  :bind (("C-," . goto-last-change)
          ("C-." . goto-last-change-reverse)))

(use-package visual-regexp-steroids
  :bind
  ( ("C-c q r" . vr/replace)
    ("C-c q q" . vr/query-replace)
    ("C-r"     . vr/isearch-backward)
    ("C-s"     . vr/isearch-forward)
    ))

(use-package rg
  :config
  (rg-enable-default-bindings)) ; https://github.com/dajva/rg.el

(use-package git-link) ; https://github.com/sshaw/git-link
(use-package copy-as-format) ; https://github.com/sshaw/copy-as-format

(provide 'dl-motion)
