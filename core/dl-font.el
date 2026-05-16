;;; dl-font.el --- fonts -*- lexical-binding: t; -*-

;;(set-face-attribute 'default nil :font "Hack 12")
                                        ;(set-face-attribute 'lambda-line nil :font "Hack 10")
                                        ;(custom-set-faces)
;; DejaVu Sans Mono
;; JetBrainsMono Nerd Font Mono
;; ZedMono NF
;; Hack
;; MonoLisa Nerd Font Mono
;; Monaspace Krypton NF

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

                       ;; <https://protesilaos.com/emacs/fontaine>
                       (t
                         :default-family "JetBrainsMono NF"
                         :default-weight regular
                         :default-height 100

                         :fixed-pitch-family "MonoLisa NF"
                         :fixed-pitch-weight nil
                         :fixed-pitch-height 1.0

                         :fixed-pitch-serif-family "Noto Sans Mono NF"
                         :fixed-pitch-serif-weight nil
                         :fixed-pitch-serif-height 1.0

                         :variable-pitch-family "Linux Libertine O"
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
                         :mode-line-active-height 120

                         :mode-line-inactive-family "Hack"
                         :mode-line-inactive-weight nil
                         :mode-line-inactive-height 120

                         :header-line-family "Hack" ; falls back to :default-family
                         :header-line-weight nil ; falls back to :default-weight
                         :header-line-height 120

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


(provide 'dl-font)
;;; dl-font.el ends here
