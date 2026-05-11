;;; dl-core.el --- basic setup -*- lexical-binding: t; -*-

(use-package emacs
  :ensure nil
  :custom

  ;; performance
  (gc-cons-threshold 50000000)
  (large-file-warning-threshold 100000000)
  (load-prefer-newer t) ; new bytecode pls
  (initial-major-mode 'fundamental-mode)

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

  ;; put custom vars from configurators somewhere other than my init.el
  (custom-file (locate-user-emacs-file "custom-vars.el"))

  (standard-indent 2) ; this is the way

  :config
  ;; don't warn when loading stuff from custom-vars.el 
  (load custom-file 'noerror 'nomessage)
  
  ;; history & recent files
  (global-auto-revert-mode)
  (save-place-mode 1)

  ;; Move through windows with Ctrl-<arrow keys>
  ;; TODO move this to dl-movement.el
  ;; (windmove-default-keybindings 'control) ; You can use other modifiers here
  (windmove-default-keybindings '(ctrl shift))
  ;; compensate in org-mode
  ;; (define-key org-mode-map (kbd "<M-up>") nil)
  ;; (define-key org-mode-map (kbd "<M-down>") nil)
  ;; (define-key org-mode-map (kbd "<M-left>") nil)
  ;; (define-key org-mode-map (kbd "<M-right>") nil)

  ;; Show the help buffer after startup
  (add-hook 'after-init-hook 'help-quick))

(use-package which-key
  :ensure t
  :config
  (which-key-mode))

(provide 'dl-core)
