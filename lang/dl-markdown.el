;;; dl-markdown.el --- MARKDOWN  -*- lexical-binding: t; -*-

(use-package markdown-mode
  :mode "\\.md\\'")

(use-package visual-fill-column
  :hook ((markdown-mode org-mode text-mode) . visual-fill-column-mode))

(use-package grip-mode
  :after markdown-mode)

(use-package markdown-toc
  :after markdown-mode)

(provide 'dl-markdown)
