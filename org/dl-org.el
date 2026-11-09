;;; dl-org.el --- Org defaults, TODO states, styling -*- lexical-binding: t; -*-

;; Slim core.  Capture lives in `dl-org-capture', agenda in
;; `dl-org-agenda', and
;; daily/weekly note builders in `dl-denote-journal'.

(require 'dl-notes-paths)
(require 'dl-faces)                    ; my/apply-org-faces (org-mode hook)

(use-package org
  :ensure nil
  :mode ("\\.org\\'" . org-mode)
  :custom
  (org-directory dl-notes-root)
  (org-default-notes-file dl-notes-inbox-file)
  (org-startup-indented t)
  (org-hide-emphasis-markers t)
  (org-return-follows-link t)
  (org-use-speed-commands t)
  (org-log-done 'time)
  (org-blank-before-new-entry '((heading . nil) (plain-list-item . nil)))

  ;; (org-ellipsis "  ")
  (org-catch-invisible-edits 'show-and-error)
  (org-special-ctrl-a/e t)
  (org-auto-align-tags nil)
  (org-ellipsis "…")
  (org-pretty-entities t)
  (org-agenda-block-separator "")
  (org-fontify-whole-heading-line t)
  (org-fontify-done-headline t)
  (org-fontify-quote-and-verse-blocks t)
  (org-id-link-to-org-use-id 'create-if-interactive)
  (org-todo-keywords
   '((sequence "TODO(t)" "NEXT(n)" "STARTED(s)" "WAITING(w@/!)" "MAYBE(m/!)"
               "|" "DONE(d!)" "CANCELED(c@)" "MOVED(v@)")))
  (org-tag-alist
   '( ("@work" . ?w)
      ("@home" . ?h)
      ("read" . ?r)
      ("write" . ?W)
      ("tech" . ?t)
      ("idea" . ?i)
      ("domestic" . ?d)
      ("admin" . ?a)
      ("errand" . ?e)
      ("satan" . ?s)
      ("unread" . ?u)
      ("project" . ?p)
      ("org" . ?o)))
  (org-clock-sound ; for org-timer-start-timer, poor man's pomodoro
   "/mnt/500G/home/david/.local/share/Steam/steamui/sounds/timer_expired_alarm.wav")
  :config
  (require 'ox-md)) ; markdown export

(use-package org-modern
  :hook ( (org-mode            . org-modern-mode)
          (org-mode            . my/apply-org-faces)
          (org-agenda-finalize . org-modern-agenda))

  :custom
  (org-tags-column 0)
  ;; styling
  (org-agenda-tags-column 0)
  (org-modern-star 'replace)
  (org-modern-block-fringe nil)
  (org-modern-table nil)
  :config
  (global-org-modern-mode))

(use-package org-bullets
  :hook (org-mode .(lambda  () org-bullets-mode 1))
  :after org-modern)

(defun my/org-setup-margins ()
  "Buffer-local margins for org buffers."
  (setq left-margin-width 2
        right-margin-width 2)
  (my/refresh-window-margins))

(defvar hl-line-range-function)

(defun dl-org--hl-line-range ()
  "Return the current line's bounds, starting after any TODO keyword.
`org-modern' paints the keyword with a text property, and the `hl-line'
overlay would repaint its background whatever the overlay's priority."
  (let ((case-fold-search nil))
    (save-excursion
      (beginning-of-line)
      (cons (if (and (looking-at org-todo-line-regexp) (match-end 2))
                (match-end 2)
              (point))
            (line-beginning-position 2)))))

(defun my/org-setup-line-display ()
  "Undo the prose defaults that fight org's own line display.
`org-indent-mode' aligns wrapped list items under their text, and
`visual-wrap-prefix-mode' would overwrite that with a prefix which ignores
heading depth.  `global-hl-line-mode' already highlights the line, so the
local `hl-line-mode' is redundant."
  (hl-line-mode -1)
  (setq-local hl-line-range-function #'dl-org--hl-line-range)
  (when (bound-and-true-p org-indent-mode)
    (visual-wrap-prefix-mode -1)))

(add-hook 'org-mode-hook #'my/org-setup-margins)
(add-hook 'org-mode-hook #'my/org-setup-line-display)

;;(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))

(add-to-list 'load-path "~/.config/emacs/elpa/org-pretty-table")
(require 'org-pretty-table)
(add-hook 'org-mode-hook (lambda () (org-pretty-table-mode)))


;; this is a checkout of my fork since the original was busted and so is the nix upstream
;; davidlee/org-timeblock
(use-package org-timeblock
  :ensure nil
  :demand t
  :bind (:map org-timeblock-mode-map
              ([remap meow-prev] . org-timeblock-backward-block)
              ([remap meow-next] . org-timeblock-forward-block)
              :map org-timeblock-list-mode-map
              ([remap meow-prev] . org-timeblock-list-previous-line)
              ([remap meow-next] . org-timeblock-list-next-line)))

(use-package org-alert
  :custom
  (alert-default-style 'libnotify)
  (org-alert-interval 300)
  (org-alert-notify-cutoff 10)
  (org-alert-notify-after-event-cutoff 10)
  :config
  (org-alert-enable))

(add-hook 'org-mode-hook (lambda () (setq tab-width 2)))

(require 'dl-org-paste-markdown)

;; (use-package book-mode :vc (:url "https://github.com/rougier/book-mode.git"))

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

(provide 'dl-org)
;; dl-org.el ends here
;;; dl-org.el ends here
