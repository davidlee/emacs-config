;;; -*- lexical-binding: t; -*-

(use-package dired-preview
  :ensure t
  :custom
  (setq dired-preview-delay 0.3)
  :config
  (dired-preview-global-mode 1))

(use-package ready-player
  :ensure t
  :config
  (ready-player-mode +1))

(load (expand-file-name
        "dl-spotify.secret.el" user-emacs-directory) t)

(setq smudge-transport 'connect)
(use-package smudge
  :custom
  (smudge-oauth2-client-secret dl/spotify-client-id)
  (smudge-oauth2-client-id dl/spotify-client-id)
  ;; optional: enable transient map for frequent commands
  (smudge-player-use-transient-map t)
  :config
  ;; optional: display current song in mode line
  (global-smudge-remote-mode)
  :bind (("C-c ." . smudge-command-map)))

(provide 'dl-dired)
