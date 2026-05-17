;;; dl-slack.el --- Slack client -*- lexical-binding: t; -*-

(load (expand-file-name "dl-slack.secret.el" user-emacs-directory) t)

(use-package alert
  :commands (alert)
  :init
  (setq alert-default-style 'notifier))

;; Re-enabling slack: do NOT restore the old `C-c S …' global bindings
;; here.  Per Policy (`KEYS.md'), tier-1 letters are owned by the central
;; keymap.  Lift the slack verbs into a `my-slack-map' in
;; `core/dl-keymap.el' under a sub-prefix (e.g. `C-c a s' or `C-c n S')
;; and bind via `my/bind'.  Mode-local maps below are package-owned and
;; remain here.
(use-package slack
  :bind ((:map slack-mode-map
            ("@" . slack-message-embed-mention)
            ("#" . slack-message-embed-channel))

          (:map slack-thread-message-buffer-mode-map
            ("C-c '" . slack-message-write-another-buffer)
            ("@" . slack-message-embed-mention)
            ("#" . slack-message-embed-channel))

          (:map slack-message-buffer-mode-map
            ("C-c '" . slack-message-write-another-buffer))

          (:map slack-message-compose-buffer-mode-map
            ("C-c '" . slack-message-send-from-buffer)))
  ;; :custom
  ;; (slack-extra-subscribed-channels
  ;;   (mapcar #'intern '("some-channel")))
  
  :config

  (slack-register-team
    :name dl/slack-name
    :token dl/slack-token
    ;; :cookie dl/slack-cookie
    :full-and-display-names t
    :default t
    :subscribed-channels nil
    ))

(provide 'dl-slack)
