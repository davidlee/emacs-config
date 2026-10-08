;;; dl-multi-edit.el --- multi-edit -*- lexical-binding: t; -*-

;; No multiple-cursors: meow beacon (`meow-grab', then a selection)
;; covers it; iedit handles live symbol renames.

(use-package expreg
  :bind (("C-=" . expreg-expand)
          ("C--" . expreg-contract)))

(use-package iedit)

(provide 'dl-multi-edit)
;;; dl-multi-edit.el ends here
