;;; dl-satan.el --- integration with SATAN (github.com:davidlee/satan) -*- lexical-binding: t; -*-
(unless (eq system-type 'darwin)
  (use-package satan
    :ensure nil
    :demand t
    :custom
    (satan-notes-root "~/notes")
    (satan-mcp-enabled t)
    (satan-goad-enabled t)
    ;; 1Password backend (dl-secret.el, required below; resolved at call time).
    (satan-credential-function #'my/satan-credential)
    (satan-journal-today
      (lambda ()
        (my/journal--ensure-today)
        (my/journal--today-file dl-notes-journal-dir "journal")))))

(provide 'dl-satan)
;;; dl-satan.el ends here
