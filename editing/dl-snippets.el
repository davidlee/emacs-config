;;; dl-snippets.el --- SNIP  -*- lexical-binding: t; -*-

(use-package yasnippet
  :config
  (yas-global-mode 1))

(use-package yasnippet-snippets
  :after yasnippet)

(use-package consult-yasnippet
  :after (consult yasnippet))

(provide 'dl-snippets)
