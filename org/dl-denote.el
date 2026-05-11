;;; dl-denote.el --- DENOTE config -*- lexical-binding: t; -*-

(use-package denote
  :custom
  (denote-directory (expand-file-name "~/notes"))
  (denote-known-keywords
    '("pkm" "writing" "reading" "project" "journal" "emacs"
       "idea" "reference" "source" "draft" "meeting"))
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-file-type 'org)
  (denote-prompts '(title keywords))
  :bind
  (("C-c n n" . denote)
    ("C-c n l" . denote-link)
    ("C-c n b" . denote-backlinks)
    ("C-c n r" . denote-rename-file)
    ("C-c n R" . denote-rename-file-using-front-matter)))


(provide 'dl-denote)
