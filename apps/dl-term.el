;;; dl-term.el --- terminals -*- lexical-binding: t; -*-

;;
;; ESHELL
;;

;; Visual commands (less, htop, ...) run in a ghostel buffer, not `term-mode'.
(declare-function ghostel-eshell-visual-command-mode "ghostel-eshell")
(add-hook 'eshell-load-hook #'ghostel-eshell-visual-command-mode)

;; `eshell-mode-map' is defined in `esh-mode', not `eshell'.
(use-package esh-mode
  :ensure nil
  :bind (:map eshell-mode-map ("C-r" . consult-history)))

(defun eshell-other-window ()
  "Create or visit an eshell buffer."
  (interactive)
  (if (not (get-buffer "*eshell*"))
    (progn
      (split-window-sensibly (selected-window))
      (other-window 1)
      (eshell))
    (switch-to-buffer-other-window "*eshell*")))

;;
;; GHOSTEL (replaces vterm / multi-vterm / vterm-toggle)
;;
;; Ghostel package itself is installed in apps/dl-ghostel.el.
;; Key bindings for ghostel live in dl-keymap.el under my-term-map (C-c m).

(defvar ghostel-buffer-name)
(declare-function ghostel "ghostel")

(defun my/ghostel-named (name)
  "Open or create a ghostel terminal buffer named for NAME."
  (interactive "sGhostel name: ")
  (let ((ghostel-buffer-name (format "*ghostel:%s*" name)))
    (ghostel)))

(defun dl-term--display-in-dock (buffer alist)
  "Show BUFFER in the dedicated window of a docked terminal, if one is visible.
`display-buffer-reuse-mode-window' passes over dedicated windows, so without
this each new terminal opens a window of its own beside the dock.  The dock
stays dedicated, per ALIST's `dedicated' entry."
  (when-let* ((dock (get-window-with-predicate
                      (lambda (window)
                        (and (window-dedicated-p window)
                             (with-current-buffer (window-buffer window)
                               (derived-mode-p 'ghostel-mode))))
                      nil (cdr (assq 'reusable-frames alist))))
              (shown (window--display-buffer buffer dock 'reuse alist)))
    (set-window-dedicated-p shown (cdr (assq 'dedicated alist)))
    shown))

(defconst dl-term-ghostel-display-rule
  '((major-mode . ghostel-mode)
     (display-buffer-reuse-mode-window
       dl-term--display-in-dock
       display-buffer-at-bottom)
     (dedicated . t)
     (reusable-frames . visible)
     (window-height . 0.3))
  "Where `display-buffer' puts a ghostel terminal: a dock at the bottom.")

(add-to-list 'display-buffer-alist dl-term-ghostel-display-rule)

(provide 'dl-term)
;;; dl-term.el ends here
