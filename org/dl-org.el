;;; dl-org.el --- Org defaults, TODO states, styling -*- lexical-binding: t; -*-

;; Slim core.  Capture lives in `dl-org-capture', agenda in
;; `dl-org-agenda', store/insert/open links in `dl-org-links', and
;; daily/weekly note builders in `dl-denote-journal'.

(require 'dl-notes-paths)

(use-package org
  :ensure nil
  :custom
  (org-directory dl-notes-root)
  (org-default-notes-file dl-notes-inbox-file)
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-return-follows-link t)
  (org-use-speed-commands t)
  (org-log-done 'time)
  (org-todo-keywords
    '((sequence "TODO(t)" "NEXT(n)" "STARTED(s)" "WAITING(w@/!)"
                "|" "DONE(d!)" "CANCELED(c@)" "MOVED(m@)")))
  (org-tag-alist
    '( ("@work" . ?w)
       ("@home" . ?h)
       ("reading" . ?r)
       ("writing" . ?W)
       ("idea" . ?i)
       ("pkm" . ?p))))

(use-package org-modern
  :after
  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda))

;; style hax
(use-package org-bullets)

(setq org-startup-indented t
  org-bullets-bullet-list '(" ") ;; no bullets, needs org-bullets package
  org-ellipsis "  " ;; folding symbol
  org-pretty-entities t
  org-hide-emphasis-markers t
  ;; show actually italicized text instead of /italicized text/
  org-agenda-block-separator ""
  org-fontify-whole-heading-line t
  org-fontify-done-headline t
  org-fontify-quote-and-verse-blocks t)

;; fiddle spacing
(add-hook 'org-mode-hook
  (lambda () (progn
               (setq left-margin-width 2)
               (setq right-margin-width 2)
               ;; (setq header-line-format " ")
               (hl-line-mode nil)
               (set-window-buffer nil (current-buffer)))))

;; (add-hook 'org-mode-hook #'variable-pitch-mode)
(provide 'dl-org)

;;;;;;;;;;;;;;;;
;; cheatsheet ;;
;;;;;;;;;;;;;;;;

;; C-c c     capture
;; C-c a     agenda
;; C-c l     store link
;; C-c C-t   cycle TODO state
;; C-c C-s   schedule
;; C-c C-d   deadline
;; C-c C-o   open link
;; TAB       fold/unfold
;; M-RET     new heading
;; M-S-RET   new TODO heading
;; M-up/down move heading
;; M-left/right promote/demote heading

;;; dl-org.el ends here
