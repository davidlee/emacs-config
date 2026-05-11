(use-package org
  :ensure nil
  :custom
  (org-directory "~/notes")
  (org-default-notes-file "~/notes/inbox.org")
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-return-follows-link t)
  (org-use-speed-commands t)
  (org-log-done 'time)
  (org-todo-keywords
   '((sequence "TODO(t)" "NEXT(n)" "WAIT(w)" "|" "DONE(d)" "CANCELLED(c)")))
  (org-tag-alist
   '(("@work" . ?w)
     ("@home" . ?h)
     ("reading" . ?r)
     ("writing" . ?W)
     ("idea" . ?i)
     ("pkm" . ?p)))
  :config
  (setq org-agenda-files
        '("~/notes/inbox.org"
          "~/notes/projects"
          "~/notes/journal"
          "~/notes/writing")))

(global-set-key (kbd "C-c a") #'org-agenda)
(global-set-key (kbd "C-c c") #'org-capture)
(global-set-key (kbd "C-c l") #'org-store-link)

(setq org-capture-templates
      `(("i" "Inbox" entry
         (file "~/notes/inbox.org")
         "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

        ("f" "Fleeting note" entry
         (file "~/notes/inbox.org")
         "* %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")

        ("j" "Journal entry" entry
         (file+datetree "~/notes/journal/log.org")
         "* %U %?\n")

        ("p" "Project task" entry
         (file "~/notes/inbox.org")
         "* TODO %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n:project:\n")

        ("r" "Reading note" entry
         (file "~/notes/inbox.org")
         "* Reading: %?\n:PROPERTIES:\n:CREATED: %U\n:END:\n")))

(provide 'dl-org)


;;
;; usage
;;
;; C-c c     capture
;; C-c a     agenda
;; C-c C-t   cycle TODO state
;; C-c C-s   schedule
;; C-c C-d   deadline
;; C-c C-o   open link
;; TAB       fold/unfold
;; M-RET     new heading
;; M-S-RET   new TODO heading
;; M-up/down move heading
;; M-left/right promote/demote heading
