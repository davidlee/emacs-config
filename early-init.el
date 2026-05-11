;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

(seq-do
  (lambda (dir) (add-to-list 'load-path (expand-file-name dir user-emacs-directory)))
  '("lisp"
		 "core"
		 "editing"
     "completion"
		 "apps"
     "org"
     "dev"
		 "lang"
     
     ;; git checkouts
     "checkout/combobulate"))

(require 'dl-package-loader)
(require 'dl-core)
