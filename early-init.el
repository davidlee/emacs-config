;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

(add-to-list 'load-path (expand-file-name "lisp" user-emacs-directory))
(add-to-list 'load-path (expand-file-name "core" user-emacs-directory))

(require 'dl-package-loader)
(require 'dl-core)
