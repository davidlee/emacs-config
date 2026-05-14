;;; dl-dired.el --- Dired -*- lexical-binding: t; -*-

;;; -*- lexical-binding: t; -*-

(use-package dired-preview
  :custom
  (setq dired-preview-delay 0.3)
  :config
  (dired-preview-global-mode 1))

(use-package ready-player
  :config
  (ready-player-mode +1))

(provide 'dl-dired)

(use-package dired-sidebar
  :bind (("C-x C-n" . dired-sidebar-toggle-sidebar))
  :commands
  (dired-sidebar-toggle-sidebar)
  :init
  (add-hook 'dired-sidebar-mode-hook
    (lambda ()
      (unless (file-remote-p default-directory)
        (auto-revert-mode))))
  :config
  (push 'toggle-window-split dired-sidebar-toggle-hidden-commands)
  (push 'rotate-windows dired-sidebar-toggle-hidden-commands)

  (setq dired-sidebar-subtree-line-prefix "__")
  (setq dired-sidebar-theme 'vscode)
  (setq dired-sidebar-use-term-integration t)
  (setq dired-sidebar-use-custom-font t))

(use-package nerd-icons :defer t)
(use-package nerd-icons-dired
  :commands (nerd-icons-dired-mode))
(setq dired-sidebar-theme 'nerd-icons)

;;; dl-dired.el ends here
