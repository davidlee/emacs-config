;;; dl-motion.el --- Getting around -*- lexical-binding: t; -*-

(use-package dumb-jump
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

;; avy: chord bindings here are escape hatches; the family map lives
;; centrally at `C-c j' (`my-jump-map') in `core/dl-keymap.el'.
;; `C-'' previously held `avy-goto-char-2' but was reassigned to
;; `embark-dwim' — the 2-char variant lives at `C-c j 2' now.
(use-package avy
  :commands (avy-goto-char avy-goto-char-2 avy-goto-char-timer
              avy-goto-line avy-goto-word-1)
  :bind ( ("C-:" . avy-goto-char)
          ("C-'" . avy-goto-char-2)  ;; <-- usually this one is what you want
          ("C-;" . avy-goto-char-timer)))

(use-package ace-window
  :custom
  (aw-scope 'frame)
  (aw-ignore-current t)
  (aw-backround nil)
  :bind (("M-o" . ace-window)))


;; `C-,' previously held `goto-last-change' but was reassigned to
;; `embark-act'.  Reverse direction still at `C-.'; rebind forward
;; here if you miss it.
(use-package goto-chg
  :bind ( ("C-."   . goto-last-change)
          ("C-S-." . goto-last-change-reverse)))


(use-package git-link) ; https://github.com/sshaw/git-link
(use-package copy-as-format) ; https://github.com/sshaw/copy-as-format

;; SELECTION
(use-package expand-region)

;; vim-style `%' — jump to the matching paren when adjacent to one.
(defun my/forward-or-backward-sexp (&optional arg)
  "Jump to the matching parenthesis when point is adjacent to one."
  (interactive "^p")
  (cond ((looking-at "\\s(")     (forward-sexp arg))
    ((looking-back "\\s)" 1) (backward-sexp arg))
    ((looking-at "\\s)")     (forward-char) (backward-sexp arg))
    ((looking-back "\\s(" 1) (backward-char) (forward-sexp arg))))

(provide 'dl-motion)
