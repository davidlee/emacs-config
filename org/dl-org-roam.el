;;; dl-org-roam.el --- ORG ROAM as Denote DB -*- lexical-binding: t; -*-

;; https://github.com/BardofSprites/denote-roam/blob/master/denote-roam.el

(require 'dl-notes-paths)

;; Org-roam
(use-package org-roam
  :after org
  :custom
  (org-roam-directory (file-truename dl-notes-root))
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
  ;; Bindings live in `my-roam-map' at `C-c n r' via `core/dl-keymap.el'.
  :commands ( org-roam-node-find org-roam-node-insert
              org-roam-buffer-toggle org-roam-capture
              org-roam-db-sync org-roam-graph)
  :config
  (require 'org-roam-graph)
  (org-roam-db-autosync-mode 1))

(provide 'dl-org-roam)
