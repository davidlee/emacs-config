;;; dl-eaf.el --- Emacs Application Framework -*- lexical-binding: t; -*-

;; EAF core + applications come from the nix flake (emacs-overlay's
;; `eaf.withApplications`). Load order matters: eaf must be loaded before
;; the application packages, because each app references symbols defined
;; in eaf.el at load time (e.g. `eaf-app-module-path-alist',
;; `eaf-get-theme-foreground-color').

(use-package eaf
  :demand t)

(use-package eaf-browser
  :demand t
  :after eaf)

(use-package eaf-pdf-viewer
  :demand t
  :after eaf)

(use-package eaf-image-viewer
  :demand t
  :after eaf)

(provide 'dl-eaf)
;;; dl-eaf.el ends here
