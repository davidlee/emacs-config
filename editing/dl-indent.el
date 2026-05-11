
;; (setopt indent-tabs-mode nil)
;; (setopt tab-width 2)

(setq-default tab-width 2)
(setq-default standard-indent 2)
(setopt c-basic-offset tab-width)
(setq-default electric-indent-inhibit t)
(setq-default indent-tabs-mode nil)
(setopt backward-delete-char-untabify-method 'nil)

(provide 'dl-indent)
