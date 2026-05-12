;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

;; Packages are provided by nix (emacsWithPackagesFromUsePackage).
;; after adding a new use-package declaration:
;; -- ensure file is known to git (staged or committed previously)
;; -- cd ~/flakes && just home-switch
(setopt package-enable-at-startup nil
  use-package-always-ensure nil)
(require 'use-package)
