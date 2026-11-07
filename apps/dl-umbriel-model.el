;;; dl-umbriel-model.el --- Pure model of a umbriel snapshot -*- lexical-binding: t; -*-

;; The model turns the parsed umbriel snapshots into the data and one-line
;; strings a presentation layer draws: workspaces paired with their windows,
;; the selector that addresses a workspace, and the labels a user reads.
;;
;; Everything here is pure -- parsed alists in, data or strings out -- so it
;; can be tested without a compositor and reused by any front end.  No
;; process, buffer or input is touched.
;;
;; Entries are alists in the shape DEC-013 parses out of the wire: JSON
;; false, null and `[]' all arrive as nil, so every read is `alist-get' with
;; a default (`""' for strings, `-1' for positions and `index', nil for
;; flags).  A field renamed upstream degrades a label instead of signalling,
;; and no entry -- even an empty one -- makes a function here signal.
;;
;; Ordering is expressed as sort keys, one list per entry, and `sort' with
;; `:key' compares them with `value<': lists lexicographically, numbers
;; numerically, strings with `string<'.  Sorting is stable and copies, so a
;; tie keeps input order and no caller's list is mutated.
;;
;; Two addressing fields are not interchangeable.  The join between a window
;; and its workspace uses the workspace's opaque `id'; an action addresses a
;; workspace by its selector, the `name' when `named' (even when it is all
;; digits) else the `index', always qualified by its `output'.  Windows are
;; addressed by their own opaque `id'.  Flattening is a display rule only:
;; the join and the selector read raw values.
;;
;; The wire's `window_count' is never read: a workspace's window count is
;; the number of windows the join placed under it, so label and rows agree.

