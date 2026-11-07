;;; dl-umbriel-buffer.el --- Draw held umbriel state -*- lexical-binding: t; -*-

;; The display half of the umbriel client.  `dl-umbriel' holds the last
;; snapshots the stream was sent; this file draws them as a tree of magit
;; sections -- workspaces, and the windows joined to each -- and turns a
;; key on a row into the requests that act on it.  It never connects:
;; `my/umbriel' is the one entry point that opens the stream, beside the
;; buffer's creation, never from the mode body.
;;
;; Actions are one table and one plan.  The row at point is captured
;; first, its plan is then refused or built, and only then is anything
;; prompted and sent -- so a refused row never prompts, and a prompt
;; never redirects the action it was opened for.  Nothing is refreshed
;; before a reply lands, and no effect is ever written locally: the
;; buffer shows only what the compositor reports.  No prompt runs inside
;; a process callback; the global switch reaches its prompt in a timer.
;;
;; Repainting is decoupled from drawing.  A write to the held state only
;; schedules one repaint, `dl-umbriel-buffer-repaint-delay' out, so a
;; burst of stream events coalesces into a single redraw.  The timer does
;; not redraw a buffer nobody is looking at: it marks the buffer stale,
;; and the buffer redraws itself when a window next displays it.
;;
;; A repaint keeps what the user would notice: every displaying window's
;; point returns to the section it was on, and folds survive through
;; magit's visibility cache.  See DEC-022.

(require 'magit-section)
(require 'dl-umbriel)
(require 'dl-umbriel-columns)
(require 'dl-umbriel-model)

;;;; State of the buffer

(defconst dl-umbriel-buffer-name "*umbriel*"
  "The name of the buffer that displays the held umbriel state.")

(defconst dl-umbriel-buffer-repaint-delay 0.1
  "Seconds a state change waits before the buffer repaints.
A burst of stream events therefore coalesces into one redraw.")

(defvar dl-umbriel-buffer--repaint-timer nil
  "The pending repaint timer, or nil when no repaint is pending.
Global on purpose: one repaint serves the one *umbriel* buffer, however
many changes asked for it.")

(defvar-local dl-umbriel-buffer--stale nil
  "Non-nil when the buffer fell behind the held state while undisplayed.
`window-buffer-change-functions' schedules the repaint that catches up.")

