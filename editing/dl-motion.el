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
  :bind  ( ("C-'"   . avy-goto-char-2)
           ("C-c j" . avy-goto-line)
           ("C-;"   . avy-goto-char-timer)))

(use-package ace-window
  :bind (("M-o" . ace-window)))

(use-package goto-chg
  :bind (("C-," . goto-last-change) ;; CONFLICT? EMBARK
          ("C-." . goto-last-change-reverse)))

(provide 'dl-motion)
