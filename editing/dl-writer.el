
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   General prose-friendly behavior
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(when (>= emacs-major-version 30)       ; compat test
  (add-hook 'text-mode-hook 'visual-wrap-prefix-mode))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Spell checking
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Jinx: Enchanted spell-checking
(use-package jinx
  :hook (((text-mode prog-mode) . jinx-mode))
  :bind (("C-;" . jinx-correct))
  :custom
  (jinx-camel-modes '(prog-mode))
  (jinx-delay 0.01))

(use-package jinx
  :hook (emacs-startup . global-jinx-mode)
  :bind (("M-$" . jinx-correct)
          ("C-M-$" . jinx-languages)))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Dictionary
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(setopt dictionary-use-single-buffer t)
(setopt dictionary-server "dict.org")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;;   Distraction mitigation
;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Olivetti centres prose at `olivetti-body-width'. visual-fill-column does
;; the same thing — partition mode hooks so they don't trample each other.
(use-package olivetti
  :hook ((text-mode org-mode markdown-mode) . olivetti-mode)
  :custom
  (olivetti-body-width 80)
  ;; Default on-hook is `(visual-line-mode)`, which TOGGLES (not enables)
  ;; visual-line-mode -- so it flips OFF in buffers where text-mode-hook
  ;; already turned it on. Replace with an explicit enable.
  (olivetti-mode-on-hook '((lambda () (visual-line-mode 1)))))

(use-package visual-fill-column
  :hook (prog-mode . visual-fill-column-mode))

(defun my/toggle-margins ()
  "Toggle body-width margins for the current buffer.
Uses `visual-fill-column-mode' in `prog-mode' derivatives,
`olivetti-mode' elsewhere."
  (interactive)
  (if (derived-mode-p 'prog-mode)
    (visual-fill-column-mode 'toggle)
    (olivetti-mode 'toggle)))
