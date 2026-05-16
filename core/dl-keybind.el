;;; dl-keybind.el --- Ergonomic global chord bindings -*- lexical-binding: t; -*-


;; Personal command families live under C-c <letter> / SPC <letter>
;; (see dl-keymap.el).  This file holds bindings that don't fit a prefix:
;; ergonomic chord shortcuts, which-key, hydra, and runtime helpers.

(use-package windmove
  :ensure nil
  :config
  (global-set-key (kbd "C-s-<left>")  #'windmove-left)
  (global-set-key (kbd "C-s-<right>") #'windmove-right)
  (global-set-key (kbd "C-s-<up>")    #'windmove-up)
  (global-set-key (kbd "C-s-<down>")  #'windmove-down))

;; Tab-bar + buffer chords.
(keymap-global-set "s-<prior>"   'tab-bar-switch-to-next-tab)
(keymap-global-set "s-<next>"    'tab-bar-switch-to-prev-tab)
(keymap-global-set "M-s-<prior>" 'switch-to-next-buffer)
(keymap-global-set "M-s-<next>"  'switch-to-prev-buffer)

(global-set-key (kbd "M-/") 'hippie-expand)
(global-set-key (kbd "M-z") 'zap-up-to-char)
(global-set-key (kbd "C-x K") 'kill-current-buffer)
(global-set-key (kbd "C-x C-b") 'ibuffer)

(define-key comint-mode-map (kbd "C-p") #'comint-previous-input)
(define-key comint-mode-map (kbd "C-n") #'comint-next-input)
(define-key comint-mode-map (kbd "C-w") #'backward-kill-word)

(global-set-key (kbd "C-x 2") 'split-and-follow-horizontally)
(global-set-key (kbd "C-x 3") 'split-and-follow-vertically)

;; Hydras for repeatable, sticky subinterfaces (no defs yet).
(use-package hydra
  :commands defhydra)

(use-package which-key
  :ensure nil
  :custom
  (prefix-help-command #'embark-prefix-help-command)
  (which-key-show-early-on-C-h t)
  (which-key-idle-delay 0.3) ; 1e6
  (which-key-idle-secondary-delay 0.05)
  :config
  (which-key-mode))

(defun my/keymap-bindings (keymap)
  "Return a list of bindings in KEYMAP."
  (let (bindings)
    (map-keymap
      (lambda (event binding)
        (push
          (cons
            (key-description (vector event))
            binding)
          bindings))
      keymap)
    (nreverse bindings)))

;; Discovery cheatsheet:
;;   C-h k        describe-key
;;   C-h b        describe-bindings
;;   C-h m        describe-mode
;;   C-h w        where-is
;;   C-h f        describe-function
;;   C-h v        describe-variable
;;   M-x describe-keymap
;;   M-x which-key-show-keymap
;;   M-x where-is

(provide 'dl-keybind)
;;; dl-keybind.el ends here
