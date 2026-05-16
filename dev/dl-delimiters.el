(use-package rainbow-delimiters)
(use-package rainbow-mode)

(use-package rainbow-delimiters
  :hook (prog-mode . rainbow-delimiters-mode))

(use-package rainbow-mode
  :commands rainbow-mode)

(provide 'dl-delimiters)
