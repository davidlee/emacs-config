;;; dl-font.el --- fonts -*- lexical-binding: t; -*-

(use-package
  fontaine
  :ensure t
  :custom
  (fontaine-presets '((small
                        :default-family "JetBrainsMono Nerd Font Mono"
                        :default-height 90
                        :variable-pitch-family "JetBrainsMono"
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

                         ;; I keep all properties for didactic purposes, but most can be
                         ;; omitted.  See the fontaine manual for the technicalities:
                         ;; <https://protesilaos.com/emacs/fontaine>.
                         :default-family "JetBrainsMono Nerd Font Mono"
                         :default-weight regular
                         :default-height 100

                         :fixed-pitch-family nil ; falls back to :default-family
                         :fixed-pitch-weight nil ; falls back to :default-weight
                         :fixed-pitch-height 1.0

                         :fixed-pitch-serif-family nil ; falls back to :default-family
                         :fixed-pitch-serif-weight nil ; falls back to :default-weight
                         :fixed-pitch-serif-height 1.0

                         :variable-pitch-family "JetBrainsMono"
                         :variable-pitch-weight nil
                         :variable-pitch-height 1.0

                         :mode-line-active-family nil ; falls back to :default-family
                         :mode-line-active-weight nil ; falls back to :default-weight
                         :mode-line-active-height 0.9

                         :mode-line-inactive-family nil ; falls back to :default-family
                         :mode-line-inactive-weight nil ; falls back to :default-weight
                         :mode-line-inactive-height 0.9

                         :header-line-family "Monacpace Radon" ; falls back to :default-family
                         :header-line-weight nil ; falls back to :default-weight
                         :header-line-height 1.4

                         :line-number-family nil ; falls back to :default-family
                         :line-number-weight nil ; falls back to :default-weight
                         :line-number-height 1.0

                         :tab-bar-family nil ; falls back to :default-family
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
  (define-key global-map (kbd "C-c f") #'fontaine-set-preset)
  (fontaine-set-preset
    (or (fontaine-restore-latest-preset) 'regular))
  (fontaine-mode 1))

(provide 'dl-font)
;; (set-face-attribute 'default nil :font "JetBrainsMono Nerd Font Mono" :height 115)
;;; dl-font.el ends here
