;;; dl-org-gcal.el --- GCal sync -*- lexical-binding: t; -*-

(require 'plstore)

;; No GPG key / pinentry on this host. Use loopback so the passphrase
;; for the symmetric-encrypted plstore (org-gcal's OAuth refresh
;; token) is read in the minibuffer, then cached for the session.
;; Pairs with `allow-loopback-pinentry' in ~/.gnupg/gpg-agent.conf.
(setq epg-pinentry-mode 'loopback)
(setq plstore-cache-passphrase-for-symmetric-encryption t)

;; `oauth2-auto-plstore' defaults to `(concat user-emacs-directory ...)';
;; `user-emacs-directory' is the unexpanded "~/.emacs.d/", so the var
;; ends up containing a literal tilde. oauth2-auto's
;; `insert-break-on-secret-entries' guard then misfires under some call
;; paths even though `file-truename' would canonicalise both sides.
;; Pin the canonical absolute path up-front.
(setq oauth2-auto-plstore
  (expand-file-name "oauth2-auto.plist" user-emacs-directory))

;; `:commands' defers load until first invocation, so `op read' (which
;; can trigger a biometric prompt) does not fire at Emacs startup.
(use-package org-gcal
  :commands (org-gcal-sync
              org-gcal-fetch
              org-gcal-fetch-buffer
              org-gcal-sync-buffer
              org-gcal-post-at-point
              org-gcal-delete-at-point)
  :config
  ;; oauth2-auto's `insert-break-on-secret-entries' guard calls
  ;; `file-equal-p', which returns nil when either path doesn't exist
  ;; (stat-based). On a fresh setup the plstore file does not exist
  ;; yet, so the guard misfires on the first `plstore-save', aborts
  ;; before secrets are encrypted, and the file lands half-written.
  ;; Pre-create an empty but parseable plstore so the guard has
  ;; something to stat. Header alone breaks `plstore--init-from-buffer'
  ;; with `end-of-file' (it `read's the sexp after the header).
  (unless (file-exists-p oauth2-auto-plstore)
    (let ((store (plstore-open oauth2-auto-plstore)))
      (plstore-save store)
      (plstore-close store)))

  (setq org-gcal-client-id
    (my/op-read "op://API_KEYS/org-mode-gcal/client-id"))
  (setq org-gcal-client-secret
    (my/op-read "op://API_KEYS/org-mode-gcal/client-secret"))
  (setq org-gcal-fetch-file-alist
    `((,(my/op-read "op://API_KEYS/work_details/email")
        . "~/notes/calendar.org")))
  (org-gcal-reload-client-id-secret))

(provide 'dl-org-gcal)
;;; dl-org-gcal.el ends here
