;;; dl-package-loader.el --- package manager -*- lexical-binding: t; -*-

;; Packages are provided by nix (emacsWithPackagesFromUsePackage).
;; No runtime installation needed.

;; after adding a new use-package though:
;; -- ensure file is known to git (staged or committed previously)
;; -- cd ~/flakes && just home-switch

(setopt package-enable-at-startup nil
  use-package-always-ensure nil)
(require 'use-package)
(provide 'dl-package-loader)
