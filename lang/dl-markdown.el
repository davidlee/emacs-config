;;; dl-markdown.el --- MARKDOWN  -*- lexical-binding: t; -*-

;; The markdown-mode package provides a major mode for Emacs for syntax
;; highlighting, editing commands, and preview support for Markdown documents.
;; It supports core Markdown syntax as well as extensions like GitHub Flavored
;; Markdown (GFM).
;; URL: https://github.com/jrblevin/markdown-mode
(use-package markdown-mode
  :commands (gfm-mode
              gfm-view-mode
              markdown-mode
              markdown-view-mode)
  :mode (("\\.markdown\\'" . markdown-mode)
          ("\\.md\\'" . markdown-mode)
          ("README\\.md\\'" . gfm-mode))
  :bind
  (:map markdown-mode-map
    ("C-c C-e" . markdown-do)))

(use-package visual-fill-column
  :hook ((markdown-mode org-mode text-mode) . visual-fill-column-mode))

(use-package grip-mode
  :after markdown-mode)

(use-package markdown-toc
  :after markdown-mode)

(provide 'dl-markdown)
