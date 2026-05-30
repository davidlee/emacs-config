;;; dl-eca.el --- ECA coding agents -*- lexical-binding: t; -*-

;; https://github.com/editor-code-assistant/eca-emacs
;; TODO keybindings

(use-package eca
  :ensure nil
  :custom (eca-custom-command '("/run/wrappers/bin/op" "run" "--" "/home/david/.emacs.d/eca/eca" "server"))
  :vc (:url "https://github.com/editor-code-assistant/eca-emacs" :rev :newest))

(provide 'dl-eca)
;;; dl-eca.el ends here
