;;; dl-interface.el --- UI settings -*- lexical-binding: t; -*-

(use-package emacs
  :ensure nil
  :custom

  ;; startup
  (inhibit-splash-screen t)

  ;; performance
  (gc-cons-threshold 50000000)
  (large-file-warning-threshold 100000000)
  (load-prefer-newer t) ; new bytecode pls
  (initial-major-mode 'fundamental-mode)

  ;; sensible defaults
  (display-time-default-load-average nil)

  ;; Automatically reread from disk if the underlying file changes
  (auto-revert-avoid-polling t)
  (auto-revert-interval 3)
  (auto-revert-check-vc-info t)
  (history-length 80)
  (global-auto-revert-non-file-buffers t) ; dired, etc

  (sentence-end-double-space nil) ; no
  
  ;; Identity
  (user-full-name "David Lee")
  (user-email-address "dav@davlee.com")

  ;; UI tweaks
  (line-number-mode t)                        ; Show current line in modeline
  (column-number-mode t)                      ; Show column as well
  
  (menu-bar-mode nil)
  (tool-bar-mode nil)

  (x-underline-at-descent-line nil)           ; Prettier underlines
  (switch-to-buffer-obey-display-actions t)   ; Make switching buffers more consistent

  (show-trailing-whitespace nil)    
  (indicate-buffer-boundaries 'left)  ; Show buffer top and bottom in the margin

  ;; Enable horizontal scrolling
  (mouse-wheel-tilt-scroll t)
  (mouse-wheel-flip-direction t)

  ;; Time format
  (display-time-format "%a %F %T")
  (display-time-interval 1)
  
  ;; Show the tab-bar as soon as tab-bar functions are invoked
  (tab-bar-show 1)
  (display-line-numbers-width 3) ; min width

  ;; put custom vars from configurators somewhere other than my init.el
  (custom-file (locate-user-emacs-file "custom-vars.el"))
  
  :init
  (display-time-mode)
  
  ;; Add the time to the tab-bar, if visible
  (add-to-list 'tab-bar-format 'tab-bar-format-align-right 'append)
  (add-to-list 'tab-bar-format 'tab-bar-format-global 'append)

  :config
  ;; don't warn when loading stuff from custom-vars.el 
  (load custom-file 'noerror 'nomessage)
  
  ;; history & recent files
  (global-auto-revert-mode)
  (save-place-mode 1)

  ;; Move through windows with Ctrl-<arrow keys>
  (windmove-default-keybindings 'control) ; You can use other modifiers here

  ;; Misc. UI tweaks
  (blink-cursor-mode -1) 
  (pixel-scroll-precision-mode)
  (cua-mode)
  (xterm-mouse-mode 1)

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

;; which-key: shows a popup of available keybindings when typing a long key
;; sequence (e.g. C-x ...)
(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(provide 'dl-interface)

