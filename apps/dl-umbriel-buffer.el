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
      (my/umbriel-scroll-left "layout-scroll-left" focused)
      (my/umbriel-scroll-right "layout-scroll-right" focused)
      (my/umbriel-move-to-workspace "window-move-to-workspace" focused
                                    workspace)
      (my/umbriel-switch "workspace-switch" workspace)
      (my/umbriel-set-layout "workspace-set-layout" active-workspace
                             layout))
    "Row actions: COMMAND, umbriel ACTION, ADDRESSING and a PROMPT.
ADDRESSING is `window' (the action takes the row's window id),
`focused' (focus the row's window first, then act), `workspace'
(switch to the row's workspace) or `active-workspace' (switch there,
then act).  PROMPT, when given, is `workspace', `layout' or
`confirm-kill'; a prompting row prompts in its command, never in a
reply."))

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

(defun dl-umbriel-buffer--off-pointer-p (workspace workspaces)
  "Non-nil unless WORKSPACE is on the output under the pointer.
That is the output of the `focused' workspace in WORKSPACES, which
umbriel marks for at most one workspace.  With none focused, or with
more than one, there is no answer, and refusing is the conservative
reading of F-6 (D-2, R-1)."
  (let ((focused (seq-filter (lambda (held) (alist-get 'focused held))
                             workspaces)))
    (not (and (= 1 (length focused))
              (equal (alist-get 'output workspace)
                     (alist-get 'output (car focused)))))))

(defun dl-umbriel-buffer--plan (spec target fields workspaces)
  "The requests SPEC plans for TARGET, or a refusal message string.
SPEC is a row of `dl-umbriel-buffer-actions', TARGET the plist
`dl-umbriel-buffer--target' returned, FIELDS the prompted action
fields or nil, and WORKSPACES the held workspaces.  Pure: it reads no
other state (D-1).  A refusal is a string with no requests in it and
depends on nothing but SPEC, TARGET and WORKSPACES, which is what lets
a command refuse a row before it prompts (D-3)."
  (let* ((action (nth 1 spec))
         (addressing (nth 2 spec))
         (window (plist-get target :window))
         (its (and window
                   (dl-umbriel-model-window-workspace workspaces window)))
         (workspace (or (plist-get target :workspace) its))
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
           (list (dl-umbriel-action
                  "window-focus"
                  (list (cons 'window (alist-get 'id window))))
                 act)
         (list act)))
      ('workspace
       (if switch (list switch) "Window has no workspace"))
      ('active-workspace
       (cond ((not switch) "Window has no workspace")
             ((dl-umbriel-buffer--off-pointer-p workspace workspaces)
              "The layout acts on the output under the pointer, not here")
             (t (list switch act))))
      (_ (error "Unknown addressing: %S" addressing)))))

(defun dl-umbriel-buffer--workspace-fields ()
  "The selector fields of the held workspace the user picks.
Empty input, which `completing-read' allows even when it requires a
match, is a `user-error': nothing is sent."
  (let* ((choices (dl-umbriel-model-workspace-choices (dl-umbriel-workspaces)))
         (workspace (alist-get (completing-read "Workspace: " choices nil t)
                               choices nil nil #'equal)))
    (unless workspace
      (user-error "No workspace chosen"))
    (dl-umbriel-model-workspace-selector workspace)))

(defun dl-umbriel-buffer--layout-fields ()
  "The layout field the user picks, for the output under the pointer.
Empty input is a `user-error', as for a workspace."
  (let ((layout (completing-read
                 "Set the layout of the output under the pointer: "
                 dl-umbriel-model-layouts nil t)))
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
  "C-<left>" #'my/umbriel-scroll-left
  "[" #'my/umbriel-scroll-left
  "C-<right>" #'my/umbriel-scroll-right
  "]" #'my/umbriel-scroll-right
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
