;;; dl-keybind.el --- keys -*- lexical-binding: t; -*-

;; GUI + PGUP / PGDN -- next / prev buffer
;;

(use-package windmove
  :ensure nil
  :config
  (global-set-key (kbd "C-s-<left>")  #'windmove-left)
  (global-set-key (kbd "C-s-<right>") #'windmove-right)
  (global-set-key (kbd "C-s-<up>")    #'windmove-up)
  (global-set-key (kbd "C-s-<down>")  #'windmove-down))

(keymap-global-set "s-<prior>" 'switch-to-next-buffer)
(keymap-global-set "s-<next>" 'switch-to-prev-buffer)

(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "C-x C-b") 'ibuffer)
(global-set-key (kbd "M-z") 'zap-up-to-char)

(global-set-key (kbd "C-s") 'isearch-forward-regexp)
(global-set-key (kbd "C-r") 'isearch-backward-regexp)
(global-set-key (kbd "C-M-s") 'isearch-forward)
(global-set-key (kbd "C-M-r") 'isearch-backward)

;; Use Hydras for repeatable, sticky subinterfaces
(use-package hydra)

(use-package which-key
  :ensure nil
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (which-key-show-early-on-C-h t)
  (which-key-idle-delay 1e6)
  (which-key-idle-secondary-delay 0.05)
  :config
  (which-key-mode))

(defun my/keymap-bindings (keymap)
  "Return a list of bindings in KEYMAP."
  (let (bindings)
    (map-keymap
      (lambda (event binding)
        (push (cons (key-description (vector event)) binding) bindings))
      keymap)
    (nreverse bindings)))

;; C-h k        describe-key
;; C-h b        describe-bindings
;; C-h m        describe-mode
;; C-h w        where-is
;; C-h f        describe-function
;; C-h v        describe-variable
;; M-x describe-keymap
;; M-x which-key-show-keymap
;; M-x where-is

(provide 'dl-keybind)

;;; dl-keybind.el ends here
