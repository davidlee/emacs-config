;;; dl-nushell.el --- DESCRnushell-ts-mode -*- lexical-binding: t; -*-

(use-package nushell-ts-mode
  :config
  ;; (require 'nushell-ts-babel)
  (defun my/nushell-mode-hook ()
    (corfu-mode 1)
    (highlight-parentheses-mode 1)
    (electric-pair-local-mode 1)
    (electric-local-indent-mode 1))
  (add-hook 'nushell-ts-mode 'my/nushell-mode-hook))

;; (with-eval-after-load 'org-contrib
;;   (org-babel-do-load-languages
;;     'org-babel-load-languages
;;     '((emacs-lisp . t)
;;        ;; ...
;;        (nushell . t))))

(provide 'dl-nushell)
;;; dl-nushell.el ends here
