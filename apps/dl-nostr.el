;;; dl-nostr.el --- nostr -*- lexical-binding: t; -*-

;; The private key comes from 1Password, not nostr.el's GPG file.
;; nostr.el has no hook for its key source, so both readers are
;; overridden: `nostr-backend-load-secret' (signing) and
;; `nostr-setup--load-secret' (`nostr-open', which first insists the
;; GPG file exists).  The second is private; recheck it on upgrade.

(require 'dl-secret)

(defcustom dl-nostr-secret-ref "op://Private/NOSTR/nsec"
  "1Password ref holding the Nostr private key (nsec or hex)."
  :type 'string
  :group 'nostr)

(defun dl-nostr--load-secret ()
  "Return the Nostr private key from 1Password."
  (let ((my/op-read-context "nostr"))
    (string-trim (my/op-read dl-nostr-secret-ref))))

(use-package nostr
  :vc (:url "https://github.com/trevarj/nostr.el"
        :branch "master")
  :commands (nostr-open
              nostr-close
              nostr-create-note
              nostr-check-backend
              nostr-account-status
              nostr-generate-private-key
              nostr-setup-import-private-key)
  :custom
  ;; Built by hand: `cargo build --release` in elpa/nostr; rebuild after
  ;; every `package-vc-upgrade` (the JSON protocol is not version-checked).
  (nostr-backend-command
    (expand-file-name "elpa/nostr/target/release/nostr-el-backend"
      user-emacs-directory))
  (nostr-db-path
    (expand-file-name "var/nostr-db.sqlite" user-emacs-directory))
  (nostr-relay-urls
    '("wss://relay.primal.net" "wss://relay.damus.io" "wss://nos.lol")))

(with-eval-after-load 'nostr-backend
  (advice-add 'nostr-backend-load-secret :override #'dl-nostr--load-secret))
(with-eval-after-load 'nostr-setup
  (advice-add 'nostr-setup--load-secret :override #'dl-nostr--load-secret))

(provide 'dl-nostr)
;;; dl-nostr.el ends here
