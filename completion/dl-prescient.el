;;; dl-prescient.el --- PRESCIENT -*- lexical-binding: t; -*-

(use-package prescient
  :functions prescient-persist-mode
  :config
  (prescient-persist-mode 1))

(use-package vertico-prescient
  :after (vertico prescient)
  :config
  (vertico-prescient-mode 1))

(provide 'dl-prescient)
