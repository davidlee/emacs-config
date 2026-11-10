;;; dl-eaf.el --- Emacs Application Framework -*- lexical-binding: t; -*-

;; EAF core + applications come from the nix flake (emacs-overlay's
;; `eaf.withApplications`). Load order matters: eaf must be loaded before
;; the application packages, because each app references symbols defined
;; in eaf.el at load time (e.g. `eaf-app-module-path-alist',
;; `eaf-get-theme-foreground-color').

(use-package eaf
  :ensure nil
  :commands (eaf-open
             eaf-open-browser
             eaf-open-pdf-viewer
             eaf-open-image-viewer))

(use-package eaf-browser
  :ensure nil
  :after eaf)

(use-package eaf-pdf-viewer
  :ensure nil
  :after eaf)

(use-package eaf-image-viewer
  :ensure nil
  :after eaf)

(use-package eaf-markdown-previewer
  :ensure nil
  :after eaf
  :vc (:url "https://github.com/emacs-eaf/eaf-markdown-previewer.git"))

(provide 'dl-eaf)
;;; dl-eaf.el ends here
