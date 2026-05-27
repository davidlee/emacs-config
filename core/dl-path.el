;;; dl-path.el --- Load & Exec Paths -*- lexical-binding: t; -*-
(defvar my/lisp-dirs
  '("lisp" "core" "editing" "completion" "apps" "org" "dev" "lang" "satan")
  "My own Lisp directories, relative to `user-emacs-directory'.")

(defvar my/checkout-lisp-dirs
  '("checkout" "elpa/org-timeblock")
  "External checkout Lisp directories, relative to `user-emacs-directory'.")

(defun my/expand-emacs-dir (dir)
  "Expand DIR relative to `user-emacs-directory' as a directory path.
Returned path is abbreviated (\"~/...\") so it matches what
`trusted-content-p' compares against."
  (file-name-as-directory
    (abbreviate-file-name
      (expand-file-name dir user-emacs-directory))))

(defun my/add-load-path-dir (dir)
  "Add DIR under `user-emacs-directory' to `load-path'."
  (add-to-list 'load-path (my/expand-emacs-dir dir)))

(defun my/trust-lisp-dir (dir)
  "Add DIR under `user-emacs-directory' to `trusted-content'."
  (add-to-list 'trusted-content (my/expand-emacs-dir dir)))

;; Load both my code and external checkouts.
(mapc #'my/add-load-path-dir
  (append my/lisp-dirs my/checkout-lisp-dirs))

;; Trust only my own code.
(mapc #'my/trust-lisp-dir my/lisp-dirs)

;; NIX path
;; (use-package exec-path-from-shell
;;   :if (memq window-system '(mac ns x pgtk))
;;   :config
;;   (exec-path-from-shell-initialize))

(add-to-list 'exec-path "~/.nix-profile/bin")
(add-to-list 'exec-path "/run/current-system/sw/bin")
(add-to-list 'exec-path "~/.local/bin")
(setenv "PATH" (concat "~/.nix-profile/bin:" (getenv "PATH")))

(require 'use-package-ensure-system-package)

;;(use-package direnv
;;  :config
;; (direnv-mode))

(use-package envrc
  :config
  (envrc-global-mode))

(provide 'dl-path)
;;; dl-path.el ends here
