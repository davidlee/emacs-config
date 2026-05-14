;;; dl-marginalia.el --- MARGINALIA -*- lexical-binding: t; -*-

(use-package marginalia
  :config
  (marginalia-mode)
  ;; MHHH
  (with-eval-after-load 'dl-shpool
    (my/shpool-marginalia-setup)))

(provide 'dl-marginalia)
