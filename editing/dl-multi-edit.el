;;; dl-multi-edit.el --- multi-edit -*- lexical-binding: t; -*-

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

;; (setq-local combobulate-checkout-path (expand-file-name "checkout/combobulate" user-emacs-directory))
(use-package combobulate
  :vc (:url "https://github.com/mickeynp/combobulate.git")
  :custom
  ;; You can customize Combobulate's key prefix here.
  ;; Note that you may have to restart Emacs for this to take effect!
  (combobulate-key-prefix "C-c o")
  :hook ((prog-mode . combobulate-mode))
  ;; :load-path combobulate-checkout-path
  )

(provide 'dl-multi-edit)
;;; dl-multi-edit.el ends here
