;;; dl-theme.el --- Theme settings -*- lexical-binding: t; -*-

(use-package modus-themes
  :ensure t
  :config

  (setopt modus-themes-mode-line '(accented borderless)
        modus-themes-bold-constructs t
        modus-themes-italic-constructs t
        modus-themes-fringes 'subtle
        modus-themes-tabs-accented t
        modus-themes-paren-match '(bold)
        ; modus-themes-prompts '(bold intense)
        ; modus-themes-completions 'opinionated
        modus-themes-org-blocks 'tinted-background
        modus-themes-scale-headings t
        modus-themes-region '(bg-only))

  (modus-themes-load-theme 'modus-operandi)

  (define-key global-map (kbd "<f5>") #'modus-themes-toggle))

(provide 'dl-theme)
