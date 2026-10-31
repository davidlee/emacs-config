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
  ;; Margins apply on `set-window-buffer'; refresh only windows already
  ;; showing this buffer.  Background visits (org-alert, agenda) must not
  ;; pull the buffer into the selected window.
  (dolist (window (get-buffer-window-list nil nil t))
    (set-window-buffer window (current-buffer))))

(add-hook 'org-mode-hook #'my/org-setup-margins)

;;(add-hook 'org-mode-hook (lambda () (org-bullets-mode 1)))
;;(add-hook 'org-mode-hook (lambda () (org-pretty-table-mode)))

;; (use-package org-pretty-table)

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

;; (use-package org-review
;;   :bind (:map org-agenda-mode-map
;; ("C-c C-r" . org-review-insert-last-review)))

;; (add-hook 'org-mode-hook #'variable-pitch-mode)

;; PASTE AGENT SLOP AS ORG-MODE
;; can you tell an agent wrote this elisp?
(defun org-paste-markdown-as-org ()
  "Convert Markdown from the clipboard to Org using Pandoc."
  (interactive)
  (unless (executable-find "pandoc")
    (user-error "Pandoc is not available"))
  (let ((markdown (gui-get-selection 'CLIPBOARD 'UTF8_STRING)))
    (unless (and (stringp markdown) (not (string-empty-p markdown)))
      (user-error "Clipboard has no text"))
    (let ((stderr-file (make-temp-file "org-paste-pandoc-"))
           (coding-system-for-read 'utf-8-unix)
           (coding-system-for-write 'utf-8-unix))
      (unwind-protect
        (let ((org-text
                (with-temp-buffer
                  (let ((status (call-process-region
                                  markdown nil "pandoc" nil (list t stderr-file) nil
                                  "-f" "markdown" "-t" "org")))
                    (unless (equal status 0)
                      (user-error "Pandoc failed (%s): %s" status
                        (with-temp-buffer
                          (insert-file-contents stderr-file)
                          (string-trim (buffer-string)))))
                    (require 'org-element)
                    (require 'org-table)
                    ;; Work backwards so alignment cannot move a later table.
                    (dolist (pos (reverse
                                   (org-element-map (org-element-parse-buffer) 'table
                                     (lambda (table)
                                       (when (eq (org-element-property :type table) 'org)
                                         (org-element-property :begin table))))))
                      (when pos
                        (goto-char pos)
                        ;; Pandoc normally emits an Org rule; accept a
                        ;; Markdown-style header separator as well.
                        (forward-line 1)
                        (when (looking-at
                                "[ \t]*|[ \t]*:?-\\{3,\\}:?[ \t]*\\(?:|[ \t]*:?-\\{3,\\}:?[ \t]*\\)+|?[ \t]*$")
                          (replace-match "|-"))
                        (goto-char pos)
                        (org-table-align)))
                    (buffer-substring-no-properties (point-min) (point-max))))))
          (insert org-text))
        (delete-file stderr-file)))))


;; (defun org-paste-markdown-as-org ()
;;   "Modern Wayland clipboard to native Org-mode table and syntax converter."
;;   (interactive)
;;   (unless (executable-find "pandoc") (user-error "Install pandoc first"))
;;   (let* ((coding-system-for-read 'utf-8)
;;           (coding-system-for-write 'utf-8)
;;           ;; Pull the modern Wayland PGTK or GUI clipboard contents directly via Emacs API
;;           (markdown-text (gui-get-selection 'CLIPBOARD 'TEXT))
;;           (start (point)))
;;     (if (not markdown-text)
;;       (message "Clipboard is empty.")
;;       ;; 1. Use an isolated temp buffer to map the markdown safely through pandoc's binary
;;       (let ((org-text (with-temp-buffer
;;                         (insert markdown-text)
;;                         (call-process-region (point-min) (point-max) "pandoc" t t nil
;;                           "-f" "markdown" "-t" "org")
;;                         (buffer-string))))
;;         (insert org-text)
;;         (let ((end (point)))
;;           (save-excursion
;;             (goto-char start)
;;             ;; 2. Hunt down raw grid or block tables and convert them to vanilla Org grids
;;             (while (re-search-forward "^[ \t]*\\(|\\|\\+\\)-" end t)
;;               (let ((table-start (line-beginning-position)))
;;                 (forward-line 1)
;;                 (while (and (< (point) end) (looking-at "^[ \t]*\\(|\\|\\+\\|\\|\\)"))
;;                   (forward-line 1))
;;                 (org-table-convert-region table-start (point))
;;                 (org-table-align))))
;;           (message "Successfully pasted clean Org data!")))))


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

;; dl-org.el ends here
(provide 'dl-org)
