;;; dl-popups.el --- Popup taming (shackle + popper) -*- lexical-binding: t; -*-

;; shackle constrains where pop-up windows appear; popper classifies
;; "popup-worthy" buffers and gives them dedicated toggle/cycle chords.

(use-package shackle) ; https://depp.brause.cc/shackle/

(use-package popper
  :bind ( ("C-`"   . popper-toggle)
          ("M-`"   . popper-cycle)
          ("C-M-`" . popper-toggle-type))
  :defer t
  :commands (popper-mode popper-echo-mode)
  :config
  (setq popper-reference-buffers
    '("\\*Messages\\*"
       "Output\\*$"
       "\\*Async Shell Command\\*"
       help-mode
       compilation-mode))
  (popper-mode +1)
  (popper-echo-mode +1)) ; For echo area hints

(provide 'dl-popups)
;;; dl-popups.el ends here
