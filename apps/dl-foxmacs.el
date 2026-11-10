;;; dl-foxmacs.el --- control Firefox from Emacs under EWM -*- lexical-binding: t; -*-

;; foxmacs talks to its Firefox extension over native messaging: hints,
;; page search, headings, reader buffer, field editing, org capture.  It
;; needs EWM, which shows each Firefox window as an Emacs buffer; outside
;; one most commands refuse.  The elisp comes from ~/flakes/emacs; the
;; extension, native messaging host and Firefox Developer Edition (which
;; accepts the unsigned extension) from ~/flakes features/web.nix.
;;
;; Loaded only in an EWM session: `:after ewm', and only EWM's launcher
;; loads ewm.  `foxmacs-mode' serves $XDG_RUNTIME_DIR/foxmacs.sock.
;;
;; Keys sit under s-b ("browser") in `ewm-mode-map', which EWM intercepts
;; from every surface, so they reach Emacs while Firefox has focus.

(use-package foxmacs
  :ensure nil
  :after ewm
  :demand t
  :bind (:map ewm-mode-map
          ("s-b o" . foxmacs-open-url)
          ("s-b h" . foxmacs-hint)
          ("s-b s" . foxmacs-search-page)
          ("s-b j" . foxmacs-jump-to-heading)
          ("s-b r" . foxmacs-read)
          ("s-b e" . foxmacs-edit)
          ("s-b c" . foxmacs-org-capture)
          ("s-b u" . foxmacs-copy-url))
  :config
  (foxmacs-mode 1))

(provide 'dl-foxmacs)
;;; dl-foxmacs.el ends here
