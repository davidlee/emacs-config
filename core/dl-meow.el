;;; dl-meow.el --- Meow modal bindings -*- lexical-binding: t; -*-

(defun my/find-dwim ()
  ())

(use-package meow
  :config
  :after dl-keymap
  (meow-setup)
  (meow-global-mode 1))

;; (use-package meow-vterm
;;   :vc (:url "https://github.com/accelbread/meow-vterm.git")
;;   :config
;;  (meow-vterm-enable))


;; +TODO+ binding for:
;; vterm-send-escape

(setq meow-mode-state-list (append meow-mode-state-list '((vterm-mode . insert))))
(defun my-disable-meow-in-vterm ()
  (when (derived-mode-p 'vterm-mode)
    (meow-mode -1)))

(add-hook 'vterm-mode-hook #'my-disable-meow-in-vterm)
(provide 'dl-meow)
;;; dl-meow.el ends here
