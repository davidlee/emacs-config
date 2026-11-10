;;; dl-package.el --- Activate installed packages, never download -*- lexical-binding: t; -*-

;;; Commentary:

;; Activates every installed package: Nix's site-lisp and `:vc' clones
;; in elpa/.  Loaded by early-init.el, and by bin/elisp-compile-child
;; so byte-compile children (Flymake, `just lint') see the packages and
;; autoloads the live config sees.

;;; Code:

(setopt
  package-enable-at-startup nil
  package-archives nil ; don't download if missing
  use-package-always-ensure nil)

(require 'package)
(package-initialize)

(provide 'dl-package)
;;; dl-package.el ends here
