;;; dl-theme.el --- Theme settings -*- lexical-binding: t; -*-

;; (use-package nano
;;   :ensure nil
;;   :vc (:url "https://github.com/rougier/nano-emacs.git"))


;; (use-package modus-themes
;;   :custom
;;   (modus-themes-mode-line '(accented borderless)
;;     modus-themes-bold-constructs t
;;     modus-themes-italic-constructs t
;;     modus-themes-fringes 'subtle
;;     modus-themes-tabs-accented t
;;     modus-themes-paren-match '(bold)
;;     ;; modus-themes-prompts '(bold intense)
;;     ;; modus-themes-completions 'opinionated
;;     modus-themes-org-blocks 'tinted-background
;;     modus-themes-scale-headings t
;;     modus-themes-region '(bg-only))
;;   :config
;;   (modus-themes-load-theme 'modus-vivendi)
;;   (define-key global-map (kbd "<f5>") #'modus-themes-toggle))

;; (use-package ef-themes
;;   :custom
;;   ;; This makes the Modus commands listed below consider only the Ef
;;   ;; themes.  For an alternative that includes Modus and all
;;   ;; derivative themes (like Ef), enable the
;;   ;; `modus-themes-include-derivatives-mode' instead.  The manual of
;;   ;; the Ef themes has a section that explains all the possibilities:
;;   ;;
;;   ;; - Evaluate `(info "(ef-themes) Working with other Modus themes or taking over Modus")'
;;   ;; - Visit <https://protesilaos.com/emacs/ef-themes#h:6585235a-5219-4f78-9dd5-6a64d87d1b6e>
;;   (ef-themes-take-over-modus-themes-mode 1)
;;   :bind
;;   (;("<f5>" . modus-themes-rotate)
;;     ("C-<f5>" . modus-themes-select)
;;     ("M-<f5>" . modus-themes-load-random))
;;   :config
;;   ;; All customisations here.
;;   (setq modus-themes-mixed-fonts t)
;;   (setq modus-themes-italic-constructs t)

;;   ;; Finally, load your theme of choice (or a random one with
;;   ;; `modus-themes-load-random', `modus-themes-load-random-dark',
;;   ;; `modus-themes-load-random-light').
;;   ;; (modus-themes-load-theme 'ef-owl)
;;   )

;; (require 'nano-layout)
;; (require 'nano-base-colors)
;; (require 'nano-faces)
;; (require 'nano-theme-light)
;; (require 'nano-theme-dark)
;; (require 'nano-theme)
;; (require 'nano-defaults)
;; (require 'nano-modeline)

(defvar my--themes
  '(doom-one doom-gruvbox doom-nord doom-material doom-ayu-dark
     doom-zenburn
     doom-laserwave doom-molokai doom-moonlight doom-dracula))

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

(use-package solaire-mode
  :commands solaire-global-mode
  :config
  (solaire-global-mode +1))

;;(dolist (face '(mode-line mode-line-inactive))
;;  (setf (alist-get face solaire-mode-remap-modeline) nil))

;;(add-to-list 'solaire-mode-themes-to-face-swap 'doom-one)

(provide 'dl-theme)
;;; dl-theme.el ends here
