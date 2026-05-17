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
;;   C-c s / SPC s   search   (scope ladder: lower=narrower, upper=wider)
;;   C-c p / SPC p   project  (project.el-aligned letters)
;;   C-c j / SPC j   jump     (avy family)
;;   C-c n / SPC n   notes    (sub-prefixes: N=new, m=manage, v=review, W=work)
;;   C-c o / SPC o   org      (cross-buffer entry points only)
;;   C-c t / SPC t   toggle
;;   C-c e / SPC e   eval
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
(defvar-keymap my-project-map     :name "project")
(defvar-keymap my-jump-map        :name "jump")
(defvar-keymap my-git-map         :name "git")
(defvar-keymap my-notes-map             :name "notes")
(defvar-keymap my-notes-new-map         :name "notes:new")
(defvar-keymap my-notes-manage-map      :name "notes:manage")
(defvar-keymap my-notes-review-map      :name "notes:review")
(defvar-keymap my-notes-work-map        :name "notes:work")
(defvar-keymap my-notes-work-review-map :name "notes:work:review")
(defvar-keymap my-roam-map              :name "roam")
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
(define-key global-map (kbd "C-c p") my-project-map)
(define-key global-map (kbd "C-c j") my-jump-map)
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
    "C-c p"   "project"
    "C-c j"   "jump"
    "C-c g"   "git"
    "C-c n"   "notes"
    "C-c n N"   "notes:new"
    "C-c n m"   "notes:manage"
    "C-c n v"   "notes:review"
    "C-c n W"   "notes:work"
    "C-c n W v" "notes:work:review"
    "C-c n r"   "roam"
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
(my/bind my-file-map   "y" #'my/yazi-here           "yazi")
(my/bind my-file-map   "b" #'my/broot-here          "broot")
(my/bind my-file-map   "K" #'my/delete-current-buffer-file "delete file + buffer")
(my/bind my-file-map   "M" #'my/move-file           "move file")
;; Project family lives at C-c p — see `my-project-map' below.

(my/bind my-buffer-map "b" #'consult-buffer         "switch")
(my/bind my-buffer-map "k" #'kill-current-buffer    "kill")
(my/bind my-buffer-map "i" #'ibuffer                "ibuffer")
(my/bind my-buffer-map "n" #'my/next-user-buffer    "next (skip *…* / dired)")
(my/bind my-buffer-map "p" #'my/previous-user-buffer "prev (skip *…* / dired)")
(my/bind my-buffer-map "t" #'my/tmp-buffer          "tmp buffer (same mode)")

(declare-function hydra-window-resize/body "dl-keybind")
(my/bind my-window-map "<left>"  #'windmove-left        "left")
(my/bind my-window-map "<down>"  #'windmove-down        "down")
(my/bind my-window-map "<up>"    #'windmove-up          "up")
(my/bind my-window-map "<right>" #'windmove-right       "right")
(my/bind my-window-map "s"       #'split-and-follow-horizontally "split-below (+focus)")
(my/bind my-window-map "v"       #'split-and-follow-vertically   "split-right (+focus)")
(my/bind my-window-map "S"       #'split-window-below   "split-below (no focus)")
(my/bind my-window-map "V"       #'split-window-right   "split-right (no focus)")
(my/bind my-window-map "o"       #'delete-other-windows "only")
(my/bind my-window-map "d"       #'delete-window        "delete")
(my/bind my-window-map "="       #'balance-windows      "balance")
(my/bind my-window-map "r"       #'hydra-window-resize/body  "resize (hydra)")
(my/bind my-window-map "f"       #'transpose-frame           "transpose h ⇄ v")
(my/bind my-window-map "c"       #'my/rotate-windows         "cycle (rotate)")
(my/bind my-window-map "C"       #'my/rotate-windows-backward "cycle back")
(my/bind my-window-map "x"       #'my/window-exchange-buffer  "exchange buffer (ace)")
(my/bind my-window-map "P"       #'my/toggle-window-dedicated "pin (dedicated)")

(my/bind my-git-map    "g" #'magit-status           "status")
(my/bind my-git-map    "l" #'git-link               "link")

;; Project family — parallel to C-c f, project.el-aligned letters so
;; muscle memory survives between C-x p and C-c p.
(my/bind my-project-map "p" #'project-switch-project          "switch project")
(my/bind my-project-map "f" #'project-find-file               "find file")
(my/bind my-project-map "b" #'project-switch-to-buffer        "switch buffer")
(my/bind my-project-map "k" #'project-kill-buffers            "kill buffers")
(my/bind my-project-map "d" #'project-dired                   "dired")
(my/bind my-project-map "D" #'project-find-dir                "find dir")
(my/bind my-project-map "c" #'project-compile                 "compile")
(my/bind my-project-map "r" #'project-query-replace-regexp    "query-replace")
(my/bind my-project-map "g" #'project-find-regexp             "grep (xref)")
(my/bind my-project-map "v" #'project-vc-dir                  "vc-dir")
(my/bind my-project-map "e" #'project-eshell                  "eshell")
(my/bind my-project-map "s" #'project-shell                   "shell")
(my/bind my-project-map "!" #'project-shell-command           "shell-command")

;; Search map — scope ladder.  Lowercase narrows, uppercase widens.
;; Helpers `my/consult-line-symbol-at-point' /
;; `my/consult-ripgrep-prompt-dir' live in `completion/dl-consult.el'.
(my/bind my-search-map  "s" #'consult-line                       "line (buffer)")
(my/bind my-search-map  "S" #'consult-line-multi                 "line (buffers)")
(my/bind my-search-map  "." #'my/consult-line-symbol-at-point    "line @ symbol")
(my/bind my-search-map  "o" #'consult-outline                    "outline")
(my/bind my-search-map  "i" #'consult-imenu                      "imenu")
(my/bind my-search-map  "I" #'consult-imenu-multi                "imenu (project)")
(my/bind my-search-map  "r" #'consult-ripgrep                    "ripgrep (project)")
(my/bind my-search-map  "R" #'my/consult-ripgrep-prompt-dir      "ripgrep (dir prompt)")
(my/bind my-search-map  "d" #'consult-find                       "find filenames")
(my/bind my-search-map  "m" #'consult-mark                       "mark ring")
(my/bind my-search-map  "M" #'consult-global-mark                "global mark ring")
(my/bind my-search-map  "g" #'rg-menu                            "rg menu")
(my/bind my-search-map  "q" #'vr/query-replace                   "vr query-replace")
(my/bind my-search-map  "Q" #'vr/replace                         "vr replace")

;; Jump map — avy family.  Chord bindings `C-:'/`C-;' live in
;; `editing/dl-motion.el' as fast escape hatches.
(my/bind my-jump-map    "j" #'avy-goto-line          "line")
(my/bind my-jump-map    "c" #'avy-goto-char-timer    "char (timer)")
(my/bind my-jump-map    "2" #'avy-goto-char-2        "2-char")
(my/bind my-jump-map    "w" #'avy-goto-word-1        "word")
(my/bind my-jump-map    "p" #'my/forward-or-backward-sexp "match paren")

;; Eval map — scope ladder over Elisp.  Lowercase reads, uppercase prints.
(my/bind my-eval-map    "e" #'eval-last-sexp              "last sexp")
(my/bind my-eval-map    "E" #'eval-print-last-sexp        "last sexp + insert")
(my/bind my-eval-map    "f" #'eval-defun                  "defun")
(my/bind my-eval-map    "r" #'eval-region                 "region")
(my/bind my-eval-map    "b" #'eval-buffer                 "buffer")
(my/bind my-eval-map    "i" #'ielm                        "ielm")
(my/bind my-eval-map    "s" #'scratch-buffer              "scratch")
(my/bind my-eval-map    "x" #'eval-expression             "expression (M-:)")
(my/bind my-eval-map    "m" #'pp-macroexpand-last-sexp    "macroexpand")

;; Org map — cross-buffer entry points only.  In-buffer Org commands stay
;; at Org's own `C-c C-<x>' (mode-specific space, Org owns it).
(my/bind my-org-map     "h" #'consult-org-heading         "heading (buffer)")
(my/bind my-org-map     "H" (lambda () (interactive)
                              (consult-org-heading nil (org-agenda-files))) "heading (agenda)")
(my/bind my-org-map     "j" #'org-clock-goto              "clock goto")
(my/bind my-org-map     "i" #'org-clock-in-last           "clock-in last")
(my/bind my-org-map     "O" #'org-clock-out               "clock-out")
(my/bind my-org-map     "r" #'org-refile                  "refile")
(my/bind my-org-map     "q" #'my/org-ql-find-here         "org-ql (here)")
(my/bind my-org-map     "b" #'org-switchb                 "switch org buffer")
(my/bind my-org-map     "L" #'org-insert-link-global      "insert link (global)")

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
(declare-function org-roam-node-find       "org-roam-node")
(declare-function org-roam-node-insert     "org-roam-node")
(declare-function org-roam-buffer-toggle   "org-roam-mode")
(declare-function org-roam-capture         "org-roam-capture")
(declare-function org-roam-db-sync         "org-roam-db")
(declare-function org-roam-graph           "org-roam-graph")
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

;; Work compartment — `C-c n W …'.  Constructors live directly under `W',
;; reviews under `W v', so personal namespaces stay clean.
(my/bind my-notes-map      "W" my-notes-work-map        "work")
(my/bind my-notes-work-map "v" my-notes-work-review-map "review")

(my/bind my-notes-work-map "h" (lambda () (interactive) (find-file dl-notes-work-file))       "open work.org")
(my/bind my-notes-work-map "i" (lambda () (interactive) (find-file dl-notes-work-inbox-file)) "work inbox")
(my/bind my-notes-work-map "I" (lambda () (interactive) (dired dl-notes-work-intake-dir))    "work intake")
(my/bind my-notes-work-map "j" #'my/work-journal-note  "work journal")
(my/bind my-notes-work-map "w" #'my/work-weekly-note   "work weekly")
(my/bind my-notes-work-map "q" #'my/work-org-ql-find   "work query")

(my/bind my-notes-work-map "p" #'my/denote-new-work-project   "new work project")
(my/bind my-notes-work-map "a" #'my/denote-new-work-area      "new work area")
(my/bind my-notes-work-map "m" #'my/denote-new-work-meeting   "new work meeting")
(my/bind my-notes-work-map "P" #'my/denote-new-work-person    "new work person")
(my/bind my-notes-work-map "s" #'my/denote-new-work-source    "new work source")
(my/bind my-notes-work-map "S" #'my/denote-new-work-slip      "new work slip")
(my/bind my-notes-work-map "r" #'my/denote-new-work-reference "new work reference")
(my/bind my-notes-work-map "x" #'my/denote-new-work-index     "new work index")

(my/bind my-notes-work-review-map "i" #'my/review-work-inbox                "inbox")
(my/bind my-notes-work-review-map "I" #'my/review-work-intake               "intake")
(my/bind my-notes-work-review-map "w" #'my/review-work-weekly               "weekly + waiting")
(my/bind my-notes-work-review-map "s" #'my/review-work-stale                "stale waiting")
(my/bind my-notes-work-review-map "r" #'my/review-work-references-retained  "refs: raw")
(my/bind my-notes-work-review-map "u" #'my/review-work-references-untrusted "refs: untrusted")

;; Roam compartment — `C-c n r …'.  Kept wired but not the primary
;; navigator; lifted out of `dl-org-roam.el' to clear tier-1 `C-c r'.
(my/bind my-notes-map  "r" my-roam-map               "roam")
(my/bind my-roam-map   "f" #'org-roam-node-find      "find node")
(my/bind my-roam-map   "i" #'org-roam-node-insert    "insert link")
(my/bind my-roam-map   "b" #'org-roam-buffer-toggle  "buffer toggle")
(my/bind my-roam-map   "c" #'org-roam-capture        "capture")
(my/bind my-roam-map   "s" #'org-roam-db-sync        "db sync")
(my/bind my-roam-map   "g" #'org-roam-graph          "graph")

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
(my/bind my-toggle-map "B" #'tab-line-mode                    "tab-line (buffer)")
(my/bind my-toggle-map "G" #'global-tab-line-mode             "tab-line (global)")
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
    '("<escape>" . ignore)
;;    '("s-[" . my/previous-user-buffer)
;;    '("s-]" . my/next-user-buffer)
    '("s-{" . tab-bar-switch-to-prev-tab)
    '("s-}" . tab-bar-switch-to-next-tab))

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
    ;; Flick-style user-buffer cycling.
    '("[" . my/previous-user-buffer)
    '("]" . my/next-user-buffer)
    ;; Mirror C-c <letter> prefix maps onto SPC <letter>.
    ;; Note: lowercase m and g are eaten by meow-keypad as the meta /
    ;; ctrl-meta prefix dispatchers before leader-keymap is consulted,
    ;; so git and term use capital aliases (SPC G, SPC M) in Meow.
    ;; Lowercase C-c g / C-c m still work directly outside Meow.
    (cons "f" my-file-map)
    (cons "b" my-buffer-map)
    (cons "w" my-window-map)
    (cons "s" my-search-map)
    (cons "p" my-project-map)
    (cons "j" my-jump-map)
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
