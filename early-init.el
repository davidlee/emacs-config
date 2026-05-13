;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

;; Packages are provided by nix (emacsWithPackagesFromUsePackage).
;; after adding a new use-package declaration:
;; -- ensure file is known to git (staged or committed previously)
;; -- cd ~/flakes && just home-switch
(setopt package-enable-at-startup nil
	use-package-always-ensure nil)

(setq package-archives
  '(("gnu" . "https://elpa.gnu.org/packages/")
     ("nongnu" . "https://elpa.nongnu.org/nongnu/")
     ("melpa" . "https://melpa.org/packages/")))

(require 'use-package)
(require 'package)
(require 'package-vc)
(package-initialize)
