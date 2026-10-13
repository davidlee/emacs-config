;;; dl-diagnostics.el --- Flymake diagnostics: checkers, inline display -*- lexical-binding: t; -*-

;;; Commentary:

;; Flymake is the single diagnostics frontend.  Its backends come from
;; eglot (LSP), Emacs's own backends (elisp, shellcheck, ...), and
;; flycheck's checker library via flymake-flycheck.  flycheck-mode
;; itself is never enabled.  flyover draws the diagnostics inline.
;;
;;   eglot ──────────────┐
;;   built-in backends ──┼──► flymake ──► flyover (inline)
;;   flycheck checkers ──┘           ├──► consult-flymake (C-c d d / D)
;;                                   └──► modeline counters (dl-modeline)
;;
;; Keys: `C-c d' family in core/dl-keymap.el; M-n / M-p below.

;;; Code:

(declare-function flymake-start "flymake")
(declare-function consult-flymake "consult-flymake")
(defvar flyover-mode)

(defun dl-diagnostics--enable-flymake ()
  "Enable `flymake-mode' when this buffer visits a file.
Hidden buffers put into a programming mode, as Org's source-block
fontification does, stay unchecked."
  (when buffer-file-name
    (flymake-mode 1)))

(add-hook 'prog-mode-hook #'dl-diagnostics--enable-flymake)

(defun dl-diagnostics--run-update-hook (&rest _)
  "Run `flymake-after-update-diagnostics-hook' in the reporting buffer."
  (run-hooks 'flymake-after-update-diagnostics-hook))

(use-package flymake
  :ensure nil
  :bind (:map flymake-mode-map
          ("M-n" . flymake-goto-next-error)
          ("M-p" . flymake-goto-prev-error))
  :custom
  ;; flyover draws inline; see `my/diagnostics-toggle-inline-style'.
  (flymake-inline-diagnostics nil)
  :config
  ;; flyover listens on this hook, which Flymake 1.4.7 lacks.  Without
  ;; it flyover advises Flymake globally and drops that advice when any
  ;; one buffer disables flyover-mode, freezing every other buffer.
  (unless (boundp 'flymake-after-update-diagnostics-hook)
    (defvar flymake-after-update-diagnostics-hook nil
      "Hook run in a buffer after Flymake handles a backend report.
Supplied by dl-diagnostics for flyover; Flymake does not define it.")
    (advice-add 'flymake--handle-report :after
                #'dl-diagnostics--run-update-hook)))

;; Checker library only.  Its twins of Flymake's built-in backends stay
;; out so each problem is reported once.
(use-package flycheck
  :defer t
  :custom
  (flycheck-disabled-checkers '(emacs-lisp emacs-lisp-checkdoc sh-shellcheck)))

;; Runs on every `flymake-mode' enable, so it also re-adds the checkers
;; after eglot replaces the backend list (eglot sets the list, then
;; enables `flymake-mode').
(use-package flymake-flycheck
  :hook (flymake-mode . flymake-flycheck-auto))

(use-package flyover
  :hook (flymake-mode . flyover-mode)
  :custom
  (flyover-checkers '(flymake))
  ;; Notes stay as underlines; drawing them all buries the code.
  (flyover-levels '(error warning)))

(defun my/diagnostics-toggle-inline-style ()
  "Swap this buffer's inline diagnostics between flyover and Flymake's own.
Flymake's own is `flymake-inline-diagnostics' set to `fancy'."
  (interactive)
  (if (bound-and-true-p flyover-mode)
      (progn (flyover-mode -1)
             (setq-local flymake-inline-diagnostics 'fancy))
    (setq-local flymake-inline-diagnostics nil)
    (flyover-mode 1))
  (flymake-start)
  (message "Inline diagnostics: %s"
           (if flyover-mode "flyover" "flymake fancy")))

(defun my/consult-flymake-project ()
  "Search Flymake diagnostics across the current project."
  (interactive)
  (consult-flymake t))

(provide 'dl-diagnostics)
;;; dl-diagnostics.el ends here
