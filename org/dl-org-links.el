;;; dl-org-links.el --- Org link store/insert/open bindings -*- lexical-binding: t; -*-

;; Phase 4 (notes-system plan) will add the consolidated C-c n l/i/o/g
;; namespace (store/insert/open/back).  For now: the global short form
;; only.

(global-set-key (kbd "C-c l") #'org-store-link)

(provide 'dl-org-links)
;;; dl-org-links.el ends here
