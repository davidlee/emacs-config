;;; dl-keymap.el --- Keymaps & leader (early) -*- lexical-binding: t; -*-
;; -*- byte-compile-warnings: (not unresolved free-vars) -*-
;; -*- native-compile-warnings: (not unresolved) -*-

;; Personal command interface.
;;
;; Durable prefix: C-c <letter>.  Meow normal-state mirrors each prefix as
;; SPC <letter> via meow-leader-define-key, so SPC f f and C-c f f both
;; reach find-file.  Meow's built-in SPC c -> C-c translation continues
;; to work as a fallback.
;;
;;   C-c f / SPC f   file
;;   C-c b / SPC b   buffer
;;   C-c w / SPC w   window
;;   C-c s / SPC s   search
;;   C-c j / SPC j   session (easysession) -- DISABLED
;;   C-c n / SPC n   notes  (sub-prefixes: N=new-by-class, m=manage, v=review)
;;   C-c o / SPC o   org / open
;;   C-c t / SPC t   toggle
;;   C-c e / SPC e   eval / elisp
;;   C-c g / SPC G   git    (capital in Meow: SPC g is keypad C-M- prefix)
;;   C-c m / SPC M   term   (capital in Meow: SPC m is keypad M- prefix)
;;   C-c z / SPC z   fold   (kirigami; routes to active backend)
;;
;; Meow normal-state `h' is also bound to `mode-specific-map' (the C-c
;; keymap), giving a third path: h f f, h j s, etc.  `meow-left' is
;; dropped — home-row arrows live on a layer.
;;
;; Add new bindings with `my/bind' so each carries a which-key label and
;; a collision warning.

