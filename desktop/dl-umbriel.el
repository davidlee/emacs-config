;;; dl-umbriel.el --- integration with umbriel (~/dev/umbriel.el) -*- lexical-binding: t; -*-

;;; Commentary:

;; The umbriel client (the *umbriel* buffer and frame focus) lives in its
;; own package, loaded from a git checkout.  A host without the checkout
;; gets a warning instead of a failed init.

;;; Code:

(require 'dl-checkout)

(if (not (locate-library "umbriel-buffer"))
    (display-warning 'dl-umbriel
                     "umbriel checkout not on load-path (~/dev/umbriel.el); skipped")
  (dl-checkout-compile-stale "umbriel.el")
  (use-package umbriel-buffer :ensure nil :demand t)
  (use-package umbriel-focus :ensure nil :demand t))

(provide 'dl-umbriel)
;;; dl-umbriel.el ends here
