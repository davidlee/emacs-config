;;; dl-umbriel-buffer.el --- Draw held umbriel state -*- lexical-binding: t; -*-

;; The display half of the umbriel client.  `dl-umbriel' holds the last
;; snapshots the stream was sent; this file draws them as a tree of magit
;; sections -- workspaces, and the windows joined to each -- and does
;; nothing else.  It never connects and never sends: `my/umbriel' is the
;; one entry point that opens the stream, beside the buffer's creation,
;; never from the mode body.
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

(defun dl-umbriel-buffer--insert-windows (windows)
  "Insert each of WINDOWS as a child section, in the given order."
  (dolist (window windows)
    (magit-insert-section (umbriel-window (alist-get 'id window))
      (insert "  " (dl-umbriel-model-window-label window) "\n"))))

(defun dl-umbriel-buffer--insert-group (group)
  "Insert GROUP, a `(WORKSPACE . WINDOWS)' pair from the model.
A nil WORKSPACE is the model's Unassigned group, which has no id."
  (let ((workspace (car group))
        (windows (cdr group)))
    (if (not workspace)
        (magit-insert-section (umbriel-unassigned)
          (magit-insert-heading "Unassigned")
          (dl-umbriel-buffer--insert-windows windows))
      (magit-insert-section (umbriel-workspace (alist-get 'id workspace))
        (magit-insert-heading
         (dl-umbriel-model-workspace-label workspace (length windows)))
        (dl-umbriel-buffer--insert-windows windows)))))

(defun dl-umbriel-buffer--insert (workspaces windows)
  "Insert the held WORKSPACES and WINDOWS as sections at point.
The caller erases the buffer first; this inserts the whole tree."
  (magit-insert-section (umbriel-root)
    (if (and (null workspaces) (null windows))
        (insert "No windows or workspaces held.\n")
      (dolist (group (dl-umbriel-model-group workspaces windows))
        (dl-umbriel-buffer--insert-group group)))))

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

;;;; Mode

(defvar-keymap dl-umbriel-buffer-mode-map
  :doc "Keymap for `dl-umbriel-buffer-mode'."
  "g" #'my/umbriel-refresh)

(define-derived-mode dl-umbriel-buffer-mode magit-section-mode "Umbriel"
  "Major mode for the *umbriel* buffer.

Displays the held state as a section tree.  It never opens the stream
and never sends a request: `my/umbriel' owns the connection."
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
