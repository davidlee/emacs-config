;; dl-god.el --- God Mode -*- lexical-binding: t; -*-
;; https://idiomdrottning.org/on-top-of-emacs-god-mode

(use-package
  god-mode
  :config
  (god-mode))

(global-set-key (kbd "<escape>") #'god-local-mode)
(custom-set-faces
  '(god-mode-lighter ((t (:inherit error)))))

(defun my-god-mode-update-cursor-type ()
  (setq cursor-type (if (or god-local-mode buffer-read-only) 'box '(bar . 4)))
  (set-cursor-color (if (or god-local-mode buffer-read-only) "#ff0000" "#ff00ff")))

(add-hook 'post-command-hook #'my-god-mode-update-cursor-type)

(defun my-god-mode-update-mode-line ()
  (cond
    (god-local-mode
      (set-face-attribute 'mode-line nil
        ;;:foreground "#604000"
        :background "#111111")
      (set-face-attribute 'mode-line-inactive nil
        ;;:foreground "#3f3000"
        :background "#223344"))
    (t
      (set-face-attribute 'mode-line nil
			  :foreground "#ff0000"
			  :background "#000000")
      (set-face-attribute 'mode-line-inactive nil
			  :foreground "#eeeeee"
			  :background "#000000"))))
(add-hook 'post-command-hook #'my-god-mode-update-mode-line)
;; VIM style on/off for god mode
(define-key god-local-mode-map (kbd "i") #'god-local-mode)
(global-set-key (kbd "<escape>") #'(lambda () (interactive) (god-local-mode 1)))

(define-key god-local-mode-map (kbd "o") 'insert-one-character)

(defun insert-one-character (times)
  (interactive "p")
  (overwrite-mode 1)
  (dotimes (x times) (quoted-insert 1))
  (overwrite-mode 0))

(defun overwrite-insert (times)
  (interactive "p")
  (delete-char times)
  (insert-one-character times))

(setopt god-mode-enable-function-key-translation nil)

(define-key god-local-mode-map (kbd ">") 'overwrite-insert)
(define-key god-local-mode-map (kbd ".") #'repeat)

(global-set-key (kbd "C-x C-1") #'delete-other-windows)
(global-set-key (kbd "C-x C-2") #'split-window-below)
(global-set-key (kbd "C-x C-3") #'split-window-right)
(global-set-key (kbd "C-x C-0") #'delete-window)

(define-key god-local-mode-map (kbd "[") #'backward-paragraph)
(define-key god-local-mode-map (kbd "]") #'forward-paragraph)

(provide 'dl-god)
;;; dl-god.el ends here
