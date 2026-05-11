(use-package multiple-cursors
  :bind (("C-S-c C-S-c" . mc/edit-lines)
          ("C->" . mc/mark-next-like-this)
          ("C-<" . mc/mark-previous-like-this)))

(use-package expreg
  :bind (("C-=" . expreg-expand)
          ("C--" . expreg-contract)))

(use-package iedit)

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(provide 'dl-multi-edit)
