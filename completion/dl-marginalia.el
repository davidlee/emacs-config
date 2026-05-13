;;; dl-marginalia.el --- MARGINALIA -*- lexical-binding: t; -*-

(use-package marginalia
  :ensure t
  :config
  (marginalia-mode)
  ;; MHHH
  (with-eval-after-load 'dl-term
    (my/shpool-marginalia-setup)))

(provide 'dl-marginalia)