(defun dl-umbriel-buffer--live ()
  "The *umbriel* buffer when it is alive and in `dl-umbriel-buffer-mode'.
A buffer that merely bears the name is somebody else's; never draw into
it."
  (let ((buffer (get-buffer dl-umbriel-buffer-name)))
    (when (and (buffer-live-p buffer)
               (eq (buffer-local-value 'major-mode buffer)
                   'dl-umbriel-buffer-mode))
      buffer)))

;;;; Header line

(defun dl-umbriel-buffer--doubled (text)
  "TEXT with every `%' doubled, as a mode-line construct requires."
  (replace-regexp-in-string "%" "%%" text t t))

(defun dl-umbriel-buffer--status-text (status)
  "One sentence naming the stream STATUS."
  (pcase status
    ('open "umbriel: stream open")
    ('never "umbriel: stream never opened")
    (_ (dl-umbriel-failure-message status))))

(defun dl-umbriel-buffer--skipped-text (skipped)
  "How many stream lines were SKIPPED, or nil when none were."
  (when (> skipped 0)
    (if (= skipped 1)
        "1 line skipped"
      (format "%s lines skipped" skipped))))

(defun dl-umbriel-buffer--header-text (status skipped)
  "The header line for the client STATUS and the SKIPPED line count.
Every `%' is doubled, because the result is a mode-line construct."
  (let ((text (dl-umbriel-buffer--status-text status))
        (skipped-text (dl-umbriel-buffer--skipped-text skipped)))
    (dl-umbriel-buffer--doubled
     (if skipped-text (format "%s · %s" text skipped-text) text))))

;;;; Rendering

(defface dl-umbriel-buffer-active-window
  '((t :inherit isearch :extend t))
  "Face for the row of the window holding the keyboard."
  :group 'faces)

(defface dl-umbriel-buffer-focused-window
  '((t :inherit highlight :extend t))
  "Face for the row of a workspace's remembered focus."
  :group 'faces)

(defface dl-umbriel-buffer-active-workspace
  '((t :inherit magit-section-heading :extend t))
  "Face for the heading of an active workspace.
`core/dl-faces.el' shades it a step darker than the rows below it."
  :group 'faces)

(defface dl-umbriel-buffer-active-workspace-window
  '((t :extend t))
  "Face for the window rows of an active workspace.
`core/dl-faces.el' shades it darker than `default'."
  :group 'faces)

(defun dl-umbriel-buffer--window-face (window)
  "The face that marks WINDOW's row, or nil for an unmarked one.
`active' is seat-global, `focused' is per workspace, so `active' wins."
  (cond ((alist-get 'active window) 'dl-umbriel-buffer-active-window)
        ((alist-get 'focused window) 'dl-umbriel-buffer-focused-window)))

(defun dl-umbriel-buffer--overlay-face (start end face)
  "Show START to END in FACE.
An overlay, because magit's point highlight is one and would hide a
text property; the priority outranks it.  The repaint's erase empties
the overlay, which then evaporates."
  (let ((overlay (make-overlay start end)))
    (overlay-put overlay 'face face)
    (overlay-put overlay 'priority 1)
    (overlay-put overlay 'evaporate t)))

(defface dl-umbriel-buffer-active-workspace-id
  '((t :inherit bold :foreground "white"))
  "Face for the output and index in an active workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-active-workspace-name
  '((t :inherit success :inverse-video t))
  "Face for the name pill in an active workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-workspace-name
  '((t :inherit default))
  "Face for the name pill in an inactive workspace's heading.
`core/dl-faces.el' gives it a muted shade of the active pill's colour."
  :group 'faces)

(defface dl-umbriel-buffer-layout
  '((t))
  "Face every layout pill shares; it sets no foreground, so a layout can.
`core/dl-faces.el' gives it a background."
  :group 'faces)

(defface dl-umbriel-buffer-layout-scrolling
  '((t :inherit (dl-umbriel-buffer-layout font-lock-comment-face)
       :slant normal))
  "Face for the `scrolling' layout in a workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-layout-dwindle
  '((t :inherit (dl-umbriel-buffer-layout warning) :weight normal))
  "Face for the `dwindle' layout in a workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-layout-master
  '((t :inherit (dl-umbriel-buffer-layout success) :weight normal))
  "Face for the `master' layout in a workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-layout-stacking
  '((t :inherit (dl-umbriel-buffer-layout font-lock-string-face)))
  "Face for the `stacking' layout in a workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-layout-toggle
  '((t :inherit (dl-umbriel-buffer-layout shadow)))
  "Face for the `toggle' layout in a workspace's heading."
  :group 'faces)

(defface dl-umbriel-buffer-window-app
  '((t :inherit font-lock-string-face))
  "Face for the app id column of a window row."
  :group 'faces)

(defface dl-umbriel-buffer-window-placement
  '((t :inherit shadow))
  "Face for the placement column of a window row."
  :group 'faces)

(defface dl-umbriel-buffer-window-flags
  '((t :inherit font-lock-comment-face))
  "Face for the flags column of a window row."
  :group 'faces)

(defconst dl-umbriel-buffer-window-cell-faces
  '((app . dl-umbriel-buffer-window-app)
    (placement . dl-umbriel-buffer-window-placement)
    (flags . dl-umbriel-buffer-window-flags))
  "The face of each window row column; a column left out has none.")

(defconst dl-umbriel-buffer-layouts
  '(("scrolling" dl-umbriel-buffer-layout-scrolling "\U000F0E73")
    ("dwindle" dl-umbriel-buffer-layout-dwindle "\U000F1677")
    ("master" dl-umbriel-buffer-layout-master "\U000F0574")
    ("stacking" dl-umbriel-buffer-layout-stacking "\U000F0328")
    ("toggle" dl-umbriel-buffer-layout-toggle "\U000F0521"))
  "The face and Nerd Font icon of each layout.
A layout left out shows in `dl-umbriel-buffer-layout', without an icon.")

(defconst dl-umbriel-buffer-column-limits '((app . 24) (title . 40))
  "The widest each column may grow; a column left out is unlimited.")

(defconst dl-umbriel-buffer-row-indent "  "
  "What a window row starts with, under its workspace's heading.")

(defun dl-umbriel-buffer--window-cells (window)
  "WINDOW's cells, cut to fit their columns."
  (dl-umbriel-columns-fit (dl-umbriel-model-window-cells window)
                          dl-umbriel-buffer-column-limits))

(defun dl-umbriel-buffer--insert-window (window starts)
  "Insert WINDOW's row at point, at STARTS, in the face that marks it, if any."
  (let ((start (point)))
    (insert dl-umbriel-buffer-row-indent
            (dl-umbriel-columns-row (dl-umbriel-buffer--window-cells window)
                                    starts
                                    dl-umbriel-buffer-window-cell-faces)
            "\n")
    (when-let* ((face (dl-umbriel-buffer--window-face window)))
      (dl-umbriel-buffer--overlay-face start (point) face))))

(defun dl-umbriel-buffer--insert-windows (windows starts)
  "Insert each of WINDOWS as a child section at STARTS, in the given order."
  (dolist (window windows)
    (magit-insert-section (umbriel-window (alist-get 'id window))
      (dl-umbriel-buffer--insert-window window starts))))

(defun dl-umbriel-buffer--pill (text face)
  "TEXT padded, in FACE, as a pill; an empty TEXT stays empty."
  (if (string-empty-p text)
      ""
    (propertize (format " %s " text)
                'font-lock-face face 'dl-umbriel-buffer-pill t)))

(defun dl-umbriel-buffer--layout-pill (layout)
  "The pill for LAYOUT, in its face and behind its icon when it has them."
  (pcase-let ((`(,face ,icon)
               (or (cdr (assoc layout dl-umbriel-buffer-layouts))
                   '(dl-umbriel-buffer-layout))))
    (dl-umbriel-buffer--pill (string-join (remq nil (list icon layout)) " ")
                             face)))

(defun dl-umbriel-buffer--group-cells (group)
  "The heading cells of GROUP, a `(WORKSPACE . WINDOWS)' pair.
The count comes before the layout, so the layout can sit over the rows'
placement, and the name and layout are pills."
  (let* ((workspace (car group))
         (cells (dl-umbriel-model-workspace-cells workspace
                                                  (length (cdr group)))))
    (list (assq 'id cells)
          (cons 'name (dl-umbriel-buffer--pill
                       (alist-get 'name cells)
                       (if (alist-get 'active workspace)
                           'dl-umbriel-buffer-active-workspace-name
                         'dl-umbriel-buffer-workspace-name)))
          (assq 'windows cells)
          (cons 'layout (dl-umbriel-buffer--layout-pill
                         (alist-get 'layout cells)))
          (assq 'marks cells))))

(defun dl-umbriel-buffer--row-starts (windows heading-cells)
  "Where WINDOWS' columns start, leaving room for HEADING-CELLS' layouts.
A layout sits over the placement column, so it can push the flags right."
  (let* ((starts (dl-umbriel-columns-starts
                  (mapcar #'dl-umbriel-buffer--window-cells windows)
                  (length dl-umbriel-buffer-row-indent)))
         (placement (alist-get 'placement starts)))
    (dl-umbriel-columns-at-least
     starts 'flags
     (and placement heading-cells
          (+ placement dl-umbriel-columns-gap
             (dl-umbriel-columns-width heading-cells 'layout))))))

(defun dl-umbriel-buffer--heading-starts (heading-cells row-starts)
  "Where HEADING-CELLS' columns start, lined up with ROW-STARTS.
A heading's layout sits over the rows' placement and its marks over their
flags, unless its own cells run past them."
  (dl-umbriel-columns-at-least
   (dl-umbriel-columns-at-least (dl-umbriel-columns-starts heading-cells 0)
                                'layout (alist-get 'placement row-starts))
   'marks (alist-get 'flags row-starts)))

(defun dl-umbriel-buffer--count-end (row-starts)
  "Where a heading's window count ends: the right edge of ROW-STARTS' titles.
Nil when there are no rows to line up with."
  (when-let* ((placement (alist-get 'placement row-starts)))
    (- placement dl-umbriel-columns-gap)))

(defun dl-umbriel-buffer--workspace-heading (group starts count-end)
  "The heading of GROUP at STARTS, shaded when its workspace is active.
Its window count ends at COUNT-END, if that leaves the count clear of
the cells before it.  A styled cell stops `magit-insert-heading' applying
its face, so the heading sets its own, under the cells.  The newline is
part of the heading, so an active shade spans the line."
  (let* ((cells (dl-umbriel-buffer--group-cells group))
         (active (alist-get 'active (car group)))
         (heading
          (concat (dl-umbriel-columns-row
                   cells
                   (dl-umbriel-columns-at-least
                    starts 'windows
                    (and count-end
                         (- count-end
                            (string-width (alist-get 'windows cells)))))
                   (and active
                        '((id . dl-umbriel-buffer-active-workspace-id))))
                  "\n")))
    (font-lock-append-text-property
     0 (length heading) 'font-lock-face
     (if active 'dl-umbriel-buffer-active-workspace 'magit-section-heading)
     heading)
    heading))

(defun dl-umbriel-buffer--raise-pills (start end)
  "Show each pill from START to END over the point highlight.
Its text property alone would lose its background under point."
  (while (< start end)
    (let ((next (next-single-property-change start 'dl-umbriel-buffer-pill
                                             nil end)))
      (when (get-text-property start 'dl-umbriel-buffer-pill)
        (dl-umbriel-buffer--overlay-face
         start next (car (ensure-list (get-text-property start
                                                         'font-lock-face)))))
      (setq start next))))

(defun dl-umbriel-buffer--insert-workspace-windows (workspace windows starts)
  "Insert WINDOWS, WORKSPACE's rows at STARTS, shaded when it is active.
A text property, so magit's point highlight still shows over the shade."
  (let ((start (point)))
    (dl-umbriel-buffer--insert-windows windows starts)
    (when (alist-get 'active workspace)
      (font-lock-append-text-property
       start (point) 'font-lock-face
       'dl-umbriel-buffer-active-workspace-window))))

(defun dl-umbriel-buffer--insert-group (group heading-starts row-starts)
  "Insert GROUP, a `(WORKSPACE . WINDOWS)' pair from the model.
HEADING-STARTS and ROW-STARTS place its heading and rows.  A nil
WORKSPACE is the model's Unassigned group, which has no id."
  (let ((workspace (car group))
        (windows (cdr group)))
    (if (not workspace)
        (magit-insert-section (umbriel-unassigned)
          (magit-insert-heading "Unassigned")
          (dl-umbriel-buffer--insert-windows windows row-starts))
      (magit-insert-section (umbriel-workspace (alist-get 'id workspace))
        (let ((start (point)))
          (magit-insert-heading
           (dl-umbriel-buffer--workspace-heading
            group heading-starts (dl-umbriel-buffer--count-end row-starts)))
          (dl-umbriel-buffer--raise-pills start (point)))
        (dl-umbriel-buffer--insert-workspace-windows workspace windows
                                                     row-starts)))))

(defun dl-umbriel-buffer--insert (workspaces windows)
  "Insert the held WORKSPACES and WINDOWS as sections at point.
The caller erases the buffer first; this inserts the whole tree.  Columns
line up across every group, so they are measured before anything is
inserted."
  (magit-insert-section (umbriel-root)
    (if (and (null workspaces) (null windows))
        (insert "No windows or workspaces held.\n")
      (let* ((groups (dl-umbriel-model-group workspaces windows))
             (heading-cells (mapcar #'dl-umbriel-buffer--group-cells
                                    (seq-filter #'car groups)))
             (row-starts (dl-umbriel-buffer--row-starts windows heading-cells))
             (heading-starts (dl-umbriel-buffer--heading-starts heading-cells
                                                                row-starts)))
        (dolist (group groups)
          (dl-umbriel-buffer--insert-group group heading-starts row-starts))))))

;;;; Keeping point

(defun dl-umbriel-buffer--point-entry ()
  "The section at point with its line and column offset, or nil.
The result is `(SECTION LINE CHAR)'."
  (when-let* ((section (magit-section-at)))
    (cons section (magit-section-get-relative-position section))))

(defun dl-umbriel-buffer--start-entry ()
  "The section at `window-start' with its line offset, or nil."
  (let ((start (window-start)))
    (when-let* ((section (magit-section-at start)))
      (cons section (count-lines (oref section start) start)))))

(defun dl-umbriel-buffer--record-positions ()
  "The point and start of every window that shows the current buffer.
Each entry is `(WINDOW POINT-ENTRY START-ENTRY)', the entries as the
recorders above return them.  When no window shows the buffer, the one
entry has a nil WINDOW and the buffer's own point."
  (let ((buffer (current-buffer)))
    (or (mapcar (lambda (window)
                  (with-selected-window window
                    (with-current-buffer buffer
                      (list window
                            (dl-umbriel-buffer--point-entry)
                            (dl-umbriel-buffer--start-entry)))))
                (get-buffer-window-list buffer nil t))
        (list (list nil (dl-umbriel-buffer--point-entry))))))

(defun dl-umbriel-buffer--goto-position (position)
  "Move point back onto POSITION, a `(SECTION LINE CHAR)' list, or nil."
  (when position
    (pcase-let ((`(,section ,line ,char) position))
      (magit-section-goto-successor section line char))))

(defun dl-umbriel-buffer--restore-start (window entry)
  "Put WINDOW's start back on the section in ENTRY, if not past point."
  (when-let* ((section (car-safe entry))
              (line (cdr-safe entry)))
    (when-let* ((found (magit-get-section (magit-section-ident section)))
                (pos (save-excursion
                       (goto-char (oref found start))
                       (forward-line line)
                       (point))))
      (when (<= pos (window-point window))
        (set-window-start window pos t)))))

(defun dl-umbriel-buffer--restore-positions (entries)
  "Move each window in ENTRIES back onto the sections it was showing."
  (dolist (entry entries)
    (let ((window (nth 0 entry)))
      (if (not window)
          (dl-umbriel-buffer--goto-position (nth 1 entry))
        (with-selected-window window
          (dl-umbriel-buffer--goto-position (nth 1 entry)))
        (dl-umbriel-buffer--restore-start window (nth 2 entry))))))

;;;; Repainting

(defun dl-umbriel-buffer--forget-highlight ()
  "Drop the highlight state that the coming erase invalidates."
  (setq magit-section-pre-command-section nil
        magit-section-highlight-overlays nil
        magit-section-selection-overlays nil
        magit-section-highlighted-sections nil
        magit-section-focused-sections nil))

(defun dl-umbriel-buffer--repaint ()
  "Redraw the *umbriel* buffer from the held state, keeping each point.
Does nothing unless there is a live *umbriel* buffer."
  (when-let* ((buffer (dl-umbriel-buffer--live)))
    (with-current-buffer buffer
      (dl-umbriel-buffer--forget-highlight)
      (let ((positions (dl-umbriel-buffer--record-positions))
            (inhibit-read-only t))
        (erase-buffer)
        (dl-umbriel-buffer--insert (dl-umbriel-workspaces)
                                   (dl-umbriel-windows))
        ;; The new sections know their `hidden' slot; only this gives
        ;; them the invisible overlays that make a fold real.
        (let ((magit-section-cache-visibility nil))
          (magit-section-show magit-root-section))
        (setq dl-umbriel-buffer--stale nil)
        (dl-umbriel-buffer--restore-positions positions))
      (magit-section-update-highlight t)
      (set-buffer-modified-p nil))))

(defun dl-umbriel-buffer--repaint-due ()
  "Repaint *umbriel* when a window shows it, else mark the buffer stale."
  (setq dl-umbriel-buffer--repaint-timer nil)
  (when-let* ((buffer (dl-umbriel-buffer--live)))
    (if (get-buffer-window buffer t)
        (dl-umbriel-buffer--repaint)
      (with-current-buffer buffer
        (setq dl-umbriel-buffer--stale t)))))

(defun dl-umbriel-buffer--schedule-repaint ()
  "Schedule one repaint of the *umbriel* buffer, unless one is pending.
The hook function: it never cancels or re-arms the pending timer, so a
burst of changes shares one repaint."
  (when (and (dl-umbriel-buffer--live)
             (null dl-umbriel-buffer--repaint-timer))
    (setq dl-umbriel-buffer--repaint-timer
          (run-at-time dl-umbriel-buffer-repaint-delay nil
                       #'dl-umbriel-buffer--repaint-due))))

(defun dl-umbriel-buffer--on-display (_window)
  "Schedule a repaint when this newly displayed buffer is stale.
It never edits the buffer: only the timer does.  The hook also runs for
buffers a window stops showing, which only costs a scheduled repaint."
  (when dl-umbriel-buffer--stale
    (dl-umbriel-buffer--schedule-repaint)))

;;;; Commands

(defun dl-umbriel-buffer--on-kill ()
  "Close the stream, then cancel a pending repaint, as *umbriel* dies.
The close announces the new status, which can arm a timer through the
state hook, so the cancel has to come last."
  (dl-umbriel-stream-close)
  (when-let* ((timer dl-umbriel-buffer--repaint-timer))
    (cancel-timer timer)
    (setq dl-umbriel-buffer--repaint-timer nil)))

(defun my/umbriel-refresh ()
  "Repaint *umbriel*, reopening the stream when it is not open.
An open stream is asked for nothing: the repaint shows what the stream
already delivered."
  (interactive)
  (if (eq (dl-umbriel-stream-status) 'open)
      (dl-umbriel-buffer--repaint)
    (dl-umbriel-stream-open)))

;;;; Actions

;; A row key names an action, and most actions act on what the
;; compositor has focused, not on the row.  Acting on a row is therefore
;; three steps: capture the held entry the row shows, plan the requests
;; that make that entry the right one (or refuse the row), then -- only
;; if the plan stands -- prompt and send.  One table holds all three per
;; row, and one plan builds them.

(eval-and-compile
  (defconst dl-umbriel-buffer-actions
    '((my/umbriel-focus "window-focus" window)
      (my/umbriel-toggle-floating "window-toggle-floating" window)
      (my/umbriel-kill "window-kill" window confirm-kill)
      (my/umbriel-center "window-center" focused)
      (my/umbriel-cycle-extent "window-cycle-primary-extent" focused)
      (my/umbriel-cycle-extent-back "window-cycle-primary-extent-back"
                                    focused)
      (my/umbriel-column-left "column-move-left" focused)
      (my/umbriel-column-right "column-move-right" focused)
      (my/umbriel-move-to-workspace "window-move-to-workspace-silent"
                                    focused workspace)
      (my/umbriel-switch "workspace-switch" workspace)
      (my/umbriel-set-layout "workspace-set-layout" active-workspace
                             layout))
    "Row actions: COMMAND, umbriel ACTION, ADDRESSING and a PROMPT.
ADDRESSING is `window' (the action takes the row's window id),
`focused' (focus the row's window first, then act, then restore the
focus the compositor held), `workspace' (always switch to the row's
workspace) or `active-workspace' (switch there, unless that is already
the focused workspace, then act: switching to a workspace umbriel holds
active on its output toggles back to the previous one under
`back_and_forth').  PROMPT,
when given, is `workspace', `layout' or `confirm-kill'; a prompting
row prompts in its command, never in a reply.  Moving a window goes
silently, so the plan's own focus steps are the only ones seen
(DEC-025)."))

(defun dl-umbriel-buffer--target ()
  "The held entry the row at point addresses, as a one-pair plist.
A `umbriel-window' section gives `(:window ENTRY)', an
`umbriel-workspace' one `(:workspace ENTRY)'; a heading, an empty
buffer or an entry no longer held is a `user-error'.  Capturing the
entry here is what keeps a later prompt from redirecting the action."
  (let* ((section (magit-section-at))
         (type (and section (oref section type)))
         (value (and section (oref section value))))
    (pcase type
      ('umbriel-window
       (if-let* ((window (dl-umbriel-window value)))
           (list :window window)
         (user-error "No umbriel row at point")))
      ('umbriel-workspace
       (if-let* ((workspace (seq-find (lambda (held)
                                        (equal value (alist-get 'id held)))
                                      (dl-umbriel-workspaces))))
           (list :workspace workspace)
         (user-error "No umbriel row at point")))
      (_ (user-error "No umbriel row at point")))))

(defun dl-umbriel-buffer--focused-workspace (workspaces)
  "The one workspace in WORKSPACES umbriel marks focused, or nil.
umbriel marks at most one; with none focused, or with more than one,
there is no answer, and nil is how callers read that (D-2, R-1)."
  (let ((focused (seq-filter (lambda (held) (alist-get 'focused held))
                             workspaces)))
    (when (= 1 (length focused))
      (car focused))))

(defun dl-umbriel-buffer--off-pointer-p (workspace workspaces)
  "Non-nil unless WORKSPACE is on the output under the pointer.
That is the output of the `focused' workspace in WORKSPACES.  With
none focused, or with more than one, there is no answer, and refusing
is the conservative reading of F-6 (D-2, R-1)."
  (if-let* ((focused (dl-umbriel-buffer--focused-workspace workspaces)))
      (not (equal (alist-get 'output workspace)
                  (alist-get 'output focused)))
    t))

(defun dl-umbriel-buffer--previous-focus (workspaces)
  "The window id a `focused' plan restores afterwards, or nil.
That is the `focused_window' of the focused workspace in WORKSPACES,
which umbriel sends as \"\" when no window is focused (DEC-025).  A
workspace that is not known, or a `focused_window' that is absent, nil
or empty, leaves the focus unknown."
  (when-let* ((focused (dl-umbriel-buffer--focused-workspace workspaces))
              (id (alist-get 'focused_window focused)))
    (and (stringp id) (not (string-empty-p id)) id)))

(defun dl-umbriel-buffer--plan (spec target fields workspaces)
  "The requests SPEC plans for TARGET, or a refusal message string.
SPEC is a row of `dl-umbriel-buffer-actions', TARGET the plist
`dl-umbriel-buffer--target' returned, FIELDS the prompted action
fields or nil, and WORKSPACES the held workspaces.  Pure: it reads no
other state (D-1).  A refusal is a string with no requests in it and
depends on nothing but SPEC, TARGET and WORKSPACES, which is what lets
a command refuse a row before it prompts (D-3).  A `focused' window
row whose known previous focus is a different window plans one more
`window-focus' at the end, putting that focus back (DEC-025).  An
`active-workspace' row switches to its workspace unless that is the
focused one, in which case it only acts: switching to a workspace
umbriel already holds active toggles back under `back_and_forth'."
  (let* ((action (nth 1 spec))
         (addressing (nth 2 spec))
         (window (plist-get target :window))
         (its (and window
                   (dl-umbriel-model-window-workspace workspaces window)))
         (workspace (or (plist-get target :workspace) its))
         (focused (dl-umbriel-buffer--focused-workspace workspaces))
         (already (and workspace focused
                       (equal (alist-get 'id workspace)
                              (alist-get 'id focused))))
         (switch (and workspace
                      (dl-umbriel-action
                       "workspace-switch"
                       (dl-umbriel-model-workspace-selector workspace))))
         (act (dl-umbriel-action action fields)))
    (pcase addressing
      ('window
       (if window
           (list (dl-umbriel-action
                  action (cons (cons 'window (alist-get 'id window)) fields)))
         "Not a window"))
      ('focused
       (if window
           (let* ((id (alist-get 'id window))
                  (previous (dl-umbriel-buffer--previous-focus workspaces))
                  (focus (dl-umbriel-action "window-focus"
                                            (list (cons 'window id)))))
             (if (and previous (not (equal previous id)))
                 (list focus act
                       (dl-umbriel-action
                        "window-focus" (list (cons 'window previous))))
               (list focus act)))
         (list act)))
      ('workspace
       (if switch (list switch) "Window has no workspace"))
      ('active-workspace
       (cond ((not switch) "Window has no workspace")
             ((dl-umbriel-buffer--off-pointer-p workspace workspaces)
              "The layout acts on the output under the pointer, not here")
             (already (list act))
             (t (list switch act))))
      (_ (error "Unknown addressing: %S" addressing)))))

(defun dl-umbriel-buffer--ordered-table (candidates)
  "A completion table over CANDIDATES that keeps their own order.
vertico prefers a table's `display-sort-function' metadata over
`vertico-sort-function', so declaring identity there keeps a recency
sort (prescient) from reordering the prompt."
  (lambda (string pred action)
    (if (eq action 'metadata)
        '(metadata (display-sort-function . identity)
                   (cycle-sort-function . identity))
      (complete-with-action action candidates string pred))))

(defun dl-umbriel-buffer--workspace-fields ()
  "The selector fields of the held workspace the user picks.
The prompt offers the choices in model order.  Empty input, which
`completing-read' allows even when it requires a match, is a
`user-error': nothing is sent."
  (let* ((choices (dl-umbriel-model-workspace-choices (dl-umbriel-workspaces)))
         (workspace (alist-get (completing-read
                                "Workspace: "
                                (dl-umbriel-buffer--ordered-table choices)
                                nil t)
                               choices nil nil #'equal)))
    (unless workspace
      (user-error "No workspace chosen"))
    (dl-umbriel-model-workspace-selector workspace)))

(defun dl-umbriel-buffer--layout-fields ()
  "The layout field the user picks, for the output under the pointer.
The prompt offers the layouts in model order.  Empty input is a
`user-error', as for a workspace."
  (let ((layout (completing-read
                 "Set the layout of the output under the pointer: "
                 (dl-umbriel-buffer--ordered-table dl-umbriel-model-layouts)
                 nil t)))
    (unless (member layout dl-umbriel-model-layouts)
      (user-error "No layout chosen"))
    (list (cons 'layout layout))))

(defun dl-umbriel-buffer--confirm-kill (window)
  "nil when the user confirms killing WINDOW, `declined' when not.
Emacs's own pid refuses at once, before any prompt: killing it would
take the editor with it (DEC-019, F-19).  The prompt reuses the row's
label, so compositor text arrives sanitised to one line; WINDOW was
captured before the prompt, so a repaint cannot redirect the kill."
  (let ((pid (alist-get 'pid window)))
    (when (and (numberp pid) (= pid (emacs-pid)))
      (user-error "That window is this Emacs; use delete-frame instead"))
    (unless (y-or-n-p (format "Kill the process of %s (pid %s)? "
                              (dl-umbriel-model-window-label window)
                              pid))
      'declined)))

(defun dl-umbriel-buffer--fields (kind target)
  "The action fields KIND yields for TARGET, or `declined'.
KIND is a row's PROMPT: `workspace' and `layout' prompt with
`completing-read', `confirm-kill' confirms TARGET's window, and nil
prompts nothing.  Any other kind signals an `error': a mistyped
prompt must never send unconfirmed."
  (cond ((null kind) nil)
        ((eq kind 'workspace) (dl-umbriel-buffer--workspace-fields))
        ((eq kind 'layout) (dl-umbriel-buffer--layout-fields))
        ((eq kind 'confirm-kill)
         (dl-umbriel-buffer--confirm-kill (plist-get target :window)))
        (t (error "Unknown prompt kind: %S" kind))))

(defun dl-umbriel-buffer--completion (result)
  "Act on the reply RESULT, then re-query unless the stream is open.
A failure is echoed and never refreshed; a success is silent.  The
stream status is read when the reply lands, not when the request left:
with the stream open the effect arrives on its own (DEC-021)."
  (if (eq (car result) :failure)
      (dl-umbriel-echo-failure result)
    (unless (eq (dl-umbriel-stream-status) 'open)
      (dl-umbriel-refresh))))

(defun dl-umbriel-buffer--run (spec)
  "Send what SPEC plans for the row at point, refusing and prompting.
The target is captured and the plan refused before any prompt (D-3),
and the plan is refused again once the prompted fields are in, so a
refusal never reaches `dl-umbriel-send-all'.  The prompts read the
held state; the reply is left to `dl-umbriel-buffer--completion'.  A
declined prompt sends nothing."
  (let* ((target (dl-umbriel-buffer--target))
         (workspaces (dl-umbriel-workspaces))
         (refusal (dl-umbriel-buffer--plan spec target nil workspaces)))
    (when (stringp refusal)
      (user-error "%s" refusal))
    (let ((fields (dl-umbriel-buffer--fields (nth 3 spec) target)))
      (unless (eq fields 'declined)
        (let ((plan (dl-umbriel-buffer--plan spec target fields workspaces)))
          (when (stringp plan)
            (user-error "%s" plan))
          (dl-umbriel-send-all plan #'dl-umbriel-buffer--completion))))))

(defmacro dl-umbriel-buffer--define-actions ()
  "Define one interactive command per row of `dl-umbriel-buffer-actions'.
Each command has a docstring naming its action and addressing, and
delegates to `dl-umbriel-buffer--run' with its own row."
  `(progn
     ,@(mapcar (lambda (row)
                 (let ((command (nth 0 row))
                       (action (nth 1 row))
                       (addressing (nth 2 row)))
                   `(defun ,command ()
                      ,(format "Send the action %s for the row at point.
Addressing: %s." action addressing)
                      (interactive)
                      (dl-umbriel-buffer--run ',row))))
               dl-umbriel-buffer-actions)))

(dl-umbriel-buffer--define-actions)

;;;; Global commands

(defun dl-umbriel-buffer--send-one (action fields)
  "Send the single request ACTION with FIELDS, then complete it.
The global commands act where the pointer is, not on a row."
  (dl-umbriel-send-all (list (dl-umbriel-action action fields))
                       #'dl-umbriel-buffer--completion))

(defun dl-umbriel-buffer--switch ()
  "Send `workspace-switch' to the held workspace the user picks."
  (dl-umbriel-buffer--send-one "workspace-switch"
                               (dl-umbriel-buffer--workspace-fields)))

(defun dl-umbriel-buffer--switch-later ()
  "Switch workspaces from a timer, or say why there is nothing to switch to.
A refresh's reply may not prompt, so it schedules this instead (D-5);
an active minibuffer asks for a retry, and so does the reply holding
no workspace at all."
  (cond ((active-minibuffer-window)
         (message "Minibuffer in use; retry with C-c u w"))
        ((null (dl-umbriel-workspaces))
         (message "No umbriel workspace known; retry with C-c u w"))
        (t (dl-umbriel-buffer--switch))))

;;;###autoload
(defun my/umbriel-switch-workspace ()
  "Switch to a workspace chosen from the held state.
The prompt runs now only while the stream is open and workspaces are
held; otherwise the state is refreshed first and the prompt follows
the reply in a timer, so no prompt ever runs inside a process
callback.  A reply that still holds no workspace is not prompted
from -- it says so instead (D-5, R-7)."
  (interactive)
  (if (and (eq (dl-umbriel-stream-status) 'open)
           (dl-umbriel-workspaces))
      (dl-umbriel-buffer--switch)
    (dl-umbriel-refresh
     (lambda (result)
       (if (eq (car result) :failure)
           (dl-umbriel-echo-failure result)
         (run-at-time 0 nil #'dl-umbriel-buffer--switch-later))))))

;;;###autoload
(defun my/umbriel-set-active-layout ()
  "Set the layout of the workspace on the output under the pointer.
The layout is prompted for at once: the choices need no held state
(D-7)."
  (interactive)
  (dl-umbriel-buffer--send-one "workspace-set-layout"
                               (dl-umbriel-buffer--layout-fields)))

;;;; Mode

(defvar-keymap dl-umbriel-buffer-mode-map
  :doc "Keymap for `dl-umbriel-buffer-mode'."
  "RET" #'my/umbriel-focus
  "s" #'my/umbriel-switch
  "m" #'my/umbriel-move-to-workspace
  "t" #'my/umbriel-toggle-floating
  "c" #'my/umbriel-center
  "k" #'my/umbriel-kill
  "L" #'my/umbriel-set-layout
  "M-<left>" #'my/umbriel-column-left
  "<" #'my/umbriel-column-left
  "M-<right>" #'my/umbriel-column-right
  ">" #'my/umbriel-column-right
  "e" #'my/umbriel-cycle-extent
  "E" #'my/umbriel-cycle-extent-back
  "g" #'my/umbriel-refresh
  "q" #'quit-window)

(define-derived-mode dl-umbriel-buffer-mode magit-section-mode "Umbriel"
  "Major mode for the *umbriel* buffer.

Displays the held state as a section tree and sends the requests the
row keys name.  It never opens the stream: `my/umbriel' owns the
connection."
  (setq-local header-line-format
              '(:eval (dl-umbriel-buffer--header-text
                       (dl-umbriel-stream-status)
                       (dl-umbriel-skipped))))
  (add-hook 'window-buffer-change-functions
            #'dl-umbriel-buffer--on-display nil t)
  (add-hook 'dl-umbriel-state-changed-hook
            #'dl-umbriel-buffer--schedule-repaint))

(defun dl-umbriel-buffer--create ()
  "Create *umbriel*, open the stream for it, draw it; return the buffer.
Whoever opens the stream registers the close: the kill hook is added
here, beside the open, never in the mode body."
  (with-current-buffer (get-buffer-create dl-umbriel-buffer-name)
    (dl-umbriel-buffer-mode)
    (add-hook 'kill-buffer-hook #'dl-umbriel-buffer--on-kill nil t)
    (dl-umbriel-stream-open)
    (dl-umbriel-buffer--repaint)
    (current-buffer)))

;;;###autoload
(defun my/umbriel ()
  "Show the *umbriel* buffer, opening the stream when it is new.
An existing buffer is shown as it is: nothing is reopened."
  (interactive)
  (pop-to-buffer (or (dl-umbriel-buffer--live) (dl-umbriel-buffer--create))))

(provide 'dl-umbriel-buffer)
;;; dl-umbriel-buffer.el ends here
