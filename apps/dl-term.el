;;; dl-term.el --- terminals -*- lexical-binding: t; -*-

(use-package eat
  :ensure t
  :custom
  (eat-term-name "xterm-256")
  (eat-eshell-mode)                     ; use Eat to handle term codes in program output
  (eat-eshell-visual-command-mode))     ; commands like less will be handled by Eat

(use-package eshell
  :init
  (defun bedrock/setup-eshell ()
    ;; Something funny is going on with how Eshell sets up its keymaps; this is
    ;; a work-around to make C-r bound in the keymap
    (keymap-set eshell-mode-map "C-r" 'consult-history))
  :hook ((eshell-mode . bedrock/setup-eshell)))

;;
;; ESHELL
;;
(defun eshell/sudo-open (filename)
  "Open a file as root in Eshell."
  (let ((qual-filename (if (string-match "^/" filename)
                         filename
                         (concat (expand-file-name (eshell/pwd)) "/" filename))))
    (switch-to-buffer
      (find-file-noselect
        (concat "/sudo::" qual-filename)))))


(defun eshell-other-window ()
  "Create or visit an eshell buffer."
  (interactive)
  (if (not (get-buffer "*eshell*"))
    (progn
      (split-window-sensibly (selected-window))
      (other-window 1)
      (eshell))
    (switch-to-buffer-other-window "*eshell*")))


(global-set-key (kbd "<s-C-return>") 'eshell-other-window)

(provide 'dl-term)
