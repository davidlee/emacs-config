;;; dl-vertico.el --- Vertico config -*- lexical-binding: t; -*-

;; lots here https://github.com/minad/vertico/tree/main

(use-package vertico
  :demand t
  :custom
  ;; (vertico-scroll-margin 0) ;; Different scroll margin
  (vertico-count 20) ;; Show more candidates
  ;; (vertico-resize t) ;; Grow and shrink the Vertico minibuffer
  (vertico-cycle t) ;; Enable cycling for `vertico-next/previous'
  :bind (:map vertico-map
         ("M-?"   . minibuffer-completion-help)
         ("M-RET" . minibuffer-force-complete-and-exit)
         ("M-TAB" . minibuffer-complete))
  :config
  (vertico-mode))

;; (when (display-graphic-p)
;;   (use-package vertico-posframe)
;;   (vertico-posframe-mode nil))

;; Minibuffer-wide settings (recursive minibuffers, prompt properties,
;; M-x predicate, context-menu) live in `dl-completion.el' / `dl-interface.el'.

;; Configure directory extension.
(use-package vertico-directory
  :after vertico
  :ensure nil
  ;; More convenient directory navigation commands
  :bind (:map vertico-map
          ("RET" . vertico-directory-enter)
          ("DEL" . vertico-directory-delete-char)
          ("M-DEL" . vertico-directory-delete-word))
  ;; Tidy shadowed file names
  :hook (rfn-eshadow-update-overlay . vertico-directory-tidy))

(use-package vertico-multiform
  :after vertico
  :ensure nil
  :config
  ;; `embark-bindings' / embark prefix help as a grid.
  (add-to-list 'vertico-multiform-categories '(embark-keybinding grid))
  (vertico-multiform-mode))

(provide 'dl-vertico)
