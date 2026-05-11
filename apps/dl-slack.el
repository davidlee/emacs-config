;;; dl-slack.el --- Slack client -*- lexical-binding: t; -*-

(load (expand-file-name "dl-slack.secret.el" user-emacs-directory) t)

(use-package alert
  :commands (alert)
  :init
  (setq alert-default-style 'notifier))

(use-package slack
  :bind (("C-c S K" . slack-stop)
          ("C-c S c" . slack-select-rooms)
          ("C-c S u" . slack-select-unread-rooms)
          ("C-c S U" . slack-user-select)
          ("C-c S s" . slack-search-from-messages)
          ("C-c S J" . slack-jump-to-browser)
          ("C-c S j" . slack-jump-to-app)
          ("C-c S e" . slack-insert-emoji)
          ("C-c S E" . slack-message-edit)
          ("C-c S r" . slack-message-add-reaction)
          ("C-c S t" . slack-thread-show-or-create)
          ("C-c S g" . slack-message-redisplay)
          ("C-c S G" . slack-conversations-list-update-quick)
          ("C-c S q" . slack-quote-and-reply)
          ("C-c S Q" . slack-quote-and-reply-with-link)

          (:map slack-mode-map
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
