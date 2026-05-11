;;; dl-org-roam.el --- ORG ROAM as Denote DB -*- lexical-binding: t; -*-

;; Org-roam
(use-package org-roam
  :after org
  :custom
  (org-roam-directory (file-truename org-directory))
  (org-roam-db-location
    (expand-file-name ".org-roam.db" org-roam-directory))
  (org-roam-completion-everywhere t)
  (org-roam-capture-templates
    '(("d" "default" plain
        "%?"
        :target
        (file+head
          "notes/%<%Y%m%dT%H%M%S>--${slug}__pkm.org"
          "#+title: ${title}\n#+filetags: :pkm:\n")
        :unnarrowed t)

       ("p" "project" plain
         "%?"
         :target
         (file+head
           "projects/%<%Y%m%dT%H%M%S>--${slug}__project.org"
           "#+title: ${title}\n#+filetags: :project:\n")
         :unnarrowed t)

       ("r" "reference" plain
         "%?"
         :target
         (file+head
           "refs/%<%Y%m%dT%H%M%S>--${slug}__reference.org"
           "#+title: ${title}\n#+filetags: :reference:\n")
         :unnarrowed t)))
  :bind
  (("C-c r f" . org-roam-node-find)
    ("C-c r i" . org-roam-node-insert)
    ("C-c r b" . org-roam-buffer-toggle)
    ("C-c r c" . org-roam-capture)
    ("C-c r s" . org-roam-db-sync))
  :config
  (require 'org-roam-graph)
  (global-set-key (kbd "C-c r g") #'org-roam-graph)
  (org-roam-db-autosync-mode 1))

(provide 'dl-org-roam)
