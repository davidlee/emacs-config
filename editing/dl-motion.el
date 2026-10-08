;;; dl-motion.el --- Getting around -*- lexical-binding: t; -*-

(use-package dumb-jump
  :custom
  (dumb-jump-prefer-searcher 'rg)
  (xref-show-definitions-function #'consult-xref)
  :config
  (add-hook 'xref-backend-functions #'dumb-jump-xref-activate))

;; avy: chord bindings here are escape hatches; the family map lives
;; centrally at `C-c j' (`my-jump-map') in `core/dl-keymap.el'.
(use-package avy
  :commands (avy-goto-char avy-goto-char-2 avy-goto-char-timer
              avy-goto-line avy-goto-word-1)
  ;; `C-;' is `iedit-mode' (`dl-keybind.el'); the timer variant is
  ;; `C-c j c'.
  :bind ( ("C-:" . avy-goto-char)
          ("C-'" . avy-goto-char-2)))  ;; <-- usually this one is what you want

(use-package ace-window
  :custom
  (aw-scope 'frame)
  (aw-ignore-current t)
  (aw-backround nil)
  :bind (("M-o" . ace-window)))


;; `C-,' previously held `goto-last-change'; it went to `embark-act'
;; and `goto-last-change' moved to `C-.'.
(use-package goto-chg
  :bind ( ("C-."   . goto-last-change)
          ("C-S-." . goto-last-change-reverse)))


(use-package git-link) ; https://github.com/sshaw/git-link
(use-package copy-as-format) ; https://github.com/sshaw/copy-as-format

;; dogears: jump list.  Meow normal `C-o' / `C-S-o' walk it (bound in
;; `core/dl-keymap.el'); `C-c j l' picks a place by completion.
;; dogears only records landings (`dogears-functions', :after) and idle
;; dwells.  A Helix-style jump list also needs the origin, so each
;; command in `dl-motion-jump-commands' is wrapped to dogear both ends.
;; Not `push-mark': meow pushes mark on every new selection.
(defvar dl-motion-jump-commands
  '(xref-find-definitions xref-find-references
    consult-line consult-imenu consult-outline consult-ripgrep
    consult-goto-line consult-mark consult-global-mark
    avy-goto-char avy-goto-char-2 avy-goto-char-timer
    avy-goto-line avy-goto-word-1
    meow-visit beginning-of-buffer end-of-buffer goto-last-change)
  "Commands whose origin and destination are dogeared.")

(defvar dogears-mode)
(declare-function dogears-mode "dogears")
(declare-function dogears-remember "dogears")

(defun dl-motion--dogear-jump (jump &rest args)
  "Call JUMP with ARGS, dogearing the place left and the place reached.
Inert unless `dogears-mode' is on."
  (if (not dogears-mode)
      (apply jump args)
    (dogears-remember)
    (prog1 (apply jump args)
      (dogears-remember))))

(use-package dogears
  :demand t
  :config
  (dolist (command dl-motion-jump-commands)
    (advice-add command :around #'dl-motion--dogear-jump))
  (dogears-mode 1))

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
