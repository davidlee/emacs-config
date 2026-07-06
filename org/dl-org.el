;;; dl-org.el --- Org defaults, TODO states, styling -*- lexical-binding: t; -*-

;; Slim core.  Capture lives in `dl-org-capture', agenda in
;; `dl-org-agenda', store/insert/open links in `dl-org-links', and
;; daily/weekly note builders in `dl-denote-journal'.

(require 'dl-notes-paths)

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
       ("reading" . ?r)
       ("writing" . ?W)
       ("idea" . ?i)
       ("pkm" . ?p)))
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

;; Add frame borders and window dividers
(modify-all-frames-parameters
  '((right-divider-width . 40)
     (internal-border-width . 40)))
(dolist (face '(window-divider
                 window-divider-first-pixel
                 window-divider-last-pixel))
  (face-spec-reset-face face)
  (set-face-foreground face (face-attribute 'default :background)))
(set-face-background 'fringe (face-attribute 'default :background))

(use-package org-bullets
  :hook (org-mode .(lambda  () org-bullets-mode 1))
  :after org-modern)

(defun my/org-hl-line-strip-bg ()
  "Strip :background from hl-line overlays, keeping :underline."
  (dolist (ov (overlays-at (point)))
    (when (eq (overlay-get ov 'face) 'hl-line)
      (overlay-put ov 'face '(:underline t)))))

(defun my/org-setup-margins ()
  "Buffer-local margin + hl-line tweaks for org buffers."
  (setq left-margin-width 2
    right-margin-width 2)
  ;; hl-line overlay clobbers org-modern pill backgrounds (text properties
  ;; lose to overlays). Intercept overlay after each highlight to strip bg.
  (add-hook 'post-command-hook #'my/org-hl-line-strip-bg 90 t)
  ;; Option B: disable hl-line entirely in org if remap isn't enough
  ;; (hl-line-mode -1)
  (set-window-buffer nil (current-buffer)))

(add-hook 'org-mode-hook #'my/org-setup-margins)

;;(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))
;;(add-hook 'org-mode-hook (lambda () (org-pretty-table-mode)))

;; (use-package org-pretty-table)

;; this is a checkout of my fork since the original was busted and so is the nix upstream
;; davidlee/org-timeblock
(use-package org-timeblock
  :ensure nil
  :demand t
  :config
  (define-key org-timeblock-mode-map [remap meow-prev] #'org-timeblock-backward-block)
  (define-key org-timeblock-mode-map [remap meow-next] #'org-timeblock-forward-block)
  (define-key org-timeblock-list-mode-map [remap meow-prev] #'org-timeblock-list-previous-line)
  (define-key org-timeblock-list-mode-map [remap meow-next] #'org-timeblock-list-next-line))

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
