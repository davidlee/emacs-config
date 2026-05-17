;;; dl-denote.el --- DENOTE config -*- lexical-binding: t; -*-

(require 'dl-notes-paths)

;; Bindings live in `core/dl-keymap.el' under the consolidated `C-c n …'
;; map (`my-notes-map' + sub-prefixes).  Keep this module to settings only.
(use-package denote
  :custom
  (denote-directory dl-notes-root)
  (denote-known-keywords
    '("pkm" "writing" "reading" "project" "area" "source" "slip"
       "reference" "index" "journal" "weekly" "emacs"
       "idea" "draft" "meeting" "person" "work"
       "work-relevant" "work-adjacent" "management" "technical-leadership"))
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-file-type 'org)
  (denote-prompts '(title keywords)))


(provide 'dl-denote)
