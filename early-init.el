;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

;; Packages are provided by nix (emacsWithPackagesFromUsePackage).
;; after adding a new use-package declaration:
;; -- ensure file is known to git (staged or committed previously)
;; -- cd ~/flakes && just home-switch

(setq my/debug-startup nil)

(when my/debug-startup
  (setq debug-on-error t)
  (setq use-package-verbose t)
  (setq use-package-compute-statistics t))

(setopt
  package-enable-at-startup nil
  package-archives nil ; don't download if missing
  use-package-always-ensure nil)

(require 'package)
(package-initialize)

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

(load-file "~/.emacs.d/core/dl-path.el")
;;; early-init.el ends here
