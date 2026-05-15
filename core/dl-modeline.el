;;; dl-modeline.el --- Modeline -*- lexical-binding: t; -*-
;; Modeline

;; (use-package doom-modeline
;;   ;; :demand t
;;   :defer t
;;   :custom
;;   (doom-modeline-height 50)
;;   (doom-modeline-icon t)
;;   (doom-modeline-time-clock-size 0.4)
;;   (doom-modeline-spc-face-overrides
;;     (list :family (face-attribute 'fixed-pitch :family)))
;;   :config
;;   (if (facep 'mode-line-active)
;;     (set-face-attribute 'mode-line-active nil
;;       :family "NerdFontMono" :height 120) ; For 29+
;;     (set-face-attribute 'mode-line nil
;;       :family "NerdFontMono" :height 120))
;;   (set-face-attribute 'mode-line-inactive nil
;;     :family "NerdFontMono" :height 120)
;;   (doom-modeline-mode nil))

;; (use-package telephone-line
;;   :defer t
;;   :config
;;   (telephone-line-mode nil))

(use-package lambda-line
  ;;  :ensure nil
  ;;  :vc (:url "https://github.com/Lambda-Emacs/lambda-line.git")
  :custom
  (lambda-line-icon-time t) ;; requires ClockFace font (see below)
  (lambda-line-clockface-update-fontset "ClockFaceRect") ;; set clock icon
  (lambda-line-position 'top) ;; Set position of status-line
  (lambda-line-abbrev t) ;; abbreviate major modes
  (lambda-line-hspace "  ")  ;; add some cushion
  (lambda-line-prefix t) ;; use a prefix symbol
  (lambda-line-prefix-padding nil) ;; no extra space for prefix
  (lambda-line-status-invert nil)  ;; no invert colors
  (lambda-line-gui-ro-symbol  " ⨂") ;; symbols
  (lambda-line-gui-mod-symbol " ⬤")
  (lambda-line-gui-rw-symbol  " ◯")
  (lambda-line-space-top +.25)  ;; padding on top and bottom of line
  (lambda-line-space-bottom -.25)
  (lambda-line-symbol-position 0.1) ;; adjust the vertical placement of symbol
  :config
  ;; activate lambda-line
  (lambda-line-mode)
  ;; set divider line in footer
  (when (eq lambda-line-position 'top)
    (setq-default mode-line-format (list "%_"))
    (setq mode-line-format (list "%_"))))

(provide 'dl-modeline)
;;; dl-modeline.el ends here
