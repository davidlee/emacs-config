;;; dl-interface.el --- UI settings -*- lexical-binding: t; -*-

(use-package emacs
  :ensure nil
  :custom

  ;; startup
  (inhibit-splash-screen t)
  (inhibit-startup-message t)
  (inhibit-startup-echo-area-message t)

  (tooltip-use-echo-area t)

  (use-short-anwswers t)
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
  
  (menu-bar-mode nil)
  (tool-bar-mode nil)

  (x-underline-at-descent-line nil)           ; Prettier underlines
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
  
  ;; Show the tab-bar as soon as tab-bar functions are invoked
  (tab-bar-show 1)
  (display-line-numbers-width 3) ; min width

  (global-prettify-symbols-mode t)

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

  ;; Modes to highlight the current line with
  (let ((hl-line-hooks '(text-mode-hook prog-mode-hook)))
    (mapc (lambda (hook) (add-hook hook 'hl-line-mode)) hl-line-hooks))) 

(use-package doom-modeline
  :demand t
  :config
  (doom-modeline-mode 1))

(use-package spacious-padding
  :config
  (spacious-padding-mode 1))

(use-package diminish
  :ensure t)

(use-package nerd-icons
  :ensure t)

(use-package nerd-icons-completion
  :after marginalia
  :config
  (nerd-icons-completion-mode)
  (add-hook 'marginalia-mode-hook #'nerd-icons-completion-marginalia-setup))

(use-package nerd-icons-dired
  :hook (dired-mode . nerd-icons-dired-mode))

(use-package beacon
  :ensure t
  :diminish beacon-mode
  :config
  (beacon-mode 1))

(setopt scroll-conservatively 100)

(provide 'dl-interface)
