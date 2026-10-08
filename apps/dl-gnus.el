;;; dl-gnus.el --- gnus + fastmail -*- lexical-binding: t; -*-

;; Mail via Fastmail: read over IMAP (nnimap), send over SMTP.
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

(defconst dl-gnus-login "david@davlee.com"
  "Fastmail account login, shared by IMAP and SMTP.")

(setq user-full-name "David Lee"
  user-mail-address "david@davlee.com")

(use-package gnus
  :defer t
  :custom
  ;; No primary (NNTP) server; Fastmail is the only source.
  (gnus-select-method '(nnnil ""))
  (gnus-secondary-select-methods
    `((nnimap "fastmail"
        (nnimap-address "imap.fastmail.com")
        (nnimap-stream ssl)
        (nnimap-user ,dl-gnus-login)))))

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
