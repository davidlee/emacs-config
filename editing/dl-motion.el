;;; dl-motion.el --- Getting around -*- lexical-binding: t; -*-

(use-package dumb-jump
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

;;(use-package avy
;;  :bind (("M-j" . avy-goto-char-timer)))

(use-package avy
  :bind  ( ("C-:"   . avy-goto-char)
           ("C-'"   . avy-goto-char-2)
           ("C-c j" . avy-goto-line)
           ("C-;"   . avy-goto-char-timer)))

(use-package ace-window
  :custom
  (aw-scope 'frame)
  (aw-ignore-current t)
  (aw-backround nil)
  :bind (("M-o" . ace-window)))


(use-package goto-chg
  :bind (("C-," . goto-last-change)
          ("C-." . goto-last-change-reverse)))


(use-package git-link) ; https://github.com/sshaw/git-link
(use-package copy-as-format) ; https://github.com/sshaw/copy-as-format

;; SELECTION
(use-package expand-region)

(provide 'dl-motion)
