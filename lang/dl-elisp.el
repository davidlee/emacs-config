;;; dl-elisp.el --- Emacs Lisp editing setup -*- lexical-binding: t; -*-

(defvar dl/package-lint-enable nil
  "Enable anal package comment linting.")

;; Core Elisp editing.
(use-package emacs
  :ensure nil
  :hook
  ((emacs-lisp-mode . eldoc-mode)
    (emacs-lisp-mode . flymake-mode)
    (emacs-lisp-mode . electric-pair-local-mode)
    (emacs-lisp-mode . show-paren-local-mode))
  :custom
  (show-paren-delay 0)
  (show-paren-style 'mixed)
  (electric-pair-preserve-balance t)
  (electric-pair-delete-adjacent-pairs t)
  (electric-pair-open-newline-between-pairs t)
  :config
  (setq-default lisp-indent-offset 2)
  (setq-default indent-tabs-mode nil))

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

;; Better help buffers.
(use-package helpful
  :bind
  (("C-h f" . helpful-callable)
    ("C-h v" . helpful-variable)
    ("C-h k" . helpful-key)
    ("C-h x" . helpful-command)
    ("C-c C-d" . helpful-at-point)))

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

(provide 'dl-elisp)
