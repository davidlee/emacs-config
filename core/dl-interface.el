;;; dl-interface.el --- UI settings -*- lexical-binding: t; -*-


(defun my/pixel-scroll-setup ()
  (interactive)
  (setq pixel-scroll-precision-large-scroll-height 1)
  (setq pixel-scroll-precision-interpolation-factor 1))

(use-package emacs
  :ensure nil
  :custom

  ;; startup
  (inhibit-splash-screen t)
  (inhibit-startup-message t)
  (inhibit-startup-echo-area-message t)

  (tooltip-use-echo-area t)

  (use-file-dialog nil)

  (use-dialog-box nil)
  (confirm-nonexistent-file-or-buffer nil)

  (default-frame-alist '((fullscreen . maximised)
                          (vertical-scroll-bars . nil)
                          (horizontal-scroll-bars . nil)

                          ;; Setting the face in here prevents flashes of
                          ;; color as the theme gets activated
                          (background-color . "#000000")
                          (foreground-color . "#ffffff")
                          (ns-appearance . dark)
                          (ns-transparent-titlebar . t)))

  (display-time-default-load-average nil)

  ;; UI tweaks
  (line-number-mode t)                        ; Show current line in modeline
  (column-number-mode t)                      ; Show column as well

  (scroll-bar-mode nil)
  (menu-bar-mode nil)
  (tool-bar-mode nil)

  (underline-minimum-offset 3)
  (x-use-underline-position-properties nil)
  (x-underline-at-descent-line t)            ; Prettier underlines
  (switch-to-buffer-obey-display-actions t)   ; Make switching buffers more consistent

  (show-trailing-whitespace nil)
  (indicate-buffer-boundaries 'left)  ; Show buffer top and bottom in the margin

  (frame-resize-pixelwise t)
  (show-paren-mode 1)

  ;; Enable horizontal scrolling
  (mouse-wheel-tilt-scroll t)
  (mouse-wheel-flip-direction t)

  ;; Time format
  (display-time-format "%a %F %T")
  (display-time-interval 1)

  (display-line-numbers-width 3)

  (global-prettify-symbols-mode t)

  ;; TAB BAR
  ;; Show the tab-bar as soon as tab-bar functions are invoked
  (tab-bar-show nil)
  (tab-bar-mode nil)
  (global-tab-line-mode nil)

  :init
  (display-time-mode)

  ;; Add the time to the tab-bar, if visible
  (add-to-list 'tab-bar-format 'tab-bar-format-align-right 'append)
  (add-to-list 'tab-bar-format 'tab-bar-format-global 'append)

  :config
  ;; Misc. UI tweaks
  (blink-cursor-mode -1)
  (pixel-scroll-precision-mode)
  (xterm-mouse-mode 1)
  ;;(cua-mode)

  ;; Display line numbers in programming mode
  (add-hook 'prog-mode-hook 'display-line-numbers-mode)

  ;; Nice line wrapping when working with text
  (add-hook 'text-mode-hook 'visual-line-mode)

  ;; Make right-click do something sensible
  (when (display-graphic-p)
    (context-menu-mode))

  (when (boundp 'pixel-scroll-precision-mode)
    (my/pixel-scroll-setup)
    (add-hook 'prog-mode-hook #'pixel-scroll-precision-mode)
    (add-hook 'org-mode-hook #'pixel-scroll-precision-mode))

  ;; Modes to highlight the current line with
  (let ((hl-line-hooks '(text-mode-hook prog-mode-hook)))
    (mapc (lambda (hook) (add-hook hook 'hl-line-mode)) hl-line-hooks)))


(use-package spacious-padding
  :config
  (spacious-padding-mode 1))

(use-package diminish
  :defer t) ; disable

(use-package nerd-icons
  :defer t)

(use-package nerd-icons-completion
  :after marginalia
  :defer t
  :commands (nerd-icons-completion-mode nerd-icons-completion-marginalia-setup)
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

(use-package beacon
  :diminish beacon-mode
  :config
  (beacon-mode 1))

(setopt scroll-conservatively 100)

(use-package breadcrumb
  :defer t)

(provide 'dl-interface)
;;; dl-interface.el ends here
