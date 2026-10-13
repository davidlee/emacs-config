;;; dl-gnus.el --- gnus + fastmail -*- lexical-binding: t; -*-

;; Mail via Fastmail: read over IMAP (nnimap), send over SMTP.
;; News via Frugal Usenet (nntp); web feeds via nnatom.
;; Login and sending address are both the Fastmail account (david@).
;;
;; Credentials come from auth-source (`auth-sources' is the GNOME
;; keyring, see init.el), keyed by host + user + port.  The secrets
;; backend matches every attribute the client asks for, and nnimap and
;; smtpmail both ask for a port, so entries without one never match.
;; With no match, each prompts and saves its own entry (nnimap's is
;; keyed by server name: host "fastmail", port "imaps").  To pre-seed
;; instead, both entries hold the same Fastmail app password:
;;
;;   (secrets-create-item "Login" "Fastmail IMAP" (read-passwd "App password: ")
;;     :host "imap.fastmail.com" :user "david@davlee.com" :port "993")
;;   (secrets-create-item "Login" "Fastmail SMTP" (read-passwd "App password: ")
;;     :host "smtp.fastmail.com" :user "david@davlee.com" :port "465")

(require 'dl-keymap-shadow)

(defconst dl-gnus-login "david@davlee.com"
  "Fastmail account login, shared by IMAP and SMTP.")

(setq user-full-name "David Lee"
  user-mail-address "david@davlee.com")

(defconst dl-gnus-archive-group "nnimap+fastmail:Archive"
  "Fastmail's Archive folder: where archived mail goes.")

(defun dl-gnus--frugal (name host)
  "Frugal Usenet server NAME at HOST, over NNTPS (port 563).
nntp prompts for the login each session and never saves it; to avoid
that, seed the keyring, one item per host (`:port' must be one nntp
asks for, e.g. \"563\"):
  (secrets-create-item \"Login\" \"Frugal Usenet\" (read-passwd \"Password: \")
    :host HOST :user USER :port \"563\")"
  `(nntp ,name
     (nntp-address ,host)
     (nntp-port-number 563)
     (nntp-open-connection-function nntp-open-ssl-stream)))

(defconst dl-gnus-feeds '("doctrine.engineering/feed.xml")
  "Atom feeds read in Gnus, each its own nnatom server.
Addresses omit the scheme; nnatom fetches over https.")

(use-package gnus
  :defer t
  :custom
  ;; No primary server: mail, news and feeds are all secondary.
  (gnus-select-method '(nnnil ""))
  (gnus-secondary-select-methods
    `((nnimap "fastmail"
        (nnimap-address "imap.fastmail.com")
        (nnimap-stream ssl)
        (nnimap-user ,dl-gnus-login))
       ,(dl-gnus--frugal "frugal" "news.frugalusenet.com")
       ,@(mapcar (lambda (feed) `(nnatom ,feed)) dl-gnus-feeds)))
  ;; Gnus has no server failover.  An article missing from the current
  ;; server (expired, taken down) is asked of these in order, the bonus
  ;; server (another backbone) last.  Not subscribable: each would
  ;; duplicate every group.
  (gnus-refer-article-method
    `(current
       ,(dl-gnus--frugal "frugal-au" "aunews.frugalusenet.com")
       ,(dl-gnus--frugal "frugal-eu" "eunews.frugalusenet.com")
       ,(dl-gnus--frugal "frugal-bonus" "bonus.frugalusenet.com"))))

(use-package gnus-msg
  :defer t
  :custom
  ;; Fastmail does not file SMTP-sent mail; Gcc a copy to its Sent
  ;; folder so it shows on every client, not in a local nnfolder.
  (gnus-message-archive-group "nnimap+fastmail:Sent")
  (gnus-gcc-mark-as-read t))

(declare-function gnus-summary-move-article "gnus-sum")

(defun my/gnus-summary-archive (&optional n)
  "Archive the process-marked articles, or the next N, as Fastmail does.
Moves them to `dl-gnus-archive-group'."
  (interactive "P" gnus-summary-mode)
  (gnus-summary-move-article n dl-gnus-archive-group))

(defun dl-gnus--yield-meow-keys ()
  "Give the summary buffer back `/' (limit) and `!' (tick) from meow.
Meow's motion state binds them; its `o' (`C-c') and `SPC' (leader) stay."
  (dl-keymap-shadow-yield 'meow-motion-mode "/" "!"))

(use-package gnus-sum
  :defer t
  :hook (gnus-summary-mode . dl-gnus--yield-meow-keys)
  :bind (:map gnus-summary-mode-map ("y" . my/gnus-summary-archive)))

(use-package smtpmail
  :defer t
  :custom
  (smtpmail-smtp-server "smtp.fastmail.com")
  (smtpmail-smtp-service 465)
  (smtpmail-stream-type 'ssl)
  (smtpmail-smtp-user dl-gnus-login)
  ;; Authenticate up front.  Otherwise smtpmail tries anonymously and
  ;; retries with a password prompt only if it already attempted a
  ;; login, which with no stored credential it never has: it just
  ;; fails "530 Authentication required".
  (smtpmail-servers-requiring-authorization
    (rx bos "smtp.fastmail.com" eos)))

(use-package message
  :defer t
  :custom
  (message-send-mail-function #'smtpmail-send-it))

(provide 'dl-gnus)
;;; dl-gnus.el ends here
