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
;;   C-c d / SPC d   diagnostics (Flymake)
;;   C-c L / SPC L   LLM    (gptel; lowercase l is org links)
;;
;; Meow normal-state `o' acts as C-c (`my/meow-ctrl-c'), giving a
;; third path: o f f, o j s, and mode-local keys such as o @ or o '.
;; Arrow-native movement via NAV layer; h/e = word motion on Gallium
;; home row.
;;
;; Add new bindings with `my/bind' so each carries a which-key label and
;; a collision warning.

;; dl-declare-insert-from-flymake

(declare-function aggressive-indent-mode                "aggressive-indent")
(declare-function avy-goto-char-2                       "avy")
(declare-function avy-goto-char-timer                   "avy")
(declare-function avy-goto-line                         "avy")
(declare-function avy-goto-word-1                       "avy")
(declare-function consult-buffer                        "consult")
(declare-function consult-fd                            "consult")
(declare-function consult-find                          "consult")
(declare-function consult-flymake                       "consult-flymake")
(declare-function consult-global-mark                   "consult")
(declare-function consult-imenu                         "consult-imenu")
(declare-function consult-imenu-multi                   "consult-imenu")
(declare-function consult-line                          "consult")
(declare-function consult-line-multi                    "consult")
(declare-function consult-mark                          "consult")
(declare-function consult-org-heading                   "consult-org")
(declare-function consult-outline                       "consult")
(declare-function consult-recent-file                   "consult")
(declare-function consult-ripgrep                       "consult")
(declare-function consult-theme                         "consult")
(declare-function crux-kill-buffer-truename             "crux")
(declare-function crux-open-with                        "crux")
(declare-function denote                                "denote")
(declare-function denote-backlinks                      "denote")
(declare-function denote-link                           "denote")
(declare-function denote-rename-file                    "denote")
(declare-function denote-rename-file-keywords           "denote")
(declare-function denote-rename-file-title              "denote")
(declare-function denote-rename-file-using-front-matter "denote")
(declare-function diff-hl-mode                          "diff-hl")
(declare-function dirvish                               "dirvish")
(declare-function dirvish-side                          "dirvish-side")
(declare-function dogears-go                            "dogears")
(declare-function dogears-sidebar                       "dogears")
(declare-function eglot-shutdown                        "") ; FIXME: defining file unknown
(declare-function flymake-goto-next-error               "flymake")
(declare-function flymake-goto-prev-error               "flymake")
(declare-function flymake-running-backends              "flymake")
(declare-function flymake-show-buffer-diagnostics       "flymake")
(declare-function flymake-show-project-diagnostics      "flymake")
(declare-function flymake-switch-to-log-buffer          "flymake")
(declare-function ghostel-other                         "") ; FIXME: defining file unknown
(declare-function consult-ghostel                       "consult-ghostel")
(declare-function consult-ghostel-status                "consult-ghostel")
(declare-function git-link                              "git-link")
(declare-function gptel                                 "gptel")
(declare-function gptel-abort                           "gptel-request")
(declare-function gptel-add                             "gptel-context")
(declare-function gptel-add-file                        "gptel-context")
(declare-function gptel-agent                           "gptel-agent")
(declare-function gptel-annotate                        "gptel-annotate")
(declare-function gptel-inline                          "gptel-inline")
(declare-function gptel-menu                            "gptel-transient")
(declare-function gptel-rewrite                         "gptel-rewrite")
(declare-function gptel-send                            "gptel")
(declare-function jinx-mode                             "jinx")
(declare-function kirigami-close-fold                   "kirigami")
(declare-function kirigami-close-folds                  "kirigami")
(declare-function kirigami-open-fold                    "kirigami")
(declare-function kirigami-open-fold-rec                "kirigami")
(declare-function kirigami-open-folds                   "kirigami")
(declare-function kirigami-toggle-fold                  "kirigami")
(declare-function magit-status                          "magit-status")
(declare-function my/bough-export-denote                "") ; FIXME: defining file unknown
(declare-function my/bough-export-org                   "") ; FIXME: defining file unknown
(declare-function my/broot-here                         "dl-dirvish")
(declare-function my/consult-flymake-project            "dl-diagnostics")
(declare-function my/consult-line-symbol-at-point       "dl-consult")
(declare-function my/consult-ripgrep-prompt-dir         "dl-consult")
(declare-function my/delete-current-buffer-file         "dl-file-ops")
(declare-function my/denote-kill-link-to-current-file   "") ; FIXME: defining file unknown
(declare-function my/denote-new-area                    "dl-denote-templates")
(declare-function my/denote-new-blog-entry              "dl-denote-blog")
(declare-function my/denote-new-index                   "dl-denote-templates")
(declare-function my/denote-new-project                 "dl-denote-templates")
(declare-function my/denote-new-reference               "dl-denote-templates")
(declare-function my/denote-new-reference-markdown      "dl-denote-templates")
(declare-function my/denote-new-slip                    "dl-denote-templates")
(declare-function my/denote-new-source                  "dl-denote-templates")
(declare-function my/denote-new-work-area               "dl-denote-templates")
(declare-function my/denote-new-work-index              "dl-denote-templates")
(declare-function my/denote-new-work-meeting            "dl-denote-templates")
(declare-function my/denote-new-work-person             "dl-denote-templates")
(declare-function my/denote-new-work-project            "dl-denote-templates")
(declare-function my/denote-new-work-reference          "dl-denote-templates")
(declare-function my/denote-new-work-slip               "dl-denote-templates")
(declare-function my/denote-new-work-source             "dl-denote-templates")
(declare-function my/denote-promote-subtree             "dl-denote-promote")
(declare-function my/diagnostics-toggle-inline-style    "dl-diagnostics")
(declare-function my/forward-or-backward-sexp           "dl-motion")
(declare-function my/jinx-global-mode                   "dl-prose")
(declare-function my/journal-note                       "dl-denote-journal")
(declare-function my/move-file                          "dl-file-ops")
(declare-function my/next-user-buffer                   "dl-buffer-management")
(declare-function my/org-ql-find-here                   "dl-org-ql")
(declare-function my/org-ql-find-notes                  "dl-org-ql")
(declare-function my/org-ql-find-work-notes             "dl-org-ql")
(declare-function my/org-ql-search-notes                "dl-org-ql")
(declare-function my/previous-user-buffer               "dl-buffer-management")
(declare-function my/project-find-file-here             "dl-project")
(declare-function my/review-inbox                       "dl-review")
(declare-function my/review-intake                      "dl-review")
(declare-function my/review-journal-open                "dl-review")
(declare-function my/review-protocol                    "dl-review")
(declare-function my/review-queue                       "dl-review")
(declare-function my/review-recent-notes                "dl-review")
(declare-function my/review-references-retained         "dl-review")
(declare-function my/review-references-untrusted        "dl-review")
(declare-function my/review-stale                       "dl-review")
(declare-function my/review-weekly                      "dl-review")
(declare-function my/review-work-inbox                  "dl-review")
(declare-function my/review-work-intake                 "dl-review")
(declare-function my/review-work-journal-open           "dl-review")
(declare-function my/review-work-recent-notes           "dl-review")
(declare-function my/review-work-references-retained    "dl-review")
(declare-function my/review-work-references-untrusted   "dl-review")
(declare-function my/review-work-stale                  "dl-review")
(declare-function my/review-work-weekly                 "dl-review")
(declare-function my/rotate-windows                     "dl-window")
(declare-function my/rotate-windows-backward            "dl-window")
(declare-function my/tmp-buffer                         "dl-buffer-management")
(declare-function my/toggle-margins                     "dl-theme")
(declare-function my/toggle-window-dedicated            "dl-window")
(declare-function my/weekly-note                        "dl-denote-journal")
(declare-function my/window-exchange-buffer             "dl-window")
(declare-function my/work-journal-note                  "dl-denote-journal")
(declare-function my/work-weekly-note                   "dl-denote-journal")
(declare-function my/yazi-here                          "dl-dirvish")
(declare-function my/zmx-kill                           "dl-zmx")
(declare-function my/zmx-new                            "dl-zmx")
(declare-function my/zmx-new-at-root                    "dl-zmx")
(declare-function my/zmx-project                        "dl-zmx")
(declare-function my/zmx-resume                         "dl-zmx")
(declare-function my/zmx-switch                         "dl-zmx")
(declare-function olivetti-mode                         "olivetti")
(declare-function org-agenda-files                      "org")
(declare-function org-clock-goto                        "org-clock")
(declare-function org-clock-in-last                     "org-clock")
(declare-function org-clock-out                         "org-clock")
(declare-function org-insert-link-global                "ol")
(declare-function org-iw-add                            "org-iw")
(declare-function org-iw-continue                       "org-iw")
(declare-function org-iw-end-session                    "org-iw")
(declare-function org-iw-list-queue                     "org-iw")
(declare-function org-iw-move                           "org-iw")
(declare-function org-iw-remove                         "org-iw")
(declare-function org-iw-visit-next                     "org-iw")
(declare-function org-mark-ring-goto                    "org")
(declare-function org-narrow-to-subtree                 "org")
(declare-function org-refile                            "org-refile")
(declare-function org-store-link                        "ol")
(declare-function rainbow-delimiters-mode               "rainbow-delimiters")
(declare-function rainbow-mode                          "rainbow-mode")
(declare-function rg-menu                               "rg-menu")
(declare-function spacious-padding-mode                 "spacious-padding")
(declare-function split-and-follow-horizontally         "dl-window")
(declare-function split-and-follow-vertically           "dl-window")
(declare-function transpose-frame                       "transpose-frame")
(declare-function vr/query-replace                      "visual-regexp")
(declare-function vr/replace                            "visual-regexp")
(declare-function my/umbriel                            "dl-umbriel-buffer")
(declare-function my/umbriel-switch-workspace           "dl-umbriel-buffer")
(declare-function my/umbriel-set-active-layout          "dl-umbriel-buffer")
(declare-function dl-umbriel-focus-frame                "dl-umbriel-focus")


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
(defvar-keymap my-file-map              :name "file")
(defvar-keymap my-buffer-map            :name "buffer")
(defvar-keymap my-window-map            :name "window")
(defvar-keymap my-search-map            :name "search")
(defvar-keymap my-project-map           :name "project")
(defvar-keymap my-jump-map              :name "jump")
(defvar-keymap my-git-map               :name "git")
(defvar-keymap my-notes-map             :name "notes")
(defvar-keymap my-notes-new-map         :name "notes:new")
(defvar-keymap my-notes-manage-map      :name "notes:manage")
(defvar-keymap my-notes-review-map      :name "notes:review")
(defvar-keymap my-notes-work-map        :name "notes:work")
(defvar-keymap my-notes-work-review-map :name "notes:work:review")
(defvar-keymap my-roam-map              :name "roam")
(defvar-keymap my-org-map               :name "org")
(defvar-keymap my-toggle-map            :name "toggle")
(defvar-keymap my-eval-map              :name "eval")
(defvar-keymap my-term-map              :name "term")
(defvar-keymap my-fold-map              :name "fold")
(defvar-keymap my-diagnostics-map       :name "diagnostics")
(defvar-keymap my-llm-map               :name "llm")
(defvar-keymap my-org-iw-map            :name "org-iw")
(defvar-keymap my-umbriel-map           :name "umbriel")

;; Bind prefix maps globally under C-c <letter>.
(define-key global-map (kbd "C-c f") my-file-map)
(define-key global-map (kbd "C-c b") my-buffer-map)
(define-key global-map (kbd "C-c w") my-window-map)
(define-key global-map (kbd "C-c s") my-search-map)
(define-key global-map (kbd "C-c p") my-project-map)
(define-key global-map (kbd "C-c j") my-jump-map)
(define-key global-map (kbd "C-c g") my-git-map)
(define-key global-map (kbd "C-c i") my-org-iw-map)
(define-key global-map (kbd "C-c n") my-notes-map)
(define-key global-map (kbd "C-c o") my-org-map)
(define-key global-map (kbd "C-c t") my-toggle-map)
(define-key global-map (kbd "C-c e") my-eval-map)
(define-key global-map (kbd "C-c m") my-term-map)
(define-key global-map (kbd "C-c z") my-fold-map)
(define-key global-map (kbd "C-c d") my-diagnostics-map)
(define-key global-map (kbd "C-c L") my-llm-map)
(define-key global-map (kbd "C-c u") my-umbriel-map)

;; Prefix labels for which-key.
(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "C-c L"   "llm"
    "C-c a"   "toggle"
    "C-c b"   "buffer"
    "C-c d"   "diagnostics"
    "C-c e"   "eval"
    "C-c f"   "file"
    "C-c g"   "git"
    "C-c j"   "jump"
    "C-c n N"   "notes:new"
    "C-c n W v" "notes:work:review"
    "C-c n W"   "notes:work"
    "C-c n m"   "notes:manage"
    "C-c n r"   "roam"
    "C-c n v"   "notes:review"
    "C-c n"   "notes"
    "C-c o"   "org"
    "C-c p"   "project"
    "C-c s"   "search"
    "C-c t"   "term"
    "C-c u"   "umbriel"
    "C-c w"   "window"
    "C-c z"   "fold"
    ))

(declare-function  hydra-window-resize/body "dl-keybind")

;;        File
(my/bind  my-file-map   "f" #'my/project-find-file-here "find-file infer proj")
(my/bind  my-file-map   "F" #'find-file              "find-file")
(my/bind  my-file-map   "s" #'save-buffer            "save")
(my/bind  my-file-map   "S" #'write-file             "save-as")
(my/bind  my-file-map   "r" #'consult-recent-file    "recent")
(my/bind  my-file-map   "d" #'dired-jump             "dired-jump")
(my/bind  my-file-map   "D" #'dirvish                "dirvish")
(my/bind  my-file-map   "t" #'dirvish-side           "dirvish-side (tree)")
(my/bind  my-file-map   "o" #'crux-open-with         "open external")
(my/bind  my-file-map   "p" #'crux-kill-buffer-truename "copy path (true)")
(my/bind  my-file-map   "y" #'my/yazi-here           "yazi")
(my/bind  my-file-map   "b" #'my/broot-here          "broot")
(my/bind  my-file-map   "K" #'my/delete-current-buffer-file "delete file + buffer")
(my/bind  my-file-map   "M" #'my/move-file           "move file")

;;        Project
(my/bind  my-buffer-map "b" #'consult-buffer         "switch")
(my/bind  my-buffer-map "k" #'kill-current-buffer    "kill")
(my/bind  my-buffer-map "i" #'ibuffer                "ibuffer")
(my/bind  my-buffer-map "n" #'my/next-user-buffer    "next (skip *…* / dired)")
(my/bind  my-buffer-map "p" #'my/previous-user-buffer "prev (skip *…* / dired)")
(my/bind  my-buffer-map "t" #'my/tmp-buffer          "tmp buffer (same mode)")

;;        Window
(my/bind my-window-map "<left>" #'windmove-left "left")
(my/bind my-window-map "<down>" #'windmove-down "down")
(my/bind my-window-map "<up>" #'windmove-up "up")
(my/bind my-window-map "<right>" #'windmove-right "right")
(my/bind my-window-map "s" #'split-and-follow-horizontally "split-below (+focus)")
(my/bind my-window-map "v" #'split-and-follow-vertically "split-right (+focus)")
(my/bind my-window-map "S" #'split-window-below "split-below (no focus)")
(my/bind my-window-map "V" #'split-window-right "split-right (no focus)")
(my/bind my-window-map "o" #'delete-other-windows "only")
(my/bind my-window-map "d" #'delete-window "delete")
(my/bind my-window-map "=" #'balance-windows "balance")
(my/bind my-window-map "r" #'hydra-window-resize/body "resize (hydra)")
(my/bind my-window-map "f" #'transpose-frame "transpose h ⇄ v")
(my/bind my-window-map "c" #'my/rotate-windows "cycle (rotate)")
(my/bind my-window-map "C" #'my/rotate-windows-backward "cycle back")
(my/bind my-window-map "x" #'my/window-exchange-buffer "exchange buffer (ace)")
(my/bind my-window-map "P" #'my/toggle-window-dedicated "pin (dedicated)")

;;        Git
(my/bind  my-git-map "g"       #'magit-status           "status")
(my/bind  my-git-map "l"       #'git-link               "link")

;; Project family — parallel to C-c f, project.el-aligned letters so
;; muscle memory survives between C-x p and C-c p.
(my/bind my-project-map "!" #'project-shell-command           "shell-command")
(my/bind my-project-map "D" #'project-find-dir                "find dir")
(my/bind my-project-map "b" #'project-switch-to-buffer        "switch buffer")
(my/bind my-project-map "c" #'project-compile                 "compile")
(my/bind my-project-map "d" #'project-dired                   "dired")
(my/bind my-project-map "e" #'project-eshell                  "eshell")
(my/bind my-project-map "f" #'project-find-file               "find file")
(my/bind my-project-map "g" #'project-find-regexp             "grep (xref)")
(my/bind my-project-map "k" #'project-kill-buffers            "kill buffers")
(my/bind my-project-map "p" #'project-switch-project          "switch project")
(my/bind my-project-map "r" #'project-query-replace-regexp    "query-replace")
(my/bind my-project-map "s" #'project-shell                   "shell")
(my/bind my-project-map "v" #'project-vc-dir                  "vc-dir")

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
(my/bind my-search-map  "d" #'consult-fd                         "fd filenames")
(my/bind my-search-map  "f" #'consult-find                       "find(1) filenames")
(my/bind my-search-map  "m" #'consult-mark                       "mark ring")
(my/bind my-search-map  "M" #'consult-global-mark                "global mark ring")
(my/bind my-search-map  "g" #'rg-menu                            "rg menu")
(my/bind my-search-map  "q" #'vr/query-replace                   "vr query-replace")
(my/bind my-search-map  "Q" #'vr/replace                         "vr replace")

;; Jump map — avy family.  Chord bindings `C-:'/`C-'' live in
;; `editing/dl-motion.el' as fast escape hatches.
(my/bind my-jump-map    "j" #'avy-goto-line          "line")
(my/bind my-jump-map    "c" #'avy-goto-char-timer    "char (timer)")
(my/bind my-jump-map    "2" #'avy-goto-char-2        "2-char")
(my/bind my-jump-map    "w" #'avy-goto-word-1        "word")
(my/bind my-jump-map    "p" #'my/forward-or-backward-sexp "match paren")
(my/bind my-jump-map    "l" #'dogears-go             "jump list")
(my/bind my-jump-map    "L" #'dogears-sidebar        "jump list sidebar")

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

;; Diagnostics map — Flymake (dev/dl-diagnostics.el).  Lowercase is the
;; buffer, uppercase the project.
(my/bind my-diagnostics-map "d" #'consult-flymake                   "search (buffer)")
(my/bind my-diagnostics-map "D" #'my/consult-flymake-project        "search (project)")
(my/bind my-diagnostics-map "l" #'flymake-show-buffer-diagnostics   "list (buffer)")
(my/bind my-diagnostics-map "L" #'flymake-show-project-diagnostics  "list (project)")
(my/bind my-diagnostics-map "<down>" #'flymake-goto-next-error      "next")
(my/bind my-diagnostics-map "<up>"   #'flymake-goto-prev-error      "previous")
(my/bind my-diagnostics-map "i" #'my/diagnostics-toggle-inline-style "inline: flyover / fancy")
(my/bind my-diagnostics-map "b" #'flymake-running-backends          "running backends")
(my/bind my-diagnostics-map "B" #'flymake-switch-to-log-buffer      "log")

;; LLM map — gptel (apps/dl-gptel.el).
(my/bind my-llm-map "l" #'gptel           "chat")
(my/bind my-llm-map "s" #'gptel-send      "send")
(my/bind my-llm-map "m" #'gptel-menu      "menu")
(my/bind my-llm-map "k" #'gptel-abort     "abort")
(my/bind my-llm-map "i" #'gptel-inline    "ask inline")
(my/bind my-llm-map "r" #'gptel-rewrite   "rewrite region")
(my/bind my-llm-map "a" #'gptel-add       "add to context")
(my/bind my-llm-map "f" #'gptel-add-file  "add file to context")
(my/bind my-llm-map "n" #'gptel-annotate  "annotate (Flymake notes)")
(my/bind my-llm-map "A" #'gptel-agent     "agent")

;; Org map — cross-buffer entry points only.  In-buffer Org commands stay
;; at Org's own `C-c C-<x>' (mode-specific space, Org owns it).
;; TRIAL: Do i really need these at C-c _ ?
(my/bind my-org-map     "a" #'org-agenda                      "agenda")
(my/bind my-org-map     "c" #'org-capture                     "capture")
(my/bind my-org-map     "a" #'org-store-link                  "store-link")

(my/bind my-org-map     "h" #'consult-org-heading         "heading (buffer)")
(my/bind my-org-map     "H" (lambda () (interactive)
                              (consult-org-heading nil (org-agenda-files))) "heading (agenda)")
(my/bind my-org-map     "j" #'org-clock-goto              "clock goto")
(my/bind my-org-map     "i" #'org-clock-in-last           "clock-in last")
(my/bind my-org-map     "O" #'org-clock-out               "clock-out")
(my/bind my-org-map     "r" #'org-refile                  "refile")
(my/bind my-org-map     "q" #'my/org-ql-find-here         "query (buffer)")
(my/bind my-org-map     "b" #'org-switchb                 "switch org buffer")
(my/bind my-org-map     "L" #'org-insert-link-global      "insert link (global)")


;; org-incremental-writing
(my/bind my-org-iw-map "a" #'org-iw-add         "org-iw-add")
(my/bind my-org-iw-map "v" #'org-iw-visit-next  "org-iw-visit-next")
(my/bind my-org-iw-map "c" #'org-iw-continue    "org-iw-continue")
(my/bind my-org-iw-map "q" #'org-iw-end-session "org-iw-end-session")
(my/bind my-org-iw-map "m" #'org-iw-move        "org-iw-move")
(my/bind my-org-iw-map "r" #'org-iw-remove      "org-iw-remove")
(my/bind my-org-iw-map "l" #'org-iw-list-queue  "org-iw-list-queue")

;; Notes (C-c n …) — see plan §4b in ~/.claude/plans/yes-use-dl-for-staged-quiche.md.
;; Sub-prefixes for new-by-class / manage / review live below.
;;
;; Phase 5 commands (`consult-notes') aren't installed yet —
;; binding by symbol is fine, the void-function error surfaces only if
;; pressed before Phase 5 lands.  `declare-function' silences the
;; byte-compiler "not known to be defined" warnings until then.
(declare-function consult-notes                     "consult-notes")
(declare-function consult-notes-search-in-all-notes "consult-notes")
(declare-function org-ql-view                       "org-ql-view")
(declare-function org-roam-node-find                "org-roam-node")
(declare-function org-roam-node-insert              "org-roam-node")
(declare-function org-roam-buffer-toggle            "org-roam-mode")
(declare-function org-roam-capture                  "org-roam-capture")
(declare-function org-roam-db-sync                  "org-roam-db")
(declare-function org-roam-graph                    "org-roam-graph")

;; NOTES
(my/bind my-notes-map "N" my-notes-new-map    "new-by-class")
(my/bind my-notes-map "m" my-notes-manage-map "manage")
(my/bind my-notes-map "v" my-notes-review-map "review")
(my/bind my-notes-map "c" #'org-capture                       "capture")
(my/bind my-notes-map "j" #'my/journal-note                   "journal today")
(my/bind my-notes-map "w" #'my/weekly-note                    "weekly")
(my/bind my-notes-map "n" #'denote                            "new note")
(my/bind my-notes-map "p" #'my/denote-promote-subtree         "promote subtree")
(my/bind my-notes-map "f" #'consult-notes                     "find note (Phase 5)")
(my/bind my-notes-map "s" #'consult-notes-search-in-all-notes "search notes (Phase 5)")
(my/bind my-notes-map "l" #'org-store-link                    "store link")
(my/bind my-notes-map "L" #'my/denote-kill-link-to-current-file "kill denote link")
(my/bind my-notes-map "i" #'denote-link                       "insert link")
(my/bind my-notes-map "o" #'org-open-at-point-global          "open link")
(my/bind my-notes-map "g" #'org-mark-ring-goto                "go back")
(my/bind my-notes-map "b" #'denote-backlinks                  "backlinks")
(my/bind my-notes-map "q" #'my/org-ql-find-notes              "query: find")
(my/bind my-notes-map "Q" #'my/org-ql-search-notes            "query: results")
(my/bind my-notes-map "V" #'org-ql-view                       "query: saved views")

;; Notes > New
(my/bind my-notes-new-map "p" #'my/denote-new-project    "project")
(my/bind my-notes-new-map "a" #'my/denote-new-area       "area")
(my/bind my-notes-new-map "s" #'my/denote-new-source     "source")
(my/bind my-notes-new-map "S" #'my/denote-new-slip       "slip")
(my/bind my-notes-new-map "r" #'my/denote-new-reference          "reference")
(my/bind my-notes-new-map "R" #'my/denote-new-reference-markdown "reference (md)")
(my/bind my-notes-new-map "i" #'my/denote-new-index      "index")
(my/bind my-notes-new-map "b" #'my/denote-new-blog-entry "blog entry")
(my/bind my-notes-new-map "j" #'my/journal-note          "journal today")
(my/bind my-notes-new-map "w" #'my/weekly-note           "weekly")

;; Notes > Manage
(my/bind my-notes-manage-map "b" #'my/bough-export-org                    "bough export org")
(my/bind my-notes-manage-map "B" #'my/bough-export-denote                 "bough export denote")
(my/bind my-notes-manage-map "r" #'denote-rename-file                     "rename")
(my/bind my-notes-manage-map "R" #'denote-rename-file-using-front-matter  "rename (front-matter)")
(my/bind my-notes-manage-map "k" #'denote-rename-file-keywords            "edit keywords")
(my/bind my-notes-manage-map "t" #'denote-rename-file-title               "retitle")

;; Notes > Review
(my/bind my-notes-review-map "q" #'my/review-queue                  "review queue")
(my/bind my-notes-review-map "i" #'my/review-inbox                  "inbox")
(my/bind my-notes-review-map "I" #'my/review-intake                 "intake (dired)")
(my/bind my-notes-review-map "j" #'my/review-journal-open           "journal open items")
(my/bind my-notes-review-map "p" #'my/review-protocol               "protocol inbox")
(my/bind my-notes-review-map "n" #'my/review-recent-notes           "recent notes")
(my/bind my-notes-review-map "w" #'my/review-weekly                 "weekly + waiting")
(my/bind my-notes-review-map "s" #'my/review-stale                  "stale waiting")
(my/bind my-notes-review-map "r" #'my/review-references-retained    "refs: raw")
(my/bind my-notes-review-map "u" #'my/review-references-untrusted   "refs: untrusted")

;; Work compartment — `C-c n W …'.  Constructors live directly under `W',
;; reviews under `W v', so personal namespaces stay clean.
(my/bind my-notes-map      "W" my-notes-work-map        "work")
(my/bind my-notes-work-map "v" my-notes-work-review-map "review")

(defvar dl-notes-work-file)
(defvar dl-notes-work-inbox-file)
(defvar dl-notes-work-intake-dir)

(my/bind my-notes-work-map "h" (lambda () (interactive) (find-file dl-notes-work-file))       "open work.org")
(my/bind my-notes-work-map "i" (lambda () (interactive) (find-file dl-notes-work-inbox-file)) "work inbox")
(my/bind my-notes-work-map "I" (lambda () (interactive) (dired dl-notes-work-intake-dir))    "work intake")
(my/bind my-notes-work-map "j" #'my/work-journal-note  "work journal")
(my/bind my-notes-work-map "w" #'my/work-weekly-note   "work weekly")
(my/bind my-notes-work-map "q" #'my/org-ql-find-work-notes "work query")
(my/bind my-notes-work-map "p" #'my/denote-new-work-project   "new work project")
(my/bind my-notes-work-map "a" #'my/denote-new-work-area      "new work area")
(my/bind my-notes-work-map "m" #'my/denote-new-work-meeting   "new work meeting")
(my/bind my-notes-work-map "P" #'my/denote-new-work-person    "new work person")
(my/bind my-notes-work-map "s" #'my/denote-new-work-source    "new work source")
(my/bind my-notes-work-map "S" #'my/denote-new-work-slip      "new work slip")
(my/bind my-notes-work-map "r" #'my/denote-new-work-reference "new work reference")
(my/bind my-notes-work-map "x" #'my/denote-new-work-index     "new work index")

;; Notes > Work Review
(my/bind my-notes-work-review-map "i" #'my/review-work-inbox                "inbox")
(my/bind my-notes-work-review-map "I" #'my/review-work-intake               "intake")
(my/bind my-notes-work-review-map "j" #'my/review-work-journal-open         "journal open items")
(my/bind my-notes-work-review-map "n" #'my/review-work-recent-notes         "recent notes")
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

;; Term map
(my/bind my-term-map   "t" #'my/zmx-resume                     "zmx resume")
(my/bind my-term-map   "T" #'my/zmx-new                        "zmx (new, here)")
(my/bind my-term-map   "o" #'my/zmx-new-at-root                "zmx (new, project)")
(my/bind my-term-map   "n" #'ghostel-other                     "ghostel-next")
(my/bind my-term-map   "z" #'my/zmx-project                    "zmx project")
(my/bind my-term-map   "Z" #'my/zmx-switch                     "zmx switch")
(my/bind my-term-map   "k" #'my/zmx-kill                       "zmx kill")
(my/bind my-term-map   "b" #'consult-ghostel                   "pick terminal")
(my/bind my-term-map   "a" #'consult-ghostel-status            "needs attention")

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
(my/bind my-toggle-map "o" #'olivetti-mode                    "olivetti")
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

;; Umbriel map — the compositor (apps/dl-umbriel-buffer.el, dl-umbriel-focus.el).

(my/bind my-umbriel-map "u" #'my/umbriel                   "buffer")
(my/bind my-umbriel-map "w" #'my/umbriel-switch-workspace  "switch workspace")
(my/bind my-umbriel-map "l" #'my/umbriel-set-active-layout "set layout (active)")
(my/bind my-umbriel-map "f" #'dl-umbriel-focus-frame       "focus frame")

;; Other
;; C-. goto last change
;; C-; iedit-mode

(provide 'dl-keymap)
;;; dl-keymap.el ends here
