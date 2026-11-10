;;; dl-elisp.el --- Emacs Lisp editing setup -*- lexical-binding: t; -*-

(defvar dl/package-lint-enable nil
  "Enable anal package comment linting.")

;; Core Elisp editing.
(use-package emacs
  :ensure nil
  :hook
  ((emacs-lisp-mode . eldoc-mode)
    (emacs-lisp-mode . electric-pair-local-mode)
    (emacs-lisp-mode . show-paren-local-mode))
  :custom
  (show-paren-delay 0)
  (show-paren-style 'mixed)
  (electric-pair-preserve-balance t)
  (electric-pair-delete-adjacent-pairs t)
  (electric-pair-open-newline-between-pairs t)
  :config
  (setq-default lisp-indent-offset nil)
  (setq-default indent-tabs-mode nil))

;; Flymake's byte-compile child is a bare `emacs -Q': hand it the config's
;; Lisp dirs, or `(require ...)' of my own libraries is "no such file".
(require 'dl-dirs)
(setq-default elisp-flymake-byte-compile-load-path
  (cons "./" (dl-dirs-load-path)))
;; ... and its installed packages, or every autoloaded command is "not
;; known to be defined".  bin/elisp-lint runs the same child.
(setq elisp-flymake-byte-compile-executable
  (expand-file-name "bin/elisp-compile-child" user-emacs-directory))

;; Flymake skips the files `just lint' skips, so the two always agree.
(require 'dl-lint)
(defun dl-elisp--skip-excluded-byte-compile ()
  "Drop Flymake's byte-compile check in files the lint excludes."
  (when (and buffer-file-name (dl-lint-excluded-p buffer-file-name))
    (remove-hook 'flymake-diagnostic-functions #'elisp-flymake-byte-compile t)))
(add-hook 'emacs-lisp-mode-hook #'dl-elisp--skip-excluded-byte-compile)

;; Turn Flymake's "not known to be defined" warnings into declare-function forms.
(use-package dl-declare
  :ensure nil
  :commands dl-declare-insert-from-flymake)

;; Built-in Elisp mode bindings.
(use-package elisp-mode
  :ensure nil
  :bind (:map emacs-lisp-mode-map
          ("C-c C-c" . eval-defun)
          ("C-c C-b" . eval-buffer)
          ("C-c C-r" . eval-region)
          ("C-c C-k" . emacs-lisp-byte-compile)
          ("C-c C-z" . ielm)))

;; Structural editing. Pick this OR paredit.
;; Or maybe try lispy: https://github.com/abo-abo/lispy
;;

(use-package puni
  :hook
  ((emacs-lisp-mode lisp-interaction-mode ielm-mode) . puni-mode)
  :bind (:map puni-mode-map
          ("C-)" . puni-slurp-forward)
          ("C-}" . puni-barf-forward)
          ("C-(" . puni-slurp-backward)
          ("C-{" . puni-barf-backward)))

;; Inline evaluation result overlays.
(use-package eros
  :hook (emacs-lisp-mode . eros-mode))

;; Add examples to Helpful buffers.
(use-package elisp-demos
  :after helpful
  :config
  (advice-add 'helpful-update :after #'elisp-demos-advice-helpful-update))

;; Discover functions by example.
(use-package suggest
  :commands suggest)

;; Built-in docstring/style checker.
(use-package checkdoc
  :ensure nil
  :commands (checkdoc checkdoc-current-buffer))

;; mostly these warnings are annoying
(when dl/package-lint-enable
  (use-package package-lint
    :commands package-lint-buffer)
  ;; Native Flymake integration for package-lint.
  (use-package package-lint-flymake
    :hook (emacs-lisp-mode . package-lint-flymake-setup)))

(use-package highlight-quoted)
(use-package highlight-numbers)
(use-package highlight-defined)


(provide 'dl-elisp)
