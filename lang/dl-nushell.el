;;; dl-nushell.el --- DESCRnushell-ts-mode -*- lexical-binding: t; -*-

;; The mode warns at load if the grammar is missing, and Guix doesn't have it.
(use-package nushell-ts-mode
  :if (treesit-language-available-p 'nu)
  :functions (highlight-parentheses-mode electric-local-indent-mode)
  :config
  ;; (require 'nushell-ts-babel)
  (defun my/nushell-mode-hook ()
    (corfu-mode 1)
    (highlight-parentheses-mode 1)
    (electric-pair-local-mode 1)
    (electric-local-indent-mode 1))
  (add-hook 'nushell-ts-mode-hook 'my/nushell-mode-hook))

;; (with-eval-after-load 'org-contrib
;;   (org-babel-do-load-languages
;;     'org-babel-load-languages
;;     '((emacs-lisp . t)
;;        ;; ...
;;        (nushell . t))))

(provide 'dl-nushell)
;;; dl-nushell.el ends here
