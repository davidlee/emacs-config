;;; dl-meow-map.el --- meow key mapping -*- lexical-binding: t; -*-

(require 'dl-keymap)


;; Gallium alpha positions → meow-normal bindings
;; b:block l:line  d:del  c:chg  v:visit    j:join y:save  o:C-c  u:undo ,:thing
;; n:srch  r:repl  t:till s:—    g:cancel   p:yank h:←word a:appd e:word→ i:ins
;; x:grow  q:quit  m:surr w:mark z:pop      k:—    f:find  ':rpt  ;:rev  .:thing
;; X:shrink  >/<:indent  U:redo  C-o/C-S-o:jump back/forward (dogears)
;; m:surround (s/d/r)  #:comment  =:reindent  ~/`:up/downcase  P:paste-pick
;; T:till+  ^/$:line start(text)/end  C:change to EOL

(declare-function meow-kill "meow-command")
(declare-function meow-delete "meow-command")
(declare-function meow-change "meow-command")
(declare-function meow--select "meow-util")
(declare-function meow--make-selection "meow-util")
(declare-function meow-normal-define-key "meow-helpers")
(declare-function meow-leader-define-key "meow-helpers")
(declare-function meow-motion-define-key "meow-helpers")

(defvar meow-cheatsheet-layout)
(defvar meow-cheatsheet-layout-qwerty)
(defvar meow-char-thing-table)

(defun my/meow-delete-dwim ()
  "Cut the active selection, or delete one character forward."
  (interactive)
  (if (region-active-p)
      (meow-kill)
    (meow-delete)))

(defun my/meow-select-to-line-end ()
  "Extend the selection's right edge to the logical line end."
  (interactive)
  (let* ((beg (if (region-active-p) (region-beginning) (point)))
         (right (if (region-active-p) (region-end) (point)))
         (end (save-excursion
                (goto-char right)
                (line-end-position))))
    (meow--select (meow--make-selection '(select . transient) beg end) t)))

(defun my/meow-change-to-line-end ()
  "Change to the line end: `D' then `c'."
  (interactive)
  (my/meow-select-to-line-end)
  (meow-change))

;; Prefix keys replay as input rather than bind a keymap object: binding
;; `mode-specific-map' reaches only global C-c keys, missing mode-local
;; ones such as outline's C-c @ or org's C-c '.
(defun my/meow--replay (keys)
  "Feed KEYS back as input, so the keys after them see every active map.
Each event is wrapped as (t . EVENT) so it is recorded in
`this-command-keys': otherwise only the first lands there, and the echo
area and which-key show C-c instead of C-c @."
  (setq unread-command-events
        (mapcar (lambda (event) (cons t event))
                (listify-key-sequence (kbd keys)))))

(defun my/meow-ctrl-c ()
  "Act as \\`C-c'."
  (interactive)
  (my/meow--replay "C-c"))

(defun my/meow-outline-prefix ()
  "Act as \\`C-c @', the `outline-minor-mode' prefix."
  (interactive)
  (my/meow--replay "C-c @"))

;; Line-wise edits (> < = #) share one notion of "the selected lines".
;; Not meow's own: with no selection `meow-indent' (C-M-\) reindents
;; from point to a possibly stale mark, and `meow-comment' (M-;
;; `comment-dwim') appends an end-of-line comment instead of toggling.
(defun my/meow--line-range ()
  "Return (BEG . END) spanning the lines the selection touches.
Without a selection, the current line.  A selection ending at a line
start (linewise) excludes that line."
  (let* ((active (region-active-p))
         (beg (if active (region-beginning) (point)))
         (end (if active (region-end) (point))))
    (cons (save-excursion (goto-char beg) (line-beginning-position))
          (save-excursion
            (goto-char end)
            (when (and (bolp) (> end beg)) (backward-char))
            (line-end-position)))))

(defun my/meow--edit-lines (edit &rest args)
  "Call EDIT with the selected lines' bounds and ARGS, keeping the selection
active so the command can repeat."
  (pcase-let ((`(,beg . ,end) (my/meow--line-range)))
    (apply edit beg end args))
  (setq deactivate-mark nil))

(defun my/meow-indent-right (n)
  "Shift selected lines right by N times `standard-indent'."
  (interactive "p")
  (my/meow--edit-lines #'indent-rigidly (* n standard-indent)))

(defun my/meow-indent-left (n)
  "Shift selected lines left by N times `standard-indent'."
  (interactive "p")
  (my/meow--edit-lines #'indent-rigidly (* (- n) standard-indent)))

(defun my/meow-comment-lines ()
  "Toggle comments on the selected lines."
  (interactive)
  (my/meow--edit-lines #'comment-or-uncomment-region))

(defun my/meow-reindent-lines ()
  "Reindent the selected lines per the major mode."
  (interactive)
  (my/meow--edit-lines #'indent-region))

;; Case.  Not `upcase-dwim': without a region it acts from point to
;; the word's end, so mid-word it changes only the tail.
(defun my/meow--change-case (change-region)
  "Apply CHANGE-REGION to the selection, else the whole word at point.
Point and the selection are kept."
  (pcase-let ((`(,beg . ,end)
               (if (region-active-p)
                   (cons (region-beginning) (region-end))
                 (or (bounds-of-thing-at-point 'word)
                     (user-error "No word at point")))))
    (funcall change-region beg end))
  (setq deactivate-mark nil))

(defun my/meow-upcase ()
  "Upcase the selection, else the word at point."
  (interactive)
  (my/meow--change-case #'upcase-region))

(defun my/meow-downcase ()
  "Downcase the selection, else the word at point."
  (interactive)
  (my/meow--change-case #'downcase-region))

;; Surround (Helix `ms' / `md' / `mr'), selection-first: select the
;; inner text (e.g. `, (' or `, "'), then edit the flanking delimiters.
(defconst my/meow-surround-things
  '((round  ?\( . ?\))
    (square ?\[ . ?\])
    (curly  ?\{ . ?\})
    (angle  ?\< . ?\>)
    (string ?\" . ?\"))
  "Delimiter pairs by meow thing.  Any other character pairs with itself.")

(defun my/meow--surround-pair (char)
  "Return (OPEN . CLOSE) for CHAR, which may be either delimiter."
  (let ((pairs (mapcar #'cdr my/meow-surround-things)))
    (or (assq char pairs)
        (rassq char pairs)
        (cons char char))))

(defun my/meow--surround-input-pair (char)
  "Like `my/meow--surround-pair', but CHAR may also be a thing letter.
Letters come from `meow-char-thing-table', as `,' / `.' read them
\(r → (), c → {}, ...)."
  (or (alist-get (alist-get char meow-char-thing-table)
                 my/meow-surround-things)
      (my/meow--surround-pair char)))

(defun my/meow--surround-bounds ()
  "Return the selection's (BEG . END) when a delimiter pair flanks it."
  (unless (region-active-p)
    (user-error "Select the text inside the delimiters first"))
  (let ((beg (region-beginning))
        (end (region-end)))
    (unless (and (> beg (point-min))
                 (< end (point-max))
                 (equal (my/meow--surround-pair (char-before beg))
                        (cons (char-before beg) (char-after end))))
      (user-error "Selection is not inside a delimiter pair"))
    (cons beg end)))

(defun my/meow-surround (char)
  "Wrap the selection in the delimiter pair for CHAR (or thing letter).
The selection stays on the content.  Without one, insert the pair
with point inside."
  (interactive "cSurround with: ")
  (pcase-let ((`(,open . ,close) (my/meow--surround-input-pair char))
              (beg (if (region-active-p) (region-beginning) (point)))
              (end (if (region-active-p) (region-end) (point))))
    (save-excursion
      (goto-char end)
      (insert close)
      (goto-char beg)
      ;; Markers at BEG (mark or point) move past OPEN onto the content.
      (insert-before-markers open)))
  (setq deactivate-mark nil))

(defun my/meow-surround-delete ()
  "Delete the delimiter pair around the selection."
  (interactive)
  (pcase-let ((`(,beg . ,end) (my/meow--surround-bounds)))
    (delete-region end (1+ end))
    (delete-region (1- beg) beg))
  (setq deactivate-mark nil))

(defun my/meow-surround-replace (char)
  "Replace the delimiter pair around the selection with CHAR's pair."
  (interactive "cReplace surround with: ")
  (pcase-let ((`(,beg . ,end) (my/meow--surround-bounds))
              (`(,open . ,close) (my/meow--surround-input-pair char)))
    ;; In place, so the selection's markers stay put.
    (subst-char-in-region end (1+ end) (char-after end) close)
    (subst-char-in-region (1- beg) beg (char-before beg) open))
  (setq deactivate-mark nil))

(defvar my-surround-map
  (define-keymap
    "s" #'my/meow-surround
    "d" #'my/meow-surround-delete
    "r" #'my/meow-surround-replace)
  "Meow normal `m': surround the selection.")

;; Binding tables read as bodies: indent two columns, not under the call.
(dolist (fn '(meow-motion-define-key meow-leader-define-key meow-normal-define-key
                                     which-key-add-key-based-replacements))
  (function-put fn 'lisp-indent-function 0))

(defun meow-setup ()
  (setq meow-cheatsheet-layout meow-cheatsheet-layout-qwerty)

  (meow-motion-define-key
    '("<left>"    . meow-left)
    '("<right>"   . meow-right)
    '("<up>"      . meow-prev)
    '("<down>"    . meow-next)
    '("S-<left>"  . meow-left-expand)
    '("S-<right>" . meow-right-expand)
    '("S-<up>"    . meow-prev-expand)
    '("S-<down>"  . meow-next-expand)

    '("!" . consult-buffer)
    '("/" . avy-goto-char-2)
    '("o" . my/meow-ctrl-c)

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
    ;; SPC ? → my/meow-gallium-cheatsheet (bound in dl-meow-cheatsheet.el)
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
    (cons "z" my-fold-map)
    (cons "d" my-diagnostics-map)
    (cons "L" my-llm-map)
    (cons "u" my-umbriel-map))

  (meow-normal-define-key
    ;; Numeric expansion.
    '("0" . meow-expand-0)
    '("1" . meow-expand-1)
    '("2" . meow-expand-2)
    '("3" . meow-expand-3)
    '("4" . meow-expand-4)
    '("5" . meow-expand-5)
    '("6" . meow-expand-6)
    '("7" . meow-expand-7)
    '("8" . meow-expand-8)
    '("9" . meow-expand-9)
    '("-" . negative-argument)

    ;; Arrow-native movement (NAV layer / joystick).
    '("<left>"    . meow-left)
    '("<right>"   . meow-right)
    '("<up>"      . meow-prev)
    '("<down>"    . meow-next)
    '("S-<left>"  . meow-left-expand)
    '("S-<right>" . meow-right-expand)
    '("S-<up>"    . meow-prev-expand)
    '("S-<down>"  . meow-next-expand)
    '("C-<left>"  . meow-back-word)
    '("C-<right>" . meow-next-word)
    '("M-<left>"  . meow-back-symbol)
    '("M-<right>" . meow-next-symbol)

    ;; Word/symbol motion — spatial pair (h left of e on Gallium home row).
    '("h" . meow-back-word)
    '("H" . meow-back-symbol)
    '("e" . meow-next-word)
    '("E" . meow-next-symbol)

    ;; Insert/append.
    '("i" . meow-insert)
    '("I" . meow-open-above)
    '("a" . meow-append)
    '("A" . meow-open-below)

    ;; Edit actions.
    '("c" . meow-change)
    '("C" . my/meow-change-to-line-end)
    '("d" . my/meow-delete-dwim)
    '("D" . my/meow-select-to-line-end)
    '("r" . meow-replace)
    '("R" . meow-swap-grab)
    '("u" . meow-undo)
    ;; Helix redo.  C-r stays global backward search; undo within the
    ;; selection is plain C-/ with a selection active.
    '("U" . undo-redo)
    '("p" . meow-yank)
    '("P" . consult-yank-pop)
    '("y" . meow-save)
    '("Y" . meow-sync-grab)

    ;; Targeted jumps.
    '("f" . meow-find)
    '("F" . meow-find-expand)
    '("t" . meow-till)
    '("T" . meow-till-expand)
    '("n" . meow-search)

    ;; Selection / text objects.
    '("w" . meow-mark-word)
    '("W" . meow-mark-symbol)
    '("l" . meow-line)
    '("L" . meow-goto-line)
    '("b" . meow-block)
    '("B" . meow-to-block)
    '("," . meow-inner-of-thing)
    '("." . meow-bounds-of-thing)
    '("[" . meow-beginning-of-thing)
    '("]" . meow-end-of-thing)

    ;; Selection manipulation.
    '("g" . meow-cancel-selection)
    '("G" . meow-grab)
    '("j" . meow-join)
    '("x" . expreg-expand)
    '("X" . expreg-contract)
    '(">" . my/meow-indent-right)
    '("<" . my/meow-indent-left)
    '("=" . my/meow-reindent-lines)
    '("#" . my/meow-comment-lines)
    '("~" . my/meow-upcase)
    '("`" . my/meow-downcase)
    '("^" . back-to-indentation)
    '("$" . move-end-of-line)
    (cons "m" my-surround-map)
    '("z" . meow-pop-selection)
    '(";" . meow-reverse)

    ;; Prefix / mode-specific (C-c dispatch).
    '("o" . my/meow-ctrl-c)
    '("@" . my/meow-outline-prefix)

    ;; Misc.
    '("%" . my/forward-or-backward-sexp)
    '("v" . meow-visit)
    '("q" . meow-quit)
    '("'" . repeat)
    '("!" . consult-buffer)
    '("/" . avy-goto-char-2)
    ;; Jump back/forward (Helix C-o/C-i; C-i is TAB, so C-S-o).
    '("C-o"   . dogears-back)
    '("C-S-o" . dogears-forward)
    '("<escape>" . ignore)))


(provide 'dl-meow-map)
;;; dl-meow-map.el ends here
