;;; dl-meow-cheatsheet.el --- Gallium-Corne meow cheatsheet -*- lexical-binding: t; -*-

(require 'meow)

(defvar my/meow-cheatsheet-labels
  '((meow-insert . "insert")
    (meow-append . "append")
    (meow-open-above . "open↑")
    (meow-open-below . "open↓")
    (meow-kill . "kill")
    (meow-save . "copy")
    (meow-yank . "paste")
    (meow-change . "change")
    (meow-delete . "delete")
    (meow-backward-delete . "del←")
    (meow-replace . "replce")
    (meow-swap-grab . "swap")
    (meow-undo . "undo")
    (meow-undo-in-selection . "undo-in")
    (meow-search . "search")
    (meow-find . "find")
    (meow-find-expand . "find+")
    (meow-till . "till")
    (meow-back-word . "←word")
    (meow-back-symbol . "←sym")
    (meow-next-word . "word→")
    (meow-next-symbol . "sym→")
    (meow-mark-word . "word")
    (meow-mark-symbol . "sym")
    (meow-line . "line")
    (meow-goto-line . "go-ln")
    (meow-block . "block")
    (meow-to-block . "→blk")
    (meow-inner-of-thing . "inner")
    (meow-bounds-of-thing . "bounds")
    (meow-beginning-of-thing . "beg")
    (meow-end-of-thing . "end")
    (meow-cancel-selection . "cancel")
    (meow-grab . "grab")
    (meow-sync-grab . "sync")
    (meow-join . "join")
    (meow-visit . "visit")
    (meow-pop-selection . "pop")
    (meow-reverse . "revrse")
    (meow-quit . "quit")
    (repeat . "repeat")
    (ignore . nil)
    (negative-argument . "neg")
    (consult-buffer . "buf-sw")
    (my/forward-or-backward-sexp . "sexp")))

(defconst my/meow--cell-width 7)

(defconst my/meow--gallium-left
  '((("b" . "B") ("l" . "L") ("d" . "D") ("c" . "C") ("v" . "V"))
    (("n" . "N") ("r" . "R") ("t" . "T") ("s" . "S") ("g" . "G"))
    (("x" . "X") ("q" . "Q") ("m" . "M") ("w" . "W") ("z" . "Z"))))

(defconst my/meow--gallium-right
  '((("j" . "J") ("y" . "Y") ("o" . "O") ("u" . "U") ("," . nil))
    (("p" . "P") ("h" . "H") ("a" . "A") ("e" . "E") ("i" . "I"))
    (("k" . "K") ("f" . "F") ("'" . nil) (";" . nil) ("." . nil))))

(defun my/meow-command-label (key)
  "Return a short display label for KEY in normal state.
Returns nil for unbound keys or commands mapped to nil in the label alist."
  (when key
    (let ((cmd (lookup-key meow-normal-state-keymap (kbd key))))
      (cond
       ((null cmd) nil)
       ((keymapp cmd) "C-c")
       ((and (symbolp cmd) (assq cmd my/meow-cheatsheet-labels))
        (alist-get cmd my/meow-cheatsheet-labels))
       ((symbolp cmd)
        (let ((name (symbol-name cmd)))
          (replace-regexp-in-string "\\`meow-" "" name)))
       (t nil)))))

(defun my/meow--pad (str &optional face)
  "Pad or truncate STR to cell width, optionally applying FACE."
  (let* ((s (or str ""))
         (w my/meow--cell-width)
         (padded (if (> (length s) w)
                     (substring s 0 w)
                   (concat s (make-string (- w (length s)) ?\s)))))
    (if face (propertize padded 'face face) padded)))

(defun my/meow--cell (key shift-key)
  "Return a 3-element list of padded strings for KEY and SHIFT-KEY.
Line 1: key (highlighted).  Line 2: command label.  Line 3: shifted label (dim)."
  (let ((label (my/meow-command-label key))
        (s-label (when shift-key (my/meow-command-label shift-key))))
    (list
     (my/meow--pad key 'meow-cheatsheet-highlight)
     (my/meow--pad (or label "·")
                   (if label 'meow-cheatsheet-command 'shadow))
     (my/meow--pad (or s-label "")
                   'shadow))))

(defun my/meow--render-row (keys)
  "Render KEYS (list of (key . shift) pairs) as 3 lines with │ separators."
  (let ((cells (mapcar (lambda (k) (my/meow--cell (car k) (cdr k))) keys)))
    (list
     (concat "│ " (mapconcat (lambda (c) (nth 0 c)) cells " │ ") " │")
     (concat "│ " (mapconcat (lambda (c) (nth 1 c)) cells " │ ") " │")
     (concat "│ " (mapconcat (lambda (c) (nth 2 c)) cells " │ ") " │"))))

(defun my/meow--hline (l m r)
  "Horizontal separator with box chars L (left), M (mid), R (right)."
  (let ((seg (make-string (+ my/meow--cell-width 2) ?─)))
    (concat (string l)
            (string-join (make-list 5 seg) (string m))
            (string r))))

(defun my/meow-gallium-cheatsheet ()
  "Show a Meow cheatsheet arranged for the Gallium-Corne layout."
  (interactive)
  (let ((buf (get-buffer-create "*Meow Gallium*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (propertize "Meow · Gallium on Corne\n"
                            'face '(:weight bold :height 1.2)))
        (insert "\n")
        (let ((top (my/meow--hline ?┌ ?┬ ?┐))
              (mid (my/meow--hline ?├ ?┼ ?┤))
              (bot (my/meow--hline ?└ ?┴ ?┘))
              (gap "  "))
          (insert "LEFT HAND"
                  (make-string (- (length top) 9) ?\s)
                  gap "RIGHT HAND\n")
          (cl-loop
           for left-row in my/meow--gallium-left
           for right-row in my/meow--gallium-right
           for i from 0
           do
           (let ((l (my/meow--render-row left-row))
                 (r (my/meow--render-row right-row)))
             (insert (if (= i 0) top mid) gap
                     (if (= i 0) top mid) "\n")
             (dotimes (j 3)
               (insert (nth j l) gap (nth j r) "\n"))))
          (insert bot gap bot "\n")
          (insert (make-string 17 ?\s)
                  "Fn     SPC     Ctl"
                  (make-string 12 ?\s)
                  "NAV     BS      ·\n"))
        (insert "\n")
        (insert (propertize "Motion" 'face '(:weight bold))
                " (NAV → arrows)\n")
        (insert "  ←→↑↓  char/line    S-‹arrow›  expand\n")
        (insert "  C-←/→  word         M-←/→      symbol\n")
        (insert "  h/e    ←word/word→  H/E        ←sym/sym→\n")
        (insert "\n")
        (insert (propertize "Leader" 'face '(:weight bold))
                " (SPC)\n")
        (insert "  f:file  b:buf  w:win  s:srch  p:proj  j:jump  G:git\n")
        (insert "  n:notes  o:org  t:tog  e:eval  M:term  z:fold\n")
        (insert "\n")
        (insert (propertize "Extras" 'face '(:weight bold)) "\n")
        (insert "  !:buf-switch  %:sexp  ':repeat  ;:reverse\n")
        (insert "  ,:inner  .:bounds  [:beg  ]:end  -:neg-arg\n")
        (goto-char (point-min))
        (special-mode)))
    (pop-to-buffer buf)))

(meow-leader-define-key
  '("?" . my/meow-gallium-cheatsheet))

(provide 'dl-meow-cheatsheet)
;;; dl-meow-cheatsheet.el ends here
