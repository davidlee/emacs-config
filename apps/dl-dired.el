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
