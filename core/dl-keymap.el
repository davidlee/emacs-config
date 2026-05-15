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
;;   C-c o / SPC o   org / open
;;   C-c t / SPC t   toggle
;;   C-c e / SPC e   eval / elisp
;;   C-c g / SPC G   git    (capital in Meow: SPC g is keypad C-M- prefix)
;;   C-c m / SPC M   term   (capital in Meow: SPC m is keypad M- prefix)
;;
;; Add new bindings with `my/bind' so each carries a which-key label and
;; a collision warning.

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
(defvar-keymap my-file-map   :name "file")
(defvar-keymap my-buffer-map :name "buffer")
(defvar-keymap my-window-map :name "window")
(defvar-keymap my-search-map :name "search")
(defvar-keymap my-git-map    :name "git")
(defvar-keymap my-org-map    :name "org")
(defvar-keymap my-toggle-map :name "toggle")
(defvar-keymap my-eval-map   :name "eval")
(defvar-keymap my-term-map   :name "term")

;; Bind prefix maps globally under C-c <letter>.
(define-key global-map (kbd "C-c f") my-file-map)
(define-key global-map (kbd "C-c b") my-buffer-map)
(define-key global-map (kbd "C-c w") my-window-map)
(define-key global-map (kbd "C-c s") my-search-map)
(define-key global-map (kbd "C-c g") my-git-map)
(define-key global-map (kbd "C-c o") my-org-map)
(define-key global-map (kbd "C-c t") my-toggle-map)
(define-key global-map (kbd "C-c e") my-eval-map)
(define-key global-map (kbd "C-c m") my-term-map)

;; Prefix labels for which-key.
(with-eval-after-load 'which-key
  (which-key-add-key-based-replacements
    "C-c f" "file"
    "C-c b" "buffer"
    "C-c w" "window"
    "C-c s" "search"
    "C-c g" "git"
    "C-c o" "org"
    "C-c t" "toggle"
    "C-c e" "eval"
    "C-c m" "term"))

;; Concrete bindings -- starter set, grow as needed.
(my/bind my-file-map   "f" #'find-file              "find-file")
(my/bind my-file-map   "s" #'save-buffer            "save")
(my/bind my-file-map   "S" #'write-file             "save-as")
(my/bind my-file-map   "r" #'consult-recent-file    "recent")

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

(my/bind my-term-map   "t" #'multi-vterm                       "vterm")
(my/bind my-term-map   "n" #'multi-vterm-next                  "vterm-next")
(my/bind my-term-map   "P" #'multi-vterm-prev                  "vterm-prev")
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
    (cons "G" my-git-map)
    (cons "o" my-org-map)
    (cons "t" my-toggle-map)
    (cons "e" my-eval-map)
    (cons "M" my-term-map))

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
    '("h" . meow-left)
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
