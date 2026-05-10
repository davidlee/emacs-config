;;; early-init.el --- Emacs pre-init -*- lexical-binding: t; -*-

(setq custom-lisp-dirs '("lisp"
			 "core"
		         "editing"
                         "completion"
			 "apps"
			 "lang"))

(seq-do
 (lambda (dir) (add-to-list
		'load-path
		(expand-file-name dir user-emacs-directory))) 
  custom-lisp-dirs) 

(require 'dl-package-loader)
(require 'dl-core)
