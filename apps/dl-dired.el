;;; dl-dired.el --- Dired core -*- lexical-binding: t; -*-

;; Dired is the base file manager. Dirvish (see dl-dirvish.el) provides
;; the UI; Yazi / Broot wrappers live alongside it. Bindings for the
;; whole stack live in core/dl-keymap.el under my-file-map (C-c f).

(use-package dired
  :ensure nil
  :commands (dired dired-jump)
  :custom
  (dired-kill-when-opening-new-dired-buffer t)
  (dired-recursive-copies 'always)
  (dired-recursive-deletes 'top)
  (delete-by-moving-to-trash t)
  (dired-listing-switches
    "-l --almost-all --human-readable --group-directories-first --no-group")
  :config
  ;; Lets `dirvish-side' auto-close its window when opening a file.
  (put 'dired-find-alternate-file 'disabled nil))

(use-package diredfl
  :hook (dired-mode . diredfl-mode))

(use-package nerd-icons :defer t)
(use-package ready-player :config (ready-player-mode +1))

(provide 'dl-dired)
;;; dl-dired.el ends here
