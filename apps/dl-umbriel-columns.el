;;; dl-umbriel-columns.el --- Lay out cells in aligned columns -*- lexical-binding: t; -*-

;; Turns rows of cells into one-line strings whose columns line up.  A
;; cell is `(COLUMN . TEXT)', as `dl-umbriel-model' builds them, and a row
;; is an alist of cells in column order.  Columns are named, so what a
;; column means and how it looks stay with the caller: limits and faces
;; come in as alists keyed by column.
;;
;; Everything here is pure.  A gap is one space with a `display' property,
;; so a row's text is still its cells joined by single spaces.

(require 'seq)

(defconst dl-umbriel-columns-gap 2
  "Columns of space between the widest cell of a column and the next.")

(defun dl-umbriel-columns-fit (cells limits)
  "CELLS with each text cut to its column's limit in LIMITS.
LIMITS is an alist of column to width; a column left out is unlimited."
  (mapcar (lambda (cell)
            (if-let* ((limit (alist-get (car cell) limits)))
                (cons (car cell)
                      (truncate-string-to-width (cdr cell) limit nil nil "…"))
              cell))
          cells))

(defun dl-umbriel-columns-starts (rows indent)
  "Where each column of ROWS starts, as an alist of column to position.
ROWS are cell alists with the same columns.  The first column starts at
INDENT and each next one a gap past the previous column's widest cell."
  (let ((start indent))
    (mapcar (lambda (column)
              (prog1 (cons column start)
                (setq start
                      (+ start dl-umbriel-columns-gap
                         (seq-max
                          (mapcar (lambda (row)
                                    (string-width (alist-get column row)))
                                  rows))))))
            (mapcar #'car (car rows)))))

(defun dl-umbriel-columns-row (cells starts faces)
  "CELLS as one line, each at its place in STARTS and its face in FACES.
FACES is an alist of column to face; a column left out has none.  An
empty cell is skipped.  A gap is one space displayed `:align-to' the next
cell, counted in the buffer's font, not the frame's: the text stays the
cells joined, and a title's emoji cannot push the columns out, whatever
width its font gives it."
  (let ((shown (seq-remove (lambda (cell) (string-empty-p (cdr cell))) cells)))
    (mapconcat
     (lambda (cell)
       (let ((face (alist-get (car cell) faces)))
         (concat (unless (eq cell (car shown))
                   (propertize " " 'display
                               `(space :align-to
                                       (,(alist-get (car cell) starts)
                                        . width))))
                 (if face
                     (propertize (cdr cell) 'font-lock-face face)
                   (cdr cell)))))
     shown "")))

(provide 'dl-umbriel-columns)

;;; dl-umbriel-columns.el ends here
