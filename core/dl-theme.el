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

(use-package doom-themes
  ;;  :bind
  ;;(("<f5>" . my--rotate-themes))
  :custom
  ;; Global settings (defaults)
  (doom-themes-enable-bold t)   ; if nil, bold is universally disabled
  (doom-themes-enable-italic t) ; if nil, italics is universally disabled
  ;; for treemacs users
  (doom-themes-treemacs-theme "doom-one") ; use "doom-colors" for less minimal icon theme

  ;; Enable flashing mode-line on errors
  (doom-themes-visual-bell-config)
  ;; Enable custom neotree theme (nerd-icons must be installed!)
  (doom-themes-neotree-config)
  ;; or for treemacs users
  (doom-themes-treemacs-config)
  ;; Corrects (and improves) org-mode's native fontification.
  (doom-themes-org-config)
  :config
  (load-theme 'doom-one t))

(global-set-key (kbd "<f5>") #'my--rotate-themes)

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
  :hook ((text-mode org-mode markdown-mode) . olivetti-mode)
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
