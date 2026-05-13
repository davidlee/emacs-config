;;; dl-eglot.el --- EGLOT LSP setup -*- lexical-binding: t; -*-

(use-package eglot
  :ensure nil
  :hook

  (((python-ts-mode
      js-ts-mode
      typescript-ts-mode
      tsx-ts-mode
      rust-ts-mode
      nix-mode
      go-ts-mode) . eglot-ensure))

  :custom
  (eglot-send-changes-idle-time 0.2)
  (eglot-extend-to-xref t)
  :config
  (fset #'jsonrpc--log-event #'ignore))  ; massive perf boost---don't log every event


(use-package consult-eglot
  :after (consult eglot))

(use-package treesit-auto
  :custom
  (treesit-auto-install 'prompt)
  :config
  (global-treesit-auto-mode))

(provide 'dl-eglot)
;;; dl-eglot.el ends here
