;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

;; Package sources:
;; -- nix (default): add the package to the list in ~/flakes/emacs/emacs.nix,
;;    then `cd ~/flakes && just home-switch'. use-package never downloads:
;;    `package-archives' is nil, so a package missing from the list fails
;;    to load.
;; -- package-vc: a `:vc' use-package stanza clones into elpa/ here
;;    at runtime, for packages not in nixpkgs or needing a writable dir
;;    (see dl-ghostel.el). `package-initialize' below activates them.
;; -- guix: Guix Home supplies most packages; `just guix-packages' fetches
;;    the rest into elpa/ (see dl-guix.el). Startup never downloads.

(defvar my/debug-startup nil
  "Non-nil to debug startup: errors enter the debugger, use-package reports.")

(when my/debug-startup
  (setq debug-on-error t)
  (setq use-package-verbose t)
  (setq use-package-compute-statistics t))

(load (expand-file-name "core/dl-package" user-emacs-directory) nil 'nomessage)

(require 'use-package)
(require 'package-vc)

;; Don't pop *Warnings* for files lacking a lexical-binding cookie
;; (third-party/legacy .el). Still logged, just not raised.
(add-to-list 'warning-suppress-types '(files missing-lexbind-cookie))
;; (add-to-list 'warning-suppress-types '(bytecomp))
;; (add-to-list 'warning-suppress-types '(comp))

(add-to-list 'default-frame-alist '(internal-border-width . 10))
;; pgtk draws its own GTK CSD titlebar; the compositor's prefer-no-csd
;; hint isn't honoured, so drop decorations ourselves (initial frame).
(add-to-list 'default-frame-alist '(undecorated . t))
(setq underline-minimum-offset 3)
(setq x-use-underline-position-properties nil)
(setq x-underline-at-descent-line t)            ; Prettier underlines

(load-file (expand-file-name "core/dl-path.el" user-emacs-directory))
(require 'dl-guix)
(dl-guix-configure-packages)
;;; early-init.el ends here
