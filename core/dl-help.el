;;; dl-help.el --- antisuck help -*- lexical-binding: t; -*-

(use-package helpful
  :bind (("C-h f" . helpful-callable)
          ("C-h v" . helpful-variable)
          ("C-h k" . helpful-key)
          ("C-h x" . helpful-command)
          ("C-c C-d" . helpful-at-point)))
(provide 'dl-help)
