;;; dl-axm.el --- axiomata lsp setup -*- lexical-binding: t; -*-

(define-derived-mode axm-mode prog-mode "Axm"
  "Major mode for Axiomata (.axm) files."
  (setq-local comment-start "// ")
  (setq-local comment-end ""))

(add-to-list 'auto-mode-alist '("\\.axm\\'" . axm-mode))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs
    '(axm-mode . ("axiomata-lsp" "--stdio"))))

(add-hook 'axm-mode-hook 'eglot-ensure)

(provide 'dl-axm)
;;; dl-axm.el ends here
