;;; dl-font.el --- fonts -*- lexical-binding: t; -*-

;;(set-face-attribute 'default nil :font "Hack 12")
;(set-face-attribute 'lambda-line nil :font "Hack 10")
;(custom-set-faces)
;; DejaVu Sans Mono
;; JetBrainsMono Nerd Font Mono
;; ZedMono NF
;; Hack
;; MonoLisa Nerd Font Mono

(use-package
  fontaine
  :custom
  (fontaine-presets '((small
                        :default-family "MonoLisa Nerd Font Mono"
                        :default-height 90
                        :variable-pitch-family "Iosevka"
                        )
                       (regular
                         :default-height 105)
                       (medium
                         :default-weight semilight
                         :default-height 125
                         :bold-weight extrabold)
                       (large
                         :inherit medium
                         :default-height 150)

                       (presentation :default-height 180)
                       (t

                         ;; I keep all properties for didactic purposes, but most ca
                         ;; omitted.  See the fontaine manual for the technicalities:
                         ;; <https://protesilaos.com/emacs/fontaine>.
                         :default-family "JetBrainsMono NF"
                         :default-weight regular
                         :default-height 100

                         :fixed-pitch-family "Roboto"; falls back to :default-family
                         :fixed-pitch-weight nil ; falls back to :default-weight
                         :fixed-pitch-height 1.0

                         :fixed-pitch-serif-family nil ; falls back to :default-family
                         :fixed-pitch-serif-weight nil ; falls back to :default-weight
                         :fixed-pitch-serif-height 1.0

                         :variable-pitch-family "JetBrainsMono"
                         :variable-pitch-weight nil
                         :variable-pitch-height 1.0

                         ;; Lambda-line faces inherit from `mode-line' /
                         ;; `mode-line-inactive', so fontaine styles it through
                         ;; the `:mode-line-{active,inactive}-*' keys (fontaine
                         ;; has no `:lambda-line-*' key). Heights kept at 1.0 to
                         ;; avoid active/inactive size jumps — lambda-line owns
                         ;; vertical padding via `lambda-line-space-{top,bottom}'.
                         :mode-line-active-family "Hack"
                         :mode-line-active-weight nil
                         :mode-line-active-height 1.0

                         :mode-line-inactive-family "Hack"
                         :mode-line-inactive-weight nil
                         :mode-line-inactive-height 1.0

                         ;;:header-line-family "Monaspace Krypton" ; falls back to :default-family
                         :header-line-family "Monaspace Neon NF" ; falls back to :default-family
                         :header-line-weight nil ; falls back to :default-weight
                         :header-line-height 140

                         :line-number-family "ZedMono" ; falls back to :default-family
                         :line-number-weight nil ; falls back to :default-weight
                         :line-number-height 1.0

                         :tab-bar-family "Monaspace Argon NF" ; falls back to :default-family
                         :tab-bar-weight nil ; falls back to :default-weight
                         :tab-bar-height 1.0

                         :tab-line-family nil ; falls back to :default-family
                         :tab-line-weight nil ; falls back to :default-weight
                         :tab-line-height 1.0

                         :bold-family nil ; use whatever the underlying face has
                         :bold-weight bold

                         :italic-family nil
                         :italic-slant italic

                         ;; Customize headings specifically
                         :heading-1-weight bold
                         :heading-1-height 1.6
                         :heading-2-weight semibold
                         :heading-2-height 1.4
                         :heading-3-weight regular
                         :heading-3-height 1.2
                         :variable-pitch t
                         :line-spacing nil)))
  :config
  ;; (define-key global-map (kbd "<f6>") #'fontaine-toggle-preset)
  (define-key global-map (kbd "C-<f6>") #'fontaine-set-preset)
  (define-key global-map (kbd "<f6>") #'fontaine-toggle-preset)
  (fontaine-set-preset
    (or (fontaine-restore-latest-preset) 'regular))
  (fontaine-mode 1))

;(add-hook 'after-init-hook #'fontaine-mode)

;; (custom-set-faces
;;  '(meow-normal-indicator ((t (:background "#a6e3a1" :foreground "black" :weight bold))))
;;  '(meow-insert-indicator ((t (:background "#f38ba8" :foreground "black" :weight bold))))
;;  '(meow-motion-indicator ((t (:background "#89b4fa" :foreground "black" :weight bold))))
;;  '(meow-keypad-indicator ((t (:background "#f9e2af" :foreground "black" :weight bold))))
;;  '(meow-beacon-indicator ((t (:background "#cba6f7" :foreground "black" :weight bold)))))

(provide 'dl-font)
;; (set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;;; dl-font.el ends here
