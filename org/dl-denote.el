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

(use-package denote-journal
  :after denote
  :custom
  (denote-journal-directory
   (expand-file-name "2026" denote-directory))
  (denote-journal-keyword "journal")
  :bind
  (("C-c n j" . denote-journal-new-entry)
   ("C-c n J" . denote-journal-new-or-existing-entry)))

(provide 'dl-denote)