(defun my/narrow-or-widen-dwim ()
  "Widen if buffer is narrowed; otherwise narrow to region, defun, or org subtree."
  (interactive)
  (cond ((buffer-narrowed-p) (widen))
    ((use-region-p) (narrow-to-region (region-beginning) (region-end)))
    ((derived-mode-p 'org-mode) (org-narrow-to-subtree))
    (t (narrow-to-defun))))

(defun my/eglot-toggle ()
  "Start eglot in current buffer, or shut it down if already managed."
  (interactive)
  (if (bound-and-true-p eglot--managed-mode)
    (call-interactively #'eglot-shutdown)
    (call-interactively #'eglot)))

(defun my/bind (map key cmd &optional desc)
  "Bind KEY to CMD in MAP, registering DESC as which-key label.
Warns when KEY already has a binding in MAP that differs from CMD."
  (let ((existing (lookup-key map (kbd key))))
    (when (and existing
            (not (numberp existing))
            (not (eq existing cmd)))
      (message "my/bind: overriding %s in %S: %S -> %S"
        key map existing cmd)))
  (define-key map (kbd key) cmd)
  (when desc
    (with-eval-after-load 'which-key
      (which-key-add-keymap-based-replacements map key desc))))

;; Prefix maps -- one per command family.
(defvar-keymap my-file-map        :name "file")
(defvar-keymap my-buffer-map      :name "buffer")
(defvar-keymap my-window-map      :name "window")
(defvar-keymap my-search-map      :name "search")
                                        ;(defvar-keymap my-session-map :name "session")
(defvar-keymap my-git-map         :name "git")
(defvar-keymap my-notes-map        :name "notes")
(defvar-keymap my-notes-new-map    :name "notes:new")
(defvar-keymap my-notes-manage-map :name "notes:manage")
(defvar-keymap my-notes-review-map :name "notes:review")
(defvar-keymap my-org-map         :name "org")
(defvar-keymap my-toggle-map      :name "toggle")
(defvar-keymap my-eval-map        :name "eval")
(defvar-keymap my-term-map        :name "term")
(defvar-keymap my-fold-map        :name "fold")

;; Bind prefix maps globally under C-c <letter>.
(define-key global-map (kbd "C-c f") my-file-map)
(define-key global-map (kbd "C-c b") my-buffer-map)
(define-key global-map (kbd "C-c w") my-window-map)
(define-key global-map (kbd "C-c s") my-search-map)
                                        ;(define-key global-map (kbd "C-c j") my-session-map)
(define-key global-map (kbd "C-c g") my-git-map)
(define-key global-map (kbd "C-c n") my-notes-map)
(define-key global-map (kbd "C-c o") my-org-map)
(define-key global-map (kbd "C-c t") my-toggle-map)
(define-key global-map (kbd "C-c e") my-eval-map)
(define-key global-map (kbd "C-c m") my-term-map)
(define-key global-map (kbd "C-c z") my-fold-map)

;; Universal Emacs muscle memory for dired-jump; C-x C-n repurposed
;; from the dropped dired-sidebar binding to dirvish-side.
(global-set-key (kbd "C-x C-j") #'dired-jump)
(global-set-key (kbd "C-x C-n") #'dirvish-side)

;; Prefix labels for which-key.
(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "C-c f"   "file"
    "C-c b"   "buffer"
    "C-c w"   "window"
    "C-c s"   "search"
    "C-c j"   "session"
    "C-c g"   "git"
    "C-c n"   "notes"
    "C-c n N" "notes:new"
    "C-c n m" "notes:manage"
    "C-c n v" "notes:review"
    "C-c o"   "org"
    "C-c t"   "toggle"
    "C-c e"   "eval"
    "C-c m"   "term"
    "C-c z"   "fold"))

;; Concrete bindings -- starter set, grow as needed.
(my/bind my-file-map   "f" #'find-file              "find-file")
(my/bind my-file-map   "s" #'save-buffer            "save")
(my/bind my-file-map   "S" #'write-file             "save-as")
(my/bind my-file-map   "r" #'consult-recent-file    "recent")
(my/bind my-file-map   "d" #'dired-jump             "dired-jump")
(my/bind my-file-map   "D" #'dirvish                "dirvish")
(my/bind my-file-map   "t" #'dirvish-side           "dirvish-side (tree)")
(my/bind my-file-map   "F" #'project-find-file      "project-find-file")
(my/bind my-file-map   "p" #'project-switch-project "project-switch")
(my/bind my-file-map   "y" #'my/yazi-here           "yazi")
(my/bind my-file-map   "b" #'my/broot-here          "broot")

(my/bind my-buffer-map "b" #'consult-buffer         "switch")
(my/bind my-buffer-map "k" #'kill-current-buffer    "kill")
(my/bind my-buffer-map "i" #'ibuffer                "ibuffer")
(my/bind my-buffer-map "n" #'next-buffer            "next")
(my/bind my-buffer-map "p" #'previous-buffer        "prev")

(my/bind my-window-map "<left>"  #'windmove-left        "left")
(my/bind my-window-map "<down>"  #'windmove-down        "down")
(my/bind my-window-map "<up>"    #'windmove-up          "up")
(my/bind my-window-map "<right>" #'windmove-right       "right")
(my/bind my-window-map "s"       #'split-window-below   "split-below")
(my/bind my-window-map "v"       #'split-window-right   "split-right")
(my/bind my-window-map "o"       #'delete-other-windows "only")
(my/bind my-window-map "d"       #'delete-window        "delete")
(my/bind my-window-map "="       #'balance-windows      "balance")

(my/bind my-git-map    "g" #'magit-status           "status")
(my/bind my-git-map    "l" #'git-link               "link")

;; Org map -- in-buffer org navigation via consult-org (bundled with consult).
(my/bind my-org-map    "h" #'consult-org-heading    "heading")

;; Notes (C-c n …) — see plan §4b in ~/.claude/plans/yes-use-dl-for-staged-quiche.md.
;; Sub-prefixes for new-by-class / manage / review live below.
;;
;; Phase 5 commands (`consult-notes', `org-ql') aren't installed yet —
;; binding by symbol is fine, the void-function error surfaces only if
;; pressed before Phase 5 lands.  `declare-function' silences the
;; byte-compiler "not known to be defined" warnings until then.
(declare-function consult-notes                     "consult-notes")
(declare-function consult-notes-search-in-all-notes "consult-notes")
(declare-function org-ql-find                       "org-ql-find")
(my/bind my-notes-map "N" my-notes-new-map    "new-by-class")
(my/bind my-notes-map "m" my-notes-manage-map "manage")
(my/bind my-notes-map "v" my-notes-review-map "review")
(my/bind my-notes-map "c" #'org-capture                       "capture")
(my/bind my-notes-map "j" #'my/journal-note                   "journal today")
(my/bind my-notes-map "w" #'my/weekly-note                    "weekly")
(my/bind my-notes-map "n" #'denote                            "new note")
(my/bind my-notes-map "f" #'consult-notes                     "find note (Phase 5)")
(my/bind my-notes-map "s" #'consult-notes-search-in-all-notes "search notes (Phase 5)")
(my/bind my-notes-map "l" #'org-store-link                    "store link")
(my/bind my-notes-map "i" #'denote-link                       "insert link")
(my/bind my-notes-map "o" #'org-open-at-point-global          "open link")
(my/bind my-notes-map "g" #'org-mark-ring-goto                "go back")
(my/bind my-notes-map "b" #'denote-backlinks                  "backlinks")
(my/bind my-notes-map "q" #'org-ql-find                       "ql find (Phase 5)")

(my/bind my-notes-new-map "p" #'my/denote-new-project    "project")
(my/bind my-notes-new-map "a" #'my/denote-new-area       "area")
(my/bind my-notes-new-map "s" #'my/denote-new-source     "source")
(my/bind my-notes-new-map "S" #'my/denote-new-slip       "slip")
(my/bind my-notes-new-map "r" #'my/denote-new-reference  "reference")
(my/bind my-notes-new-map "i" #'my/denote-new-index      "index")
(my/bind my-notes-new-map "j" #'my/journal-note          "journal today")
(my/bind my-notes-new-map "w" #'my/weekly-note           "weekly")

(my/bind my-notes-manage-map "r" #'denote-rename-file                     "rename")
(my/bind my-notes-manage-map "R" #'denote-rename-file-using-front-matter  "rename (front-matter)")
(my/bind my-notes-manage-map "k" #'denote-rename-file-keywords            "edit keywords")
(my/bind my-notes-manage-map "t" #'denote-rename-file-title               "retitle")

(my/bind my-notes-review-map "i" #'my/review-inbox                  "inbox")
(my/bind my-notes-review-map "I" #'my/review-intake                 "intake (dired)")
(my/bind my-notes-review-map "w" #'my/review-weekly                 "weekly + waiting")
(my/bind my-notes-review-map "s" #'my/review-stale                  "stale waiting")
(my/bind my-notes-review-map "r" #'my/review-references-retained    "refs: raw")
(my/bind my-notes-review-map "u" #'my/review-references-untrusted   "refs: untrusted")

;; Session map -- easysession.  Package is :demand t so symbols resolve
;; by call time even though we bind here at startup.
;; (my/bind my-session-map "s" #'easysession-save                          "save")
;; (my/bind my-session-map "l" #'easysession-switch-to                     "load")
;; (my/bind my-session-map "L" #'easysession-switch-to-and-restore-geometry "load+geometry")
;; (my/bind my-session-map "r" #'easysession-rename                        "rename")
;; (my/bind my-session-map "R" #'easysession-reset                         "reset")
;; (my/bind my-session-map "u" #'easysession-unload                        "unload")
;; (my/bind my-session-map "d" #'easysession-delete                        "delete")

(my/bind my-term-map   "t" #'ghostel                           "ghostel")
(my/bind my-term-map   "T" #'my/ghostel-here                   "ghostel (new, here)")
(my/bind my-term-map   "o" #'ghostel-project                   "ghostel (project)")
(my/bind my-term-map   "n" #'ghostel-other                     "ghostel-next")
(my/bind my-term-map   "a" #'my/shpool                         "attach")
(my/bind my-term-map   "p" #'my/shpool-project                 "project")
(my/bind my-term-map   "F" #'my/shpool-force                   "force-attach")
(my/bind my-term-map   "r" #'my/shpool-restore                 "restore")
(my/bind my-term-map   "L" #'my/shpool-list                    "list")
(my/bind my-term-map   "d" #'my/shpool-detach-current          "detach")
(my/bind my-term-map   "k" #'my/shpool-kill-session            "kill-session")
(my/bind my-term-map   "+" #'my/shpool-add-current-to-restore  "+restore")
(my/bind my-term-map   "-" #'my/shpool-remove-from-restore     "-restore")
(my/bind my-term-map   "f" #'my/shpool-forget-session          "forget")

;; Fold map -- kirigami routes to active backend (outline / hs / treesit-fold).
(my/bind my-fold-map   "o" #'kirigami-open-fold      "open")
(my/bind my-fold-map   "O" #'kirigami-open-fold-rec  "open-rec")
(my/bind my-fold-map   "r" #'kirigami-open-folds     "open-all")
(my/bind my-fold-map   "c" #'kirigami-close-fold     "close")
(my/bind my-fold-map   "m" #'kirigami-close-folds    "close-all")
(my/bind my-fold-map   "a" #'kirigami-toggle-fold    "toggle")

;; Toggle map -- session knobs.
(my/bind my-toggle-map "l" #'display-line-numbers-mode        "line-numbers")
(my/bind my-toggle-map "L" #'global-display-line-numbers-mode "line-numbers (global)")
(my/bind my-toggle-map "w" #'visual-line-mode                 "visual-line (soft-wrap)")
(my/bind my-toggle-map "t" #'toggle-truncate-lines            "truncate-lines")
(my/bind my-toggle-map "h" #'hl-line-mode                     "hl-line")
(my/bind my-toggle-map "p" #'display-fill-column-indicator-mode "fill-column-indicator")
(my/bind my-toggle-map "W" #'whitespace-mode                  "whitespace")
(my/bind my-toggle-map "r" #'read-only-mode                   "read-only")
(my/bind my-toggle-map "f" #'auto-fill-mode                   "auto-fill (hard-wrap)")
(my/bind my-toggle-map "s" #'jinx-mode                        "spell (jinx) buffer")
(my/bind my-toggle-map "S" #'my/jinx-global-mode              "spell (jinx) prog/text/org")
(my/bind my-toggle-map "c" #'my/toggle-margins                "margins (olivetti / vfc)")
(my/bind my-toggle-map "V" #'variable-pitch-mode              "variable-pitch")
(my/bind my-toggle-map "e" #'electric-pair-mode               "electric-pair")
(my/bind my-toggle-map "i" #'indent-tabs-mode                 "indent-tabs")
(my/bind my-toggle-map "a" #'auto-revert-mode                 "auto-revert")
(my/bind my-toggle-map "n" #'my/narrow-or-widen-dwim          "narrow/widen")
(my/bind my-toggle-map "m" #'flymake-mode                     "flymake")
(my/bind my-toggle-map "d" #'toggle-debug-on-error            "debug-on-error")
(my/bind my-toggle-map "D" #'toggle-debug-on-quit             "debug-on-quit")
(my/bind my-toggle-map "T" #'consult-theme                    "theme")
(my/bind my-toggle-map "P" #'spacious-padding-mode            "spacious-padding")
;;(my/bind my-toggle-map "B" #'beacon-mode                      "beacon")

(my/bind my-toggle-map "B" #'tab-line-mode                    "tab-line")
(my/bind my-toggle-map "B" #'global-tab-line-mode             "global tab-line")
(my/bind my-toggle-map "g" #'diff-hl-mode                     "diff-hl (vcs gutter)")
(my/bind my-toggle-map "*" #'prettify-symbols-mode            "prettify-symbols")
(my/bind my-toggle-map ")" #'rainbow-delimiters-mode          "rainbow-delimiters")
(my/bind my-toggle-map "R" #'rainbow-mode                     "rainbow (colors)")
(my/bind my-toggle-map "=" #'aggressive-indent-mode           "aggressive-indent")
(my/bind my-toggle-map "E" #'my/eglot-toggle                  "eglot")

(defun meow-setup ()
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)

  (meow-motion-define-key
    '("j" . meow-next)
    '("k" . meow-prev)
    '("<escape>" . ignore))

  (meow-leader-define-key
    ;; Digit arguments.
    '("1" . meow-digit-argument)
    '("2" . meow-digit-argument)
    '("3" . meow-digit-argument)
    '("4" . meow-digit-argument)
    '("5" . meow-digit-argument)
    '("6" . meow-digit-argument)
    '("7" . meow-digit-argument)
    '("8" . meow-digit-argument)
    '("9" . meow-digit-argument)
    '("0" . meow-digit-argument)
    '("/" . meow-keypad-describe-key)
    '("?" . meow-cheatsheet)
    ;; Mirror C-c <letter> prefix maps onto SPC <letter>.
    ;; Note: lowercase m and g are eaten by meow-keypad as the meta /
    ;; ctrl-meta prefix dispatchers before leader-keymap is consulted,
    ;; so git and term use capital aliases (SPC G, SPC M) in Meow.
    ;; Lowercase C-c g / C-c m still work directly outside Meow.
    (cons "f" my-file-map)
    (cons "b" my-buffer-map)
    (cons "w" my-window-map)
    (cons "s" my-search-map)
    ;; (cons "j" my-session-map)
    (cons "G" my-git-map)
    (cons "n" my-notes-map)
    (cons "o" my-org-map)
    (cons "t" my-toggle-map)
    (cons "e" my-eval-map)
    (cons "M" my-term-map)
    (cons "z" my-fold-map))

  (meow-normal-define-key
    '("0" . meow-expand-0)
    '("9" . meow-expand-9)
    '("8" . meow-expand-8)
    '("7" . meow-expand-7)
    '("6" . meow-expand-6)
    '("5" . meow-expand-5)
    '("4" . meow-expand-4)
    '("3" . meow-expand-3)
    '("2" . meow-expand-2)
    '("1" . meow-expand-1)
    '("-" . negative-argument)
    '(";" . meow-reverse)
    '("," . meow-inner-of-thing)
    '("." . meow-bounds-of-thing)
    '("[" . meow-beginning-of-thing)
    '("]" . meow-end-of-thing)
    '("a" . meow-append)
    '("A" . meow-open-below)
    '("b" . meow-back-word)
    '("B" . meow-back-symbol)
    '("c" . meow-change)
    '("d" . meow-delete)
    '("D" . meow-backward-delete)
    '("e" . meow-next-word)
    '("E" . meow-next-symbol)
    '("f" . meow-find)
    '("F" . meow-find-expand)
    '("g" . meow-cancel-selection)
    '("G" . meow-grab)
    `("h" . ,mode-specific-map)
    '("H" . meow-left-expand)
    '("i" . meow-insert)
    '("I" . meow-open-above)
    '("j" . meow-next)
    '("J" . meow-next-expand)
    '("k" . meow-prev)
    '("K" . meow-prev-expand)
    '("l" . meow-right)
    '("L" . meow-right-expand)
    '("m" . meow-join)
    '("n" . meow-search)
    '("o" . meow-block)
    '("O" . meow-to-block)
    '("p" . meow-yank)
    '("q" . meow-quit)
    '("Q" . meow-goto-line)
    '("r" . meow-replace)
    '("R" . meow-swap-grab)
    '("s" . meow-kill)
    '("t" . meow-till)
    '("u" . meow-undo)
    '("U" . meow-undo-in-selection)
    '("v" . meow-visit)
    '("w" . meow-mark-word)
    '("W" . meow-mark-symbol)
    '("x" . meow-line)
    '("X" . meow-goto-line)
    '("y" . meow-save)
    '("Y" . meow-sync-grab)
    '("z" . meow-pop-selection)
    '("'" . repeat)
    '("<escape>" . ignore)))

(provide 'dl-keymap)
;;; dl-keymap.el ends here