(require 'seq)
(require 'subr-x)

;;;; Fields

(defun dl-umbriel-model--text (entry key)
  "ENTRY's KEY flattened into one line.
Newlines, carriage returns and tabs become spaces; a missing value, or a
nil one, becomes the empty string, and a non-string is rendered with
`%s'."
  (let ((value (alist-get key entry)))
    (cond ((stringp value)
           (replace-regexp-in-string "[\n\r\t]" " " value t t))
          ((null value) "")
          (t (format "%s" value)))))

(defun dl-umbriel-model--number (value)
  "VALUE when it is an integer, else -1, the unset position."
  (if (integerp value) value -1))

(defun dl-umbriel-model--position (value)
  "VALUE when it is a placed position, else `most-positive-fixnum'.
Placed means an integer of 0 or more; -1 and anything unreadable sorts
after every placed position."
  (if (and (integerp value) (>= value 0))
      value
    most-positive-fixnum))

(defun dl-umbriel-model--marks (entry fields)
  "The names of FIELDS that ENTRY has set, in the given order, as strings."
  (delq nil (mapcar (lambda (field)
                      (and (alist-get field entry) (symbol-name field)))
                    fields)))

;;;; Sort keys

(defun dl-umbriel-model--workspace-key (workspace)
  "Sort key for WORKSPACE: its `output', then its `index'."
  (list (dl-umbriel-model--text workspace 'output)
        (dl-umbriel-model--number (alist-get 'index workspace -1))))

(defun dl-umbriel-model--window-key (window)
  "Sort key for WINDOW, which also puts tiled windows before floating ones.
Tiled windows sort by `column', then `row', then `tab_index' (each with -1
last), then `title'; floating windows sort by `title' alone."
  (if (alist-get 'floating window)
      (list 1 0 0 0 (dl-umbriel-model--text window 'title))
    (list 0
          (dl-umbriel-model--position (alist-get 'column window -1))
          (dl-umbriel-model--position (alist-get 'row window -1))
          (dl-umbriel-model--position (alist-get 'tab_index window -1))
          (dl-umbriel-model--text window 'title))))

;;;; Grouping

(defun dl-umbriel-model--windows-of (owner pairs)
  "The windows of PAIRS that OWNER takes, in display order.
PAIRS are `(OWNER . WINDOW)' as `dl-umbriel-model-group' computed them,
with a nil owner for the windows that join nothing."
  (sort (mapcar #'cdr (seq-filter (lambda (pair) (eq owner (car pair)))
                                  pairs))
        :key #'dl-umbriel-model--window-key))

(defun dl-umbriel-model-group (workspaces windows)
  "Pair each of WORKSPACES with the WINDOWS that join it, in display order.
The result is a list of `(WORKSPACE . WINDOWS)' groups, ordered by output
and index; a workspace with no windows is kept, with nil windows.  A
window joins the workspace whose `id' equals its `workspace'; one that
joins none -- an empty, nil or unknown id -- goes to a final
`(nil . WINDOWS)' group, omitted when empty.  Every window appears exactly
once, entries are returned as given, and neither input is mutated."
  (let* ((ordered (sort workspaces :key #'dl-umbriel-model--workspace-key))
         (pairs (mapcar (lambda (window)
                          (cons (dl-umbriel-model-window-workspace
                                 ordered window)
                                window))
                        windows))
         (groups (mapcar (lambda (workspace)
                           (cons workspace
                                 (dl-umbriel-model--windows-of
                                  workspace pairs)))
                         ordered))
         (unassigned (dl-umbriel-model--windows-of nil pairs)))
    (if unassigned
        (append groups (list (cons nil unassigned)))
      groups)))

(defun dl-umbriel-model-window-workspace (workspaces window)
  "The entry in WORKSPACES that WINDOW joins, or nil.
The join is on the raw opaque `id'; a window whose `workspace' is not a
non-empty string joins nothing."
  (let ((id (alist-get 'workspace window)))
    (when (and (stringp id) (not (string-empty-p id)))
      (seq-find (lambda (workspace)
                  (equal id (alist-get 'id workspace)))
                workspaces))))

;;;; Selectors and choices

(defun dl-umbriel-model-workspace-selector (workspace)
  "The action fields addressing WORKSPACE, as an alist.
`workspace' is the raw `name' string when WORKSPACE is `named' -- even
when it is all digits -- else the `index' number.  `output' is always
present, raw as well."
  (list (cons 'workspace
              (if (alist-get 'named workspace)
                  (or (alist-get 'name workspace) "")
                (dl-umbriel-model--number (alist-get 'index workspace -1))))
        (cons 'output (or (alist-get 'output workspace) ""))))

(defun dl-umbriel-model-workspace-choices (workspaces)
  "`(LABEL . WORKSPACE)' pairs for `completing-read', in display order.
LABEL is `dl-umbriel-model-workspace-label' without a window count."
  (mapcar (lambda (workspace)
            (cons (dl-umbriel-model-workspace-label workspace) workspace))
          (sort workspaces :key #'dl-umbriel-model--workspace-key)))

;;;; Display strings

(defun dl-umbriel-model--line (tokens)
  "TOKENS, the non-empty ones, joined into one display line."
  (string-join (seq-filter (lambda (token) (not (string-empty-p token)))
                           tokens)
               " "))

(defun dl-umbriel-model--cells-line (cells)
  "CELLS, an alist of column to text, as one display line."
  (dl-umbriel-model--line (mapcar #'cdr cells)))

(defun dl-umbriel-model-workspace-cells (workspace &optional count)
  "WORKSPACE's display parts as an alist, in column order.
`id' is the output and index, `name' the name of a named workspace,
`layout' the layout, `windows' how many windows the join placed under it
when COUNT is non-nil, and `marks' the `active', `focused' and `urgent'
marks.  A part WORKSPACE lacks is the empty string.  The wire's
`window_count' is never read."
  (list (cons 'id (dl-umbriel-model--line
                   (list (dl-umbriel-model--text workspace 'output)
                         (number-to-string
                          (dl-umbriel-model--number
                           (alist-get 'index workspace -1))))))
        (cons 'name (if (alist-get 'named workspace)
                        (dl-umbriel-model--text workspace 'name)
                      ""))
        (cons 'layout (dl-umbriel-model--text workspace 'layout))
        (cons 'windows (cond ((null count) "")
                             ((equal count 1) "1 window")
                             (t (format "%s windows" count))))
        (cons 'marks (dl-umbriel-model--line
                      (dl-umbriel-model--marks
                       workspace '(active focused urgent))))))

(defun dl-umbriel-model-workspace-label (workspace &optional count)
  "One display line for WORKSPACE, its cells for COUNT windows joined.
See `dl-umbriel-model-workspace-cells'."
  (dl-umbriel-model--cells-line
   (dl-umbriel-model-workspace-cells workspace count)))

(defun dl-umbriel-model--placement (window column row tab)
  "Placement token for WINDOW at COLUMN, ROW and TAB.
`float' for a floating window, `tab I' for a tabbed one, `tile C,R' when
COLUMN is placed, else the bare `tile'."
  (cond ((alist-get 'floating window) "float")
        ((alist-get 'tabbed window) (format "tab %d" tab))
        ((>= column 0) (format "tile %d,%d" column row))
        (t "tile")))

(defun dl-umbriel-model-window-cells (window)
  "WINDOW's display parts as an alist, in column order.
`app' is the app id, `title' the title, `placement' the placement, and
`flags' every flag that is set, in the order `active', `focused',
`visible', `minimized', `fullscreen', `urgent', `xwayland'.  A part
WINDOW lacks is the empty string."
  (list (cons 'app (dl-umbriel-model--text window 'app_id))
        (cons 'title (dl-umbriel-model--text window 'title))
        (cons 'placement
              (dl-umbriel-model--placement
               window
               (dl-umbriel-model--number (alist-get 'column window -1))
               (dl-umbriel-model--number (alist-get 'row window -1))
               (dl-umbriel-model--number (alist-get 'tab_index window -1))))
        (cons 'flags (dl-umbriel-model--line
                      (dl-umbriel-model--marks
                       window '(active focused visible minimized fullscreen
                                urgent xwayland))))))

(defun dl-umbriel-model-window-label (window)
  "One display line for WINDOW, its cells joined.
See `dl-umbriel-model-window-cells'."
  (dl-umbriel-model--cells-line (dl-umbriel-model-window-cells window)))

;;;; Layouts

(defconst dl-umbriel-model-layouts
  '("scrolling" "dwindle" "master" "stacking" "toggle")
  "The layout actions a workspace may be asked to switch to.")

(provide 'dl-umbriel-model)

;;; dl-umbriel-model.el ends here
