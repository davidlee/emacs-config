;;; ddl-org.el --- ORG  -*- lexical-binding: t; -*-

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
    '( ("@work" . ?w)
       ("@home" . ?h)
       ("reading" . ?r)
       ("writing" . ?W)
       ("idea" . ?i)
       ("pkm" . ?p)))
  :config
  (setq org-agenda-files
    '( "~/notes/inbox.org"
       "~/notes/projects"
       "~/notes/journal"
       "~/notes/writing")))

(global-set-key (kbd "C-c a") #'org-agenda)
(global-set-key (kbd "C-c c") #'org-capture)
(global-set-key (kbd "C-c l") #'org-store-link)

;; Capture bodies use `(function (lambda () (string-join '(...) "\n")))'
;; so each line of the resulting template reads as its own list entry —
;; easier to scan than one long string of `\n'-separated chunks.

(setq org-capture-templates
  `(("i" "Inbox" entry
      (file "~/notes/inbox.org")
      (function (lambda ()
                  (string-join
                    '("* TODO %?"
                       ":PROPERTIES:"
                       ":CREATED: %U"
                       ":END:")
                    "\n"))))

     ("f" "Fleeting note" entry
       (file "~/notes/inbox.org")
       (function (lambda ()
                   (string-join
                     '("* %?"
                        ":PROPERTIES:"
                        ":CREATED: %U"
                        ":END:")
                     "\n"))))

     ("j" "Journal entry" entry
       (file+datetree "~/notes/journal/log.org")
       "* %U %?\n")

     ("P" "Project task" entry
       (file "~/notes/inbox.org")
       (function (lambda ()
                   (string-join
                     '("* TODO %?"
                        ":PROPERTIES:"
                        ":CREATED: %U"
                        ":END:"
                        ":project:")
                     "\n"))))

     ("r" "Reading note" entry
       (file "~/notes/inbox.org")
       (function (lambda ()
                   (string-join
                     '("* Reading: %?"
                        ":PROPERTIES:"
                        ":CREATED: %U"
                        ":END:")
                     "\n"))))

     ("p" "Protocol" entry
       (file+headline ,(expand-file-name "protocol.org" org-directory) "Inbox")
       (function (lambda ()
                   (string-join
                     '("* %^{Title|%:description}"
                        "Source: %:link"
                        "Captured: %U"
                        ""
                        "#+BEGIN_QUOTE"
                        "%i"
                        "#+END_QUOTE"
                        ""
                        "%?%(progn (setq my/org-capture-delete-frame-on-finalize t) \"\")")
                     "\n")))
       :empty-lines 1)

     ("L" "Protocol Link" entry
       (file+headline ,(expand-file-name "protocol.org" org-directory) "Inbox")
       (function (lambda ()
                   (string-join
                     '("* %? [[%:link][%(my/sanitize-link-description \"%:description\")]]"
                        "Captured: %U"
                        "%(progn (setq my/org-capture-delete-frame-on-finalize t) \"\")")
                     "\n")))
       :empty-lines 1)))

;; Org-protocol helpers — sanitizing link descriptions and auto-closing
;; the emacsclient-spawned frame after the browser-driven capture finishes.

(defun my/sanitize-link-description (s)
  "Replace [ and ] in S with ( and ).
Page titles can contain square brackets (ArXiv is the canonical
offender), which break `[[link][description]]'."
  (replace-regexp-in-string
    "\\]" ")"
    (replace-regexp-in-string "\\[" "(" s)))

(defvar my/org-capture-delete-frame-on-finalize nil
  "When non-nil, delete the current frame after the next capture finishes.
Set by Protocol templates so the emacsclient-spawned frame goes away
when the user finalizes or aborts.  Guarded to no-op unless the frame
was actually created by emacsclient, so local `\\[org-capture]' invocations
in the main frame are safe.")

(defun my/org-capture-delete-client-frame (&rest _)
  "Delete current frame iff a capture template asked for it."
  (when (and my/org-capture-delete-frame-on-finalize
          (frame-parameter nil 'client)
          (cdr (frame-list)))         ; never delete the last frame
    (setq my/org-capture-delete-frame-on-finalize nil)
    (delete-frame)))

;; `org-capture-refile' calls `org-capture-finalize' internally, so the
;; finalize advice covers refile too; only kill needs separate wiring.
(advice-add 'org-capture-finalize :after #'my/org-capture-delete-client-frame)
(advice-add 'org-capture-kill     :after #'my/org-capture-delete-client-frame)

;; (add-hook 'org-mode-hook
;;   (lambda ()
;;     (add-to-list 'org-capture-templates
;;       ;; The template follows
;;       '("capture"
;;          "Capture (Org Protocol)"
;;          entry
;;          (file "protocol.org")
;;          (function (lambda ()
;;                      (string-join
;;                        '("* %:description"
;;                           ":PROPERTIES:"
;;                           ":CREATED: %U"
;;                           ":END:"
;;                           "%:annotation"
;;                           "%i"
;;                           ""
;;                           "%?")
;;                        "\n")))
;;          :prepend t
;;          :empty-lines 1)
;;       ;; End template
;;       )))


(global-set-key (kbd "C-c c") #'org-capture)

(use-package org-modern
  :after
  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda))

;; style hax
(use-package org-bullets)

(setq org-startup-indented t
  org-bullets-bullet-list '(" ") ;; no bullets, needs org-bullets package
  org-ellipsis "  " ;; folding symbol
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
;;
;; custom functions for periodic notes
;;
(defun my/daily-note ()
  "Open today's plain Org daily note."
  (interactive)
  (let* ((dir (expand-file-name "2026" org-directory))
          (file (expand-file-name
                  (format-time-string "%Y-%m-%d.org")
                  dir)))
    (make-directory dir t)
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title: " (format-time-string "%Y-%m-%d %A") "\n")
      (insert "#+filetags: :journal:\n\n")
      (insert "* Focus\n\n* Notes\n\n* Log\n")
      )))

(defun my/weekly-note ()
  "Open this week's plain Org weekly note."
  (interactive)
  (let* ((dir (expand-file-name "2026" org-directory))
          (file (expand-file-name
                  (format-time-string "%G-W%V.org")
                  dir)))
    (make-directory dir t)
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title: " (format-time-string "Week %G-W%V") "\n")
      (insert "#+filetags: :journal:weekly:\n\n")
      (insert "* Review\n\n* Projects\n\n* Notes promoted\n\n* Next week\n"))))

;; and keybinds

(global-set-key (kbd "C-c n d") #'my/daily-note)
(global-set-key (kbd "C-c n w") #'my/weekly-note)

;; (add-hook 'org-mode-hook #'variable-pitch-mode)
(provide 'dl-org)

;;;;;;;;;;;;;;;;
;; cheatsheet ;;
;;;;;;;;;;;;;;;;

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

;;; dl-org.el ends here
