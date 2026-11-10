;;; dl-satan.el --- integration with SATAN (github.com:davidlee/satan) -*- lexical-binding: t; -*-

;; SATAN and Malebolge are built with Nix, so Guix leaves them out until
;; there is a plan for Nix there.  This gate is the only edge: nothing else
;; in the config needs them at load.

(require 'dl-guix)
(require 'dl-checkout)

(unless (or (eq system-type 'darwin) (dl-guix-system-p))
  (dl-checkout-compile-stale "satan.el")
  (use-package satan
    :ensure nil
    :demand t
    :custom
    (satan-notes-root "~/notes")
    (satan-mcp-enabled t)
    (satan-goad-enabled t)
    ;; SL-037 interim: remove once satan-attrd accepts content_backlog.
    (satan-sensor-content-enabled nil)
    (satan-journal-today
     (lambda ()
       (my/journal--ensure-today)
       (my/journal--today-file dl-notes-journal-dir "journal"))))


  ;; Client of SATAN's durable session daemon (github.com:davidlee/Malebolge).
  (use-package malebolge
    :ensure nil
    :load-path "~/dev/malebolge/emacs"
    :commands (malebolge-attach malebolge-start malebolge-stop)
    ;; Theme faces, not hex, so a theme change carries through. Under
    ;; foxglove-dark the package's defaults (function-name, constant) are
    ;; plain text colour. SATAN is `error' (red) and status `shadow' by default;
    ;; wakes inherit the thread face.
    :custom-face
    (malebolge-tool-face ((t :inherit success)))
    ;; foxglove-dark has no orange ink; warning's amber sat too near SATAN's red.
    (malebolge-thread-face ((t :inherit warning :weight normal :foreground "#e8915a")))
    (malebolge-reap-face ((t :inherit warning :weight bold :underline t))))

  (require 'malebolge-mail)
  (setopt malebolge-mail-plans-directory "~/.local/state/malebolge/mail-plans"
          malebolge-mail-acts-directory  "~/.local/state/malebolge/mail-acts"))

(provide 'dl-satan)
;;; dl-satan.el ends here
