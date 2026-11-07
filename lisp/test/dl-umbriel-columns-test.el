;;; dl-umbriel-columns-test.el --- ert tests for umbriel column layout -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-umbriel-columns RET.
;;
;; Layout is pure, so nothing here needs a buffer.  How rows land in
;; *umbriel* is tested in dl-umbriel-buffer-test.el.

(require 'ert)
(require 'dl-umbriel-columns)

(defun dl-umbriel-columns-test--stops (row)
  "The `:align-to' specs on ROW, a string, left to right."
  (let ((pos 0)
        stops)
    (while (< pos (length row))
      (when-let* ((display (get-text-property pos 'display row)))
        (push (plist-get (cdr display) :align-to) stops))
      (setq pos (1+ pos)))
    (nreverse stops)))

(ert-deftest dl-umbriel-columns-fit/cuts-only-limited-columns ()
  "A cell over its limit ends in an ellipsis; others are left alone."
  (should (equal '((a . "xxx…") (b . "xxxxxx") (c . "xx"))
                 (dl-umbriel-columns-fit
                  '((a . "xxxxxx") (b . "xxxxxx") (c . "xx"))
                  '((a . 4) (c . 4))))))

(ert-deftest dl-umbriel-columns-starts/measure-the-widest-cell ()
  "Each column starts a gap past the widest cell of the one before."
  (should (equal `((a . 2)
                   (b . ,(+ 2 3 dl-umbriel-columns-gap))
                   (c . ,(+ 2 3 dl-umbriel-columns-gap
                            1 dl-umbriel-columns-gap)))
                 (dl-umbriel-columns-starts '(((a . "xxx") (b . "") (c . "x"))
                                              ((a . "x") (b . "x") (c . "xxx")))
                                            2))))

(ert-deftest dl-umbriel-columns-starts/count-display-width ()
  "A wide character counts as the columns it occupies."
  (should (= (+ 2 dl-umbriel-columns-gap)
             (alist-get 'b (dl-umbriel-columns-starts
                            '(((a . "漢") (b . "x"))) 0)))))

(ert-deftest dl-umbriel-columns-starts/no-rows-no-columns ()
  "Nothing to measure gives no starts."
  (should-not (dl-umbriel-columns-starts nil 0)))

(ert-deftest dl-umbriel-columns-row/reads-as-a-single-spaced-line ()
  "Without its display properties a row is its cells, one space apart."
  (should (equal "foo bar"
                 (substring-no-properties
                  (dl-umbriel-columns-row '((a . "foo") (b . "bar"))
                                          '((a . 0) (b . 9))
                                          nil)))))

(ert-deftest dl-umbriel-columns-row/stops-count-the-buffer-font ()
  "A gap aligns in the current font's width, not the frame's."
  (should (equal '((9 . width))
                 (dl-umbriel-columns-test--stops
                  (dl-umbriel-columns-row '((a . "foo") (b . "bar"))
                                          '((a . 0) (b . 9))
                                          nil)))))

(ert-deftest dl-umbriel-columns-row/skips-an-empty-cell ()
  "An empty cell takes no gap; the next cell keeps its own stop."
  (let ((row (dl-umbriel-columns-row '((a . "foo") (b . "") (c . "bar"))
                                     '((a . 0) (b . 5) (c . 9))
                                     nil)))
    (should (equal "foo bar" (substring-no-properties row)))
    (should (equal '((9 . width)) (dl-umbriel-columns-test--stops row)))))

(ert-deftest dl-umbriel-columns-row/faces-go-on-the-text-not-the-gap ()
  "A cell's face covers its text; a column with no face has none."
  (let ((row (dl-umbriel-columns-row '((a . "foo") (b . "bar"))
                                     '((a . 0) (b . 9))
                                     '((a . bold)))))
    (should (eq 'bold (get-text-property 0 'font-lock-face row)))
    (should-not (get-text-property 3 'font-lock-face row))
    (should-not (get-text-property 4 'font-lock-face row))))

;;; dl-umbriel-columns-test.el ends here
