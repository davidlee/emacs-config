;;; dl-spotify.el --- Spotify :: Smudge -*- lexical-binding: t; -*-

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

(provide 'dl-spotify)
;;; dl-spotify.el ends here
