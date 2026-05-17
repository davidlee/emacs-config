;;; dl-org.el --- ORG  -*- lexical-binding: t; -*-

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
       ("pkm" . ?p)))
  :config
  (setq org-agenda-files
    (list dl-notes-inbox-file
          dl-notes-projects-dir
          dl-notes-journal-dir
          dl-notes-weekly-dir)))

(global-set-key (kbd "C-c a") #'org-agenda)
(global-set-key (kbd "C-c c") #'org-capture)
(global-set-key (kbd "C-c l") #'org-store-link)

;; Capture-body helpers.  Each builder returns a 0-arg function that
;; assembles the body lazily, so templates read one line per list entry
;; instead of a single string speckled with `\n'.

(defun my/capture-body (&rest lines)
  "Return a 0-arg fn that joins LINES with newlines into a capture body."
  (lambda () (string-join lines "\n")))

(defun my/capture-entry (heading &rest body-lines)
  "Like `my/capture-body' but wraps HEADING with a standard properties drawer.
Result:
  HEADING
  :PROPERTIES:
  :CREATED: %U
  :END:
  BODY-LINES..."
  (apply #'my/capture-body
    heading
    ":PROPERTIES:"
    ":CREATED: %U"
    ":END:"
    body-lines))

(setq org-capture-templates
  `(("i" "Inbox" entry
      (file ,dl-notes-inbox-file)
      (function ,(my/capture-entry "* TODO %?")))

     ("f" "Fleeting note" entry
       (file ,dl-notes-inbox-file)
       (function ,(my/capture-entry "* %?")))

     ("j" "Journal entry" entry
       (file+datetree ,(my/notes-path "journal" "log.org"))
       "* %U %?\n")

     ("P" "Project task" entry
       (file ,dl-notes-inbox-file)
       (function ,(my/capture-entry "* TODO %?" ":project:")))

     ("r" "Reading note" entry
       (file ,dl-notes-inbox-file)
       (function ,(my/capture-entry "* Reading: %?")))

     ;; these last two are for https://github.com/sprig/org-capture-extension
     ("p" "Protocol" entry
       (file+headline ,(my/notes-path "protocol.org") "Inbox")
       (function ,(my/capture-body
                    "* %^{Title|%:description}"
                    "Source: %:link"
                    "Captured: %U"
                    ""
                    "#+BEGIN_QUOTE"
                    "%i"
                    "#+END_QUOTE"
                    ""
                    "%?%(progn (setq my/org-capture-delete-frame-on-finalize t) \"\")"))
       :empty-lines 1)

     ("L" "Protocol Link" entry
       (file+headline ,(my/notes-path "protocol.org") "Inbox")
       (function ,(my/capture-body
                    "* %? [[%:link][%(my/sanitize-link-description \"%:description\")]]"
                    "Captured: %U"
                    "%(progn (setq my/org-capture-delete-frame-on-finalize t) \"\")"))
       :empty-lines 1)))

;; Org-protocol helpers — sanitizing link descriptions and auto-closing
;; the emacsclient-spawned frame after the browser-driven capture finishes.

(defun my/sanitize-link-description (s)
  "Replace [ and ] in S with ( and ).
Page titles can contain square brackets (ArXiv is the canonical
offender), which break `[[link][description]]'."
  (replace-regexp-in-string   "\\]" ")"
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
;; NOTE: Phase 1 keeps the simple-name format and just points at the new
;; dirs (journal/, weekly/).  Phase 3 replaces these with Denote-named
;; equivalents — see plans/yes-use-dl-for-staged-quiche.md.
(defun my/daily-note ()
  "Open today's plain Org daily note."
  (interactive)
  (let ((file (expand-file-name
                (format-time-string "%Y-%m-%d.org")
                dl-notes-journal-dir)))
    (find-file file)
    (when (= (point-max) 1)
      (insert "#+title: " (format-time-string "%Y-%m-%d %A") "\n")
      (insert "#+filetags: :journal:\n\n")
      (insert "* Focus\n\n* Notes\n\n* Log\n"))))

(defun my/weekly-note ()
  "Open this week's plain Org weekly note."
  (interactive)
  (let ((file (expand-file-name
                (format-time-string "%G-W%V.org")
                dl-notes-weekly-dir)))
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
