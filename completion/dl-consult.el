;;; dl-consult.el --- CONSULT -*- lexical-binding: t; -*-

;; `C-c s …' search map bindings live in `core/dl-keymap.el' so the
;; scope ladder (lower=narrower, upper=wider) is in one place.  These
;; non-prefix globals stay here — they're Emacs-native escape hatches,
;; not part of the family map.
(use-package consult
  :bind (("C-x b"   . consult-buffer)
          ("M-y"    . consult-yank-pop)
          ("M-g g"  . consult-goto-line)
          ("M-s r"  . consult-ripgrep)))

(defun my/consult-line-symbol-at-point ()
  "Run `consult-line' seeded with the symbol at point."
  (interactive)
  (consult-line (thing-at-point 'symbol t)))

(defun my/consult-ripgrep-prompt-dir ()
  "Run `consult-ripgrep', always prompting for the search root."
  (interactive)
  (consult-ripgrep (read-directory-name "Ripgrep in: ")))

(provide 'dl-consult)
