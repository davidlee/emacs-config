;;; dl-lsp.el --- LSP setup -*- lexical-binding: t; -*-

(use-package eglot
  :ensure nil
  :hook

  ((python-ts-mode
    js-ts-mode
    typescript-ts-mode
    tsx-ts-mode
    rust-ts-mode
    nix-mode
    go-ts-mode) . eglot-ensure))

                                        ;  :custom
                                        ;  (eglot-send-changes-idle-time 0.2)
                                        ; (eglot-extend-to-xref t))

(use-package consult-eglot
  :after (consult eglot))


(provide 'dl-lsp)
