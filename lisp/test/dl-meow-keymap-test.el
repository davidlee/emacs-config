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
                   ("C-S-o" . dogears-forward)))
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

(provide 'dl-meow-keymap-test)
;;; dl-meow-keymap-test.el ends here
