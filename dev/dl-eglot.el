;;; dl-eglot.el --- EGLOT LSP setup -*- lexical-binding: t; -*-

(defun my/eglot-connected-p ()
  "Return non-nil when current buffer has a live Eglot server."
  (and (bound-and-true-p eglot--managed-mode)
       (ignore-errors (eglot-current-server))))

(defun my/eglot-format-buffer-if-connected ()
  (when (my/eglot-connected-p)
    (eglot-format-buffer)))

(defun my/eglot-organize-imports-if-connected ()
  (when (my/eglot-connected-p)
    (eglot-code-action-organize-imports)))

(defun my/eglot-on-save-setup ()
  "Wire format + organize-imports on save, buffer-locally."
  (add-hook 'before-save-hook #'my/eglot-format-buffer-if-connected    nil t)
  (add-hook 'before-save-hook #'my/eglot-organize-imports-if-connected nil t))

(use-package eglot
  :ensure nil
  :hook

  (((python-ts-mode
      js-ts-mode
      typescript-ts-mode
      tsx-ts-mode
      rust-ts-mode
      nix-mode
      go-ts-mode
      ruby-ts-mode
      zig-ts-mode
      zig-mode
      elixir-ts-mode
      lua-ts-mode
      terraform-mode) . eglot-ensure))

  :custom
  (eglot-send-changes-idle-time 0.2)
  (eglot-extend-to-xref t)
  :config
  (fset #'jsonrpc--log-event #'ignore)  ; massive perf boost---don't log every event
  (add-hook 'eglot-managed-mode-hook #'my/eglot-on-save-setup))


(use-package consult-eglot
  :after (consult eglot))

(provide 'dl-eglot)
;;; dl-eglot.el ends here
