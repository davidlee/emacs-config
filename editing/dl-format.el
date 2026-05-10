;;; dl-format.el --- editor language formatting  -*- lexical-binding: t; -*-

;; (use-package format-all
;;   :commands format-all-mode
;;   :hook (prog-mode . format-all-mode)
;;   :config
;;   (setq-default format-all-formatters
;;                 '(("C"     (astyle "--mode=c"))
;;                   ("Shell" (shfmt "-i" "4" "-ci")))))

(use-package editorconfig
  :init
  (editorconfig-mode 1))

(use-package ws-butler
  :hook ((prog-mode text-mode) . ws-butler-mode))

(use-package apheleia
  :config
  (apheleia-global-mode +1))

(provide 'dl-format)
