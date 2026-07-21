;;; dl-theme.el --- Theme settings -*- lexical-binding: t; -*-

(defvar my--themes
  '(doom-one doom-gruvbox doom-nord doom-material doom-ayu-dark
     doom-zenburn doom-one-light doom-one doom-acario-light
     doom-laserwave doom-molokai doom-moonlight doom-dracula))

(defvar my--theme-shortlist
  '())

(defvar my--current-theme-index -1
  "Index of the currently selected theme in `my--themes'.")

(defun my--rotate-themes ()
  "Rotate through `my--themes', disabling currently enabled themes first."
  (interactive)
  (mapc #'disable-theme custom-enabled-themes)
  (setq my--current-theme-index
    (mod (1+ my--current-theme-index) (length my--themes)))
  (let ((theme (nth my--current-theme-index my--themes)))
    (load-theme theme t)
    (message "Loaded theme: %s" theme)))

;;(load-theme 'nano)
(load-theme 'doom-gruvbox)

;; doom-themes-base defines `gnus-group-news-low-empty' to inherit
;; `gnus-group-news-low', while Emacs' builtin defface has news-low
;; inherit news-low-empty.  Together that is an inheritance cycle, which
;; Emacs 30's face validator (`face-spec-set-2' / the C face realizer)
;; now rejects — it aborts `make-frame' (C-x 5 2) with
;;   "Face inheritance results in inheritance cycle: gnus-group-news-low".
;; It is an upstream doom-themes bug (every other gnus-group-news-N-empty
;; face inherits an -empty peer; only -low-empty points at the non-empty
;; face).  A higher-priority `user' override does NOT help — the
;; validator walks doom's own theme-face entry regardless of priority —
;; so repoint that entry in place, across every enabled theme's spec, to
;; the -empty peer.  Runs after each theme enable so `my--rotate-themes'
;; is covered too.
(defun my/break-doom-gnus-face-cycle (&rest _)
  "Repoint `gnus-group-news-low-empty' off `gnus-group-news-low'.
Breaks the latent doom-themes-base inheritance cycle Emacs 30 rejects."
  (when-let ((spec (get 'gnus-group-news-low-empty 'theme-face)))
    (dolist (theme-entry spec)
      (dolist (clause (cadr theme-entry))
        (let ((plist (cadr clause)))
          (when (eq (plist-get plist :inherit) 'gnus-group-news-low)
            (setcar (cdr clause)
                    (plist-put plist :inherit 'gnus-group-news-1-empty))))))
    (put 'gnus-group-news-low-empty 'theme-face spec)
    ;; At init gnus is not loaded, so the face has no defface yet even
    ;; though doom has stamped its `theme-face' — `face-spec-recalc'
    ;; would signal "Invalid face".  The corrected spec above is what
    ;; breaks the cycle; it applies when gnus defines and realises the
    ;; face later.  Only recalc now if the face already exists.
    (when (facep 'gnus-group-news-low-empty)
      (face-spec-recalc 'gnus-group-news-low-empty nil))))

(add-hook 'enable-theme-functions #'my/break-doom-gnus-face-cycle)
(my/break-doom-gnus-face-cycle)

;; (use-package doom-themes
;;   ;;  :bind
;;   ;;(("<f5>" . my--rotate-themes))
;;   :custom
;;   ;; Global settings (defaults)
;;   (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
;;   (doom-themes-enable-italic t) ; if nil, italics is universally disabled
;;   ;; for treemacs users
;;   (doom-themes-treemacs-theme "doom-one") ; use "doom-colors" for less minimal icon theme

;;   ;; Enable flashing mode-line on errors
;;   (doom-themes-visual-bell-config)
;;   ;; Enable custom neotree theme (nerd-icons must be installed!)
;;   (doom-themes-neotree-config)
;;   ;; or for treemacs users
;;   (doom-themes-treemacs-config)
;;   ;; Corrects (and improves) org-mode's native fontification.
;;   (doom-themes-org-config)
;;   :config
;;   (load-theme 'doom-one t))
;; (global-set-key (kbd "<f5>") #'my--rotate-themes)

;; New frames inherit `default-frame-alist' bg/fg before the theme
;; paints them — leaves a black flash (or worse, a permanently black
;; frame in some daemons).  Sync the alist to the active theme after
;; each load so subsequent frames open in the right colours.
(defun my/sync-frame-colors-to-theme (&rest _)
  "Copy current `default' face bg/fg into `default-frame-alist'."
  (let ((bg (face-background 'default nil t))
         (fg (face-foreground 'default nil t)))
    (when bg (setf (alist-get 'background-color default-frame-alist) bg))
    (when fg (setf (alist-get 'foreground-color default-frame-alist) fg))))

(add-hook 'enable-theme-functions #'my/sync-frame-colors-to-theme)
(my/sync-frame-colors-to-theme)



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Distraction mitigation
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(use-package solaire-mode
  :commands solaire-global-mode
  :config
  (solaire-global-mode +1))

;; Olivetti centres prose at `olivetti-body-width'. visual-fill-column does
;; the same thing — partition mode hooks so they don't trample each other.
(use-package olivetti
  ;; :hook ((text-mode org-mode markdown-mode) . olivetti-mode)
  :custom
  (olivetti-body-width 80)
  ;; Default on-hook is `(visual-line-mode)`, which TOGGLES (not enables)
  ;; visual-line-mode -- so it flips OFF in buffers where text-mode-hook
  ;; already turned it on. Replace with an explicit enable.
  (olivetti-mode-on-hook '((lambda () (visual-line-mode 1)))))

;; (use-package visual-fill-column
;;   :hook (prog-mode . visual-fill-column-mode))

(defun my/toggle-margins ()
  "Toggle body-width margins for the current buffer.
Uses `visual-fill-column-mode' in `prog-mode' derivatives,
`olivetti-mode' elsewhere."
  (interactive)
  (if (derived-mode-p 'prog-mode)
    (visual-fill-column-mode 'toggle)
    (olivetti-mode 'toggle)))

;;(dolist (face '(mode-line mode-line-inactive))
;;  (setf (alist-get face solaire-mode-remap-modeline) nil))

;;(add-to-list 'solaire-mode-themes-to-face-swap 'doom-one)

(provide 'dl-theme)
;;; dl-theme.el ends here
