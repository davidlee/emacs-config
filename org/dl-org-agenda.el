;;; dl-org-agenda.el --- Org agenda files and commands -*- lexical-binding: t; -*-

(require 'dl-notes-paths)

(setq org-agenda-files
  (list dl-notes-inbox-file
        dl-notes-projects-dir
        dl-notes-journal-dir
        dl-notes-weekly-dir))

(global-set-key (kbd "C-c a") #'org-agenda)

(provide 'dl-org-agenda)
;;; dl-org-agenda.el ends here
