;;; dl-meow-keymap-test.el --- ert tests for meow normal-state bindings -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-meow-keymap RET.

(require 'ert)
(require 'meow)
(require 'dl-keymap)

(meow-setup)

(defmacro dl-meow-keymap-test--with-buffer (text &rest body)
  "Run BODY in a selected, undo-enabled buffer holding TEXT, point at start.
`standard-indent' is pinned to the config's 2; `emacs -Q' defaults to 4."
  (declare (indent 1))
  `(with-temp-buffer
     (setq-local standard-indent 2)
     (save-window-excursion
       (switch-to-buffer (current-buffer))
       (buffer-enable-undo)
       (insert ,text)
       (goto-char (point-min))
       (transient-mark-mode 1)
       ,@body)))

(defun dl-meow-keymap-test--select (beg end)
  "Activate a selection from BEG to END."
  (goto-char end)
  (push-mark beg t t))

(defun dl-meow-keymap-test--run (command)
  "Invoke COMMAND as the command loop would, tracking `last-command'."
  (setq this-command command)
  (call-interactively command)
  (setq last-command command))

(ert-deftest dl-meow-keymap/normal-state-bindings ()
  "Gap-filling commands are reachable from normal state."
  (pcase-dolist (`(,key . ,command)
                 '(("C-r"   . undo-redo)
                   (">"     . my/meow-indent-right)
                   ("<"     . my/meow-indent-left)
                   ("x"     . expreg-expand)
                   ("X"     . expreg-contract)
                   ("C-o"   . dogears-back)
                   ("C-S-o" . dogears-forward)
                   ("m s"   . my/meow-surround)
                   ("m d"   . my/meow-surround-delete)
                   ("m r"   . my/meow-surround-replace)
                   ("#"     . my/meow-comment-lines)
                   ("="     . my/meow-reindent-lines)
                   ("~"     . my/meow-upcase)
                   ("`"     . my/meow-downcase)
                   ("P"     . consult-yank-pop)
                   ("T"     . meow-till-expand)
                   ("^"     . back-to-indentation)
                   ("$"     . move-end-of-line)))
    (should (eq (lookup-key meow-normal-state-keymap (kbd key)) command))))

(ert-deftest dl-meow-keymap/redo-reverts-meow-undo ()
  "`C-r' re-applies the change `u' undid."
  (dl-meow-keymap-test--with-buffer ""
    (insert "a") (undo-boundary)
    (insert "b") (undo-boundary)
    (dl-meow-keymap-test--run 'meow-undo)
    (should (equal (buffer-string) "a"))
    (dl-meow-keymap-test--run 'undo-redo)
    (should (equal (buffer-string) "ab"))))

(ert-deftest dl-meow-keymap/indent-shifts-selected-lines ()
  "`>' shifts every line the selection touches and keeps it active.
A linewise selection ending at the next line's start excludes that line."
  (dl-meow-keymap-test--with-buffer "a\nb\nc"
    (dl-meow-keymap-test--select (point-min) (line-beginning-position 3))
    (dl-meow-keymap-test--run 'my/meow-indent-right)
    (should (equal (buffer-string) "  a\n  b\nc"))
    (should (region-active-p))
    (dl-meow-keymap-test--run 'my/meow-indent-left)
    (should (equal (buffer-string) "a\nb\nc"))))

(ert-deftest dl-meow-keymap/indent-without-selection-shifts-current-line ()
  "With no selection, `>' shifts only the line at point."
  (dl-meow-keymap-test--with-buffer "a\nb"
    (forward-line 1)
    (dl-meow-keymap-test--run 'my/meow-indent-right)
    (should (equal (buffer-string) "a\n  b"))))

(defun dl-meow-keymap-test--selected ()
  "The selected text."
  (buffer-substring-no-properties (region-beginning) (region-end)))

(ert-deftest dl-meow-keymap/surround-wraps-selection ()
  "`m s' wraps the selection in a pair; opener or closer picks the same pair.
Other characters wrap symmetrically.  The selection stays on the content."
  (pcase-dolist (`(,char . ,expected) '((?\( . "x (ab) y")
                                        (?\) . "x (ab) y")
                                        (?\" . "x \"ab\" y")))
    (dl-meow-keymap-test--with-buffer "x ab y"
      (dl-meow-keymap-test--select 3 5)
      (my/meow-surround char)
      (should (equal (buffer-string) expected))
      (should (equal (dl-meow-keymap-test--selected) "ab")))))

(ert-deftest dl-meow-keymap/surround-without-selection-inserts-pair ()
  "With no selection, `m s' inserts the pair with point inside it."
  (dl-meow-keymap-test--with-buffer "ab"
    (forward-char 1)
    (my/meow-surround ?\[)
    (should (equal (buffer-string) "a[]b"))
    (should (= (point) 3))))

(ert-deftest dl-meow-keymap/surround-delete-removes-flanking-pair ()
  "`m d' deletes the delimiters around an inner selection."
  (dl-meow-keymap-test--with-buffer "x (ab) y"
    (dl-meow-keymap-test--select 4 6)
    (my/meow-surround-delete)
    (should (equal (buffer-string) "x ab y"))
    (should (equal (dl-meow-keymap-test--selected) "ab"))))

(ert-deftest dl-meow-keymap/surround-replace-swaps-flanking-pair ()
  "`m r' replaces the delimiters around an inner selection."
  (dl-meow-keymap-test--with-buffer "x (ab) y"
    (dl-meow-keymap-test--select 4 6)
    (my/meow-surround-replace ?\{)
    (should (equal (buffer-string) "x {ab} y"))
    (should (equal (dl-meow-keymap-test--selected) "ab"))))

(ert-deftest dl-meow-keymap/surround-delete-rejects-unpaired-flanks ()
  "`m d' refuses when the selection is not inside a pair."
  (dl-meow-keymap-test--with-buffer "x (ab] y"
    (dl-meow-keymap-test--select 4 6)
    (should-error (my/meow-surround-delete) :type 'user-error)
    (should (equal (buffer-string) "x (ab] y"))))

(ert-deftest dl-meow-keymap/comment-toggles-selected-lines ()
  "`#' comments the lines the selection touches, then uncomments them."
  (dl-meow-keymap-test--with-buffer "a\nb\nc"
    (emacs-lisp-mode)
    (dl-meow-keymap-test--select (point-min) (line-beginning-position 3))
    (dl-meow-keymap-test--run 'my/meow-comment-lines)
    (should (equal (buffer-string) ";; a\n;; b\nc"))
    (should (region-active-p))
    (dl-meow-keymap-test--run 'my/meow-comment-lines)
    (should (equal (buffer-string) "a\nb\nc"))))

(ert-deftest dl-meow-keymap/reindent-fixes-selected-lines ()
  "`=' reindents the lines the selection touches."
  (dl-meow-keymap-test--with-buffer "(a\nb)"
    (emacs-lisp-mode)
    (dl-meow-keymap-test--select (point-min) (point-max))
    (dl-meow-keymap-test--run 'my/meow-reindent-lines)
    (should (equal (buffer-string) "(a\n b)"))))

(ert-deftest dl-meow-keymap/case-without-selection-changes-whole-word ()
  "`~' / `` ` '' change the whole word around point, not just its tail,
and leave point where it was."
  (dl-meow-keymap-test--with-buffer "foo bar"
    (forward-char 1)
    (dl-meow-keymap-test--run 'my/meow-upcase)
    (should (equal (buffer-string) "FOO bar"))
    (should (= (point) 2))
    (dl-meow-keymap-test--run 'my/meow-downcase)
    (should (equal (buffer-string) "foo bar"))))

(ert-deftest dl-meow-keymap/case-changes-selection-and-keeps-it ()
  "With a selection, `~' changes exactly it and the selection survives."
  (dl-meow-keymap-test--with-buffer "foo bar baz"
    (dl-meow-keymap-test--select 5 8)
    (dl-meow-keymap-test--run 'my/meow-upcase)
    (should (equal (buffer-string) "foo BAR baz"))
    (should (region-active-p))
    (should (equal (dl-meow-keymap-test--selected) "BAR"))))

(provide 'dl-meow-keymap-test)
;;; dl-meow-keymap-test.el ends here
