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

(add-to-list 'default-frame-alist '(internal-border-width . 10))

(load-file "~/.emacs.d/core/dl-path.el")
;;; early-init.el ends here
