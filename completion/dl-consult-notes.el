;;; dl-consult-notes.el --- consult-notes with per-class sources -*- lexical-binding: t; -*-

;; Backs `C-c n f' (`consult-notes') and `C-c n s'
;; (`consult-notes-search-in-all-notes'), bound in `core/dl-keymap.el'.
;;
;; Per-class sources expose each notes subdir as a narrowable bucket
;; (e.g. press `j SPC' at the consult prompt to scope to journal/).
;; `consult-notes-denote-mode' picks up bare Denote-named files at
;; `dl-notes-root' that don't live in a class subdir (root-level legacy
;; notes pending Phase 7 triage).

(require 'dl-notes-paths)

(use-package consult-notes
  :commands (consult-notes consult-notes-search-in-all-notes)
  :custom
  (consult-notes-file-dir-sources
    `( ;; ("Journal"    ?j ,dl-notes-journal-dir)
       ;; ("Weekly"     ?w ,dl-notes-weekly-dir)
       ("Projects"   ?p ,dl-notes-projects-dir)
       ("Areas"      ?a ,dl-notes-areas-dir)
       ("Sources"    ?s ,dl-notes-sources-dir)
       ("Slips"      ?S ,dl-notes-slips-dir)
       ("References" ?r ,dl-notes-references-dir)
       ("Indexes"    ?i ,dl-notes-indexes-dir)))
  :config
  (when (fboundp 'consult-notes-denote-mode)
    (consult-notes-denote-mode 1)))

(provide 'dl-consult-notes)
;;; dl-consult-notes.el ends here
