;;; dl-umbriel-buffer-test.el --- ert tests for the *umbriel* buffer -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-umbriel-buffer/ RET.
;;
;; Contract: .doctrine/slice/016/design.md § The buffer, and the phase sheet
;; .doctrine/state/slice/016/phases/phase-04.md (C-1..C-12, EX-1..EX-7).
;;
;; Nothing here reaches a compositor.  Every test runs inside
;; `dl-umbriel-buffer-test--with-state', which binds `process-environment' to a
;; socket path that does not exist, stubs the stream open/close pair, and kills
;; *umbriel* on the way out with the stubs still in place.  Fixtures are
;; hand-written alists in the DEC-013 shape; no title, app id or name below is
;; real.
;;
;; One batch-mode caveat: `format-mode-line' returns "" in `emacs --batch'
;; whatever it is given (there is no terminal to render a mode line on), so the
;; `%%' rule is checked where it is observable here: the header construct's
;; text has every `%' doubled, which is exactly what the display would halve.

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'eieio)
(require 'magit-section)
(require 'dl-umbriel)
(require 'dl-umbriel-model)
(require 'dl-umbriel-buffer)

;; Declared for the byte-compiler: the tests `let'-bind and read these, and the
;; implementation owns their values.
(defvar dl-umbriel-buffer--repaint-timer)
(defvar dl-umbriel-buffer--stale)

;;;; Fixtures

(defconst dl-umbriel-buffer-test--unset :unset
  "Override value that removes a field from a fixture entry entirely.")

(defun dl-umbriel-buffer-test--entry (defaults overrides)
  "Return a copy of DEFAULTS with the plist OVERRIDES applied.
OVERRIDES are keywords (`:id') naming the alist symbols they replace.  A
value of `dl-umbriel-buffer-test--unset' removes that key instead."
  (let ((entry (copy-tree defaults)))
    (while overrides
      (let ((key (intern (substring (symbol-name (pop overrides)) 1)))
            (value (pop overrides)))
        (setq entry (assq-delete-all key entry))
        (unless (eq value dl-umbriel-buffer-test--unset)
          (push (cons key value) entry))))
    entry))

(defconst dl-umbriel-buffer-test--workspace-defaults
  '((id . "DP-1:1") (name . "web") (named . t) (index . 1) (output . "DP-1")
    (active . nil) (focused . nil) (layout . "dwindle"))
  "A workspace entry as the compositor snapshot delivers it.")

(defconst dl-umbriel-buffer-test--window-defaults
  '((id . "w-1") (workspace . "DP-1:1") (app_id . "foot") (title . "shell")
    (floating . nil) (column . 0) (row . 0) (tabbed . nil) (tab_index . -1)
    (active . nil) (focused . nil) (visible . nil) (minimized . nil)
    (fullscreen . nil) (urgent . nil) (xwayland . nil) (pid . 4242))
  "A window entry as the compositor snapshot delivers it.")

(defun dl-umbriel-buffer-test--workspace (&rest overrides)
  "A workspace fixture with OVERRIDES applied."
  (dl-umbriel-buffer-test--entry dl-umbriel-buffer-test--workspace-defaults
                                 overrides))

(defun dl-umbriel-buffer-test--window (&rest overrides)
  "A window fixture with OVERRIDES applied."
  (dl-umbriel-buffer-test--entry dl-umbriel-buffer-test--window-defaults
                                 overrides))

(defun dl-umbriel-buffer-test--held (windows workspaces &optional status skipped)
  "A held-state plist: WINDOWS, WORKSPACES, STATUS, SKIPPED.
STATUS is `open' unless given; SKIPPED is 0 unless given."
  (list :windows windows :workspaces workspaces
        :status (or status 'open) :skipped (or skipped 0)))

(defun dl-umbriel-buffer-test--fixture-workspaces ()
  "Two workspaces on two outputs, the second one empty."
  (list (dl-umbriel-buffer-test--workspace :id "DP-1:3" :name "web"
                                           :index 3 :output "DP-1")
        (dl-umbriel-buffer-test--workspace :id "HDMI-A-1:3" :name nil
                                           :named nil :index 3
                                           :output "HDMI-A-1")))

(defun dl-umbriel-buffer-test--fixture-windows ()
  "Windows for the render fixture: two joined, one scratch, one ghost."
  (list (dl-umbriel-buffer-test--window :id "w-abc" :workspace "DP-1:3"
                                        :app_id "foot" :title "shell"
                                        :column 0 :row 0
                                        :active t :focused t)
        (dl-umbriel-buffer-test--window :id "w-def" :workspace "DP-1:3"
                                        :app_id "emacs" :title "notes.org"
                                        :column 1 :row 0)
        (dl-umbriel-buffer-test--window :id "w-scratch" :workspace ""
                                        :app_id "pavucontrol" :title "Volume"
                                        :floating t :minimized t)
        (dl-umbriel-buffer-test--window :id "w-ghost" :workspace "DP-9:9"
                                        :app_id "firefox" :title "Docs"
                                        :column 0 :row 0)))

(defun dl-umbriel-buffer-test--point-workspaces ()
  "One workspace, for the point-keeping fixtures."
  (list (dl-umbriel-buffer-test--workspace :id "DP-1:3" :name "web"
                                           :index 3 :output "DP-1")))

(defun dl-umbriel-buffer-test--order-windows (b-column b-row)
  "Three windows in one workspace, with w-b placed at B-COLUMN and B-ROW.
At 0,0 w-b sorts first; at 3,0 it sorts last."
  (list (dl-umbriel-buffer-test--window :id "w-a" :workspace "DP-1:3"
                                        :app_id "foot" :title "alpha"
                                        :column 1 :row 0)
        (dl-umbriel-buffer-test--window :id "w-b" :workspace "DP-1:3"
                                        :app_id "emacs" :title "bravo"
                                        :column b-column :row b-row)
        (dl-umbriel-buffer-test--window :id "w-c" :workspace "DP-1:3"
                                        :app_id "kitty" :title "charlie"
                                        :column 2 :row 0)))

(defun dl-umbriel-buffer-test--tall-windows (&optional extra)
  "Thirty tiled windows in one workspace, plus EXTRA more.
Enough rows that the rendered tree is taller than a batch window."
  (cl-loop for index from 0 below (+ 30 (or extra 0))
           collect (dl-umbriel-buffer-test--window
                    :id (format "w-tall-%02d" index)
                    :workspace "DP-1:3"
                    :app_id "foot"
                    :title (format "tall %02d" index)
                    :column 0 :row index)))

(defconst dl-umbriel-buffer-test--socket
  "/nonexistent/umbriel-test/umbriel.sock"
  "The `UMBRIEL_SOCKET' every test binds: a path nothing listens on.")

;;;; Isolation (C-12)

(defvar dl-umbriel-buffer-test--stream-log nil
  "Stream calls made by the default stubs, newest first.")

(defvar dl-umbriel-buffer-test--timers nil
  "The timer objects `--with-timers' faked for the repaint throttle.")

(defconst dl-umbriel-buffer-test--helper-buffers
  (list "*umbriel-test-other*" "*umbriel-test-unrelated*")
  "Scratch buffers the tests display or kill, removed on the way out.")

(defmacro dl-umbriel-buffer-test--with-state (state &rest body)
  "Run BODY with STATE held, the stream faked and *umbriel* disposable.
STATE is a held-state plist for `dl-umbriel--state', or nil for the initial
state.  `process-environment' names a socket that does not exist and drops
`WAYLAND_DISPLAY'; `dl-umbriel-stream-open' and `-close' are counting stubs
logged in `dl-umbriel-buffer-test--stream-log';
`dl-umbriel-state-changed-hook' and the repaint timer start nil.  On exit
the buffer named `dl-umbriel-buffer-name' is killed with the stubs still
in place, and the window configuration is restored."
  (declare (indent 1))
  `(let ((dl-umbriel--state ,state)
         (dl-umbriel-state-changed-hook nil)
         (dl-umbriel-buffer--repaint-timer nil)
         (dl-umbriel-buffer-test--stream-log nil)
         (process-environment
          (append (list (concat "UMBRIEL_SOCKET="
                                dl-umbriel-buffer-test--socket))
                  (seq-remove
                   (lambda (variable)
                     (string-match-p
                      "\\`\\(UMBRIEL_SOCKET\\|WAYLAND_DISPLAY\\)=" variable))
                   process-environment))))
     (save-window-excursion
       (unwind-protect
           (cl-letf (((symbol-function 'dl-umbriel-stream-open)
                      (lambda (&rest _)
                        (push 'open dl-umbriel-buffer-test--stream-log)
                        t))
                     ((symbol-function 'dl-umbriel-stream-close)
                      (lambda (&rest _)
                        (push 'close dl-umbriel-buffer-test--stream-log)
                        nil)))
             ,@body)
         (when-let* ((buffer (get-buffer dl-umbriel-buffer-name)))
           (with-current-buffer buffer
             ;; A faked timer is not a timer: clear it, so the kill hook's
             ;; cancel (C-9) cannot signal now that the stubs are gone.
             (when (and dl-umbriel-buffer--repaint-timer
                        (not (timerp dl-umbriel-buffer--repaint-timer)))
               (setq dl-umbriel-buffer--repaint-timer nil)))
           (kill-buffer buffer)))
         ;; Nothing a test displayed or killed may outlive it either.
         (dolist (name dl-umbriel-buffer-test--helper-buffers)
           (when (get-buffer name)
             (kill-buffer name))))))

(defun dl-umbriel-buffer-test--count (call)
  "How often the default stubs logged CALL, a symbol."
  (seq-count (lambda (entry) (eq entry call))
             dl-umbriel-buffer-test--stream-log))

(defmacro dl-umbriel-buffer-test--with-timers (calls &rest body)
  "Run BODY with the timer interface discriminated; CALLS collects ours.
A `run-at-time' whose FUNCTION is `dl-umbriel-buffer--repaint-due' is
recorded in CALLS as `(DELAY REPEAT FUNCTION ARGS)' and answered with a
faked timer; a `run-with-idle-timer' for that function fails the test.
`cancel-timer' and `timer-set-time' fail the test when their TIMER is
one of ours, because the throttle never cancels or re-arms (C-6).
Every other call -- auto-revert and friends in a full init -- goes to
the original function."
  (declare (indent 1))
  `(let ((,calls nil)
         (dl-umbriel-buffer-test--timers nil)
         (orig-at-time (symbol-function 'run-at-time))
         (orig-idle (symbol-function 'run-with-idle-timer))
         (orig-cancel (symbol-function 'cancel-timer))
         (orig-set-time (symbol-function 'timer-set-time)))
     (cl-letf (((symbol-function 'run-at-time)
                (lambda (time repeat function &rest args)
                  (if (eq function #'dl-umbriel-buffer--repaint-due)
                      (let ((timer (list 'fake-timer time repeat)))
                        (push (list time repeat function args) ,calls)
                        (push timer dl-umbriel-buffer-test--timers)
                        timer)
                    (apply orig-at-time time repeat function args))))
               ((symbol-function 'run-with-idle-timer)
                (lambda (time repeat function &rest args)
                  (if (eq function #'dl-umbriel-buffer--repaint-due)
                      (ert-fail "the repaint throttle must not be idle")
                    (apply orig-idle time repeat function args))))
               ((symbol-function 'cancel-timer)
                (lambda (timer)
                  (if (memq timer dl-umbriel-buffer-test--timers)
                      (ert-fail "cancel-timer must not be called")
                    (funcall orig-cancel timer))))
               ((symbol-function 'timer-set-time)
                (lambda (timer &rest args)
                  (if (memq timer dl-umbriel-buffer-test--timers)
                      (ert-fail "timer-set-time must not be called")
                    (apply orig-set-time timer args)))))
       ,@body)))

(defmacro dl-umbriel-buffer-test--with-repaint-count (count &rest body)
  "Run BODY with `dl-umbriel-buffer--repaint' counting into COUNT."
  (declare (indent 1))
  `(let ((,count 0))
     (cl-letf (((symbol-function 'dl-umbriel-buffer--repaint)
                (lambda (&rest _) (cl-incf ,count))))
       ,@body)))

;;;; Buffer and section helpers

(defun dl-umbriel-buffer-test--mode-buffer ()
  "Create *umbriel* in `dl-umbriel-buffer-mode', undisplayed and unrendered."
  (let ((buffer (get-buffer-create dl-umbriel-buffer-name)))
    (with-current-buffer buffer
      (dl-umbriel-buffer-mode))
    buffer))

(defun dl-umbriel-buffer-test--text ()
  "The current buffer's text, without properties."
  (buffer-substring-no-properties (point-min) (point-max)))

(defun dl-umbriel-buffer-test--root ()
  "The root section of the current buffer."
  (or magit-root-section
      (error "The buffer has no root section")))

(defun dl-umbriel-buffer-test--children (&optional section)
  "The child sections of SECTION, default the root."
  (oref (or section (dl-umbriel-buffer-test--root)) children))

(defun dl-umbriel-buffer-test--sections (&optional section)
  "SECTION, default the root, and all its descendants, depth first."
  (let ((section (or section (dl-umbriel-buffer-test--root))))
    (cons section
          (mapcan #'dl-umbriel-buffer-test--sections (oref section children)))))

(defun dl-umbriel-buffer-test--types (sections)
  "The `type' of each of SECTIONS."
  (mapcar (lambda (section) (oref section type)) sections))

(defun dl-umbriel-buffer-test--values (sections)
  "The `value' of each of SECTIONS."
  (mapcar (lambda (section) (oref section value)) sections))

(defun dl-umbriel-buffer-test--find (type value)
  "The first section of TYPE in the current buffer whose value is VALUE."
  (seq-find (lambda (section)
              (and (eq (oref section type) type)
                   (equal (oref section value) value)))
            (dl-umbriel-buffer-test--sections)))

(defun dl-umbriel-buffer-test--heading (section)
  "The heading text of SECTION, from its start to the end of its heading."
  (buffer-substring-no-properties (oref section start)
                                  (or (oref section content)
                                      (oref section end))))

(defun dl-umbriel-buffer-test--percent-pairs-p (string)
  "Non-nil when every `%' in STRING is part of a `%%' pair.
That is the property a mode-line construct needs: the display halves each
pair, so a lone `%' would be read as a construct."
  (let ((index 0)
        (ok t)
        (length (length string)))
    (while (and ok (< index length))
      (if (eq (aref string index) ?%)
          (if (and (< (1+ index) length)
                   (eq (aref string (1+ index)) ?%))
              (setq index (+ index 2))
            (setq ok nil))
        (setq index (1+ index))))
    ok))

(defun dl-umbriel-buffer-test--doubled (string)
  "STRING with every `%' doubled, as a mode-line construct needs."
  (replace-regexp-in-string "%" "%%" string t t))

;;;; render (VT-1, EX-1)

(ert-deftest dl-umbriel-buffer/renders-the-held-state ()
  "VT-1/EX-1: section types and id values, windows nested, Unassigned last."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (should (eq (oref (dl-umbriel-buffer-test--root) type) 'umbriel-root))
        (let ((top (dl-umbriel-buffer-test--children)))
          (should (equal '(umbriel-workspace umbriel-workspace
                            umbriel-unassigned)
                         (dl-umbriel-buffer-test--types top)))
          (should (equal '("DP-1:3" "HDMI-A-1:3" nil)
                         (dl-umbriel-buffer-test--values top)))
          ;; Windows nested under the workspace that joined them.
          (should (equal '(umbriel-window umbriel-window)
                         (dl-umbriel-buffer-test--types
                          (dl-umbriel-buffer-test--children (nth 0 top)))))
          (should (equal '("w-abc" "w-def")
                         (dl-umbriel-buffer-test--values
                          (dl-umbriel-buffer-test--children (nth 0 top)))))
          ;; An empty workspace still gets a section, with no windows.
          (should-not (dl-umbriel-buffer-test--children (nth 1 top)))
          ;; The workspace id, not the heading label, is the section value.
          ;; Unassigned holds the unknown- and empty-workspace windows.
          (should (equal '("w-ghost" "w-scratch")
                         (sort (dl-umbriel-buffer-test--values
                                (dl-umbriel-buffer-test--children (nth 2 top)))
                               #'string<))))))))

(ert-deftest dl-umbriel-buffer/workspace-heading-counts-the-join ()
  "VT-1: a workspace heading carries the number of windows the join placed."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (let ((top (dl-umbriel-buffer-test--children)))
          (should (string-match-p "2 windows"
                                  (dl-umbriel-buffer-test--heading (nth 0 top))))
          (should (string-match-p "0 windows"
                                  (dl-umbriel-buffer-test--heading (nth 1 top))))
          (should (string-match-p "Unassigned"
                                  (dl-umbriel-buffer-test--heading (nth 2 top)))))))))

(ert-deftest dl-umbriel-buffer/renders-the-empty-state ()
  "VT-1/EX-1: with nothing held the body is the one empty-state line."
  (dl-umbriel-buffer-test--with-state nil
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (should (equal "No windows or workspaces held.\n"
                       (dl-umbriel-buffer-test--text)))
        (should (eq (oref (dl-umbriel-buffer-test--root) type) 'umbriel-root))
        (should-not (dl-umbriel-buffer-test--children))))))

;;;; header (VT-2, EX-2)

(ert-deftest dl-umbriel-buffer/header-names-the-stream ()
  "VT-2/EX-2: open and never get their sentence, each failure its message."
  (should (equal "umbriel: stream open"
                 (dl-umbriel-buffer--header-text 'open 0)))
  (should (equal "umbriel: stream never opened"
                 (dl-umbriel-buffer--header-text 'never 0)))
  (dolist (kind '(no-path absent refused closed rejected malformed))
    (let* ((failure (list :failure kind (format "%s: test detail" kind)))
           (text (dl-umbriel-buffer--header-text failure 0)))
      (should (stringp text))
      (should (string-prefix-p (format "umbriel: %s" kind) text))
      (should (equal (dl-umbriel-failure-message failure) text))
      (should-not (string-match-p "\n" text)))))

(ert-deftest dl-umbriel-buffer/header-shows-skipped-lines ()
  "VT-2: the skipped count appears only when non-zero, singular for one."
  (let ((none (dl-umbriel-buffer--header-text 'open 0))
        (one (dl-umbriel-buffer--header-text 'open 1))
        (three (dl-umbriel-buffer--header-text 'open 3)))
    (should-not (string-match-p "skipped" none))
    (should (string-prefix-p "umbriel: stream open" one))
    (should (string-match-p "1 line skipped" one))
    (should-not (string-match-p "1 lines skipped" one))
    (should (string-prefix-p "umbriel: stream open" three))
    (should (string-match-p "3 lines skipped" three))))

(ert-deftest dl-umbriel-buffer/header-doubles-percent ()
  "VT-2/EX-2: a compositor `%' is doubled, so the display shows one."
  (let* ((failure (list :failure 'closed "50% of the docs"))
         (text (dl-umbriel-buffer--header-text failure 0)))
    (should (stringp text))
    (should (string-match-p "50%%" text))
    (should (dl-umbriel-buffer-test--percent-pairs-p text))
    (should (equal (dl-umbriel-buffer-test--doubled
                    (dl-umbriel-failure-message failure))
                   text)))
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held nil nil '(:failure closed "50% of the docs") 0)
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        ;; The mode installs `:eval' so the header reads live client state.
        (should (consp header-line-format))
        (should (eq (car header-line-format) :eval))
        (let ((rendered (eval (nth 1 header-line-format) t)))
          (should (stringp rendered))
          (should (string-match-p "50%%" rendered))
          (should-not (string-match-p "50%[^%]" rendered))
          (should (dl-umbriel-buffer-test--percent-pairs-p rendered)))))))

;;;; throttle (VT-3, EX-3)

(ert-deftest dl-umbriel-buffer/throttle-coalesces-state-changes ()
  "VT-3/EX-3/F-11: five changes ride one `run-at-time'; a later one adds one."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (dl-umbriel-buffer-test--with-timers calls
        (dl-umbriel-buffer-test--with-repaint-count repaints
          (dotimes (_ 5)
            (dl-umbriel-buffer--schedule-repaint))
          (should (= 1 (length calls)))
          (let ((call (car calls)))
            (should (equal dl-umbriel-buffer-repaint-delay (nth 0 call)))
            (should (equal 0.1 (nth 0 call)))
            (should-not (nth 1 call))
            (should (eq (nth 2 call) #'dl-umbriel-buffer--repaint-due)))
          ;; Nothing repaints until the timer fires.
          (should (= 0 repaints))
          ;; Displayed: the pending repaint repaints exactly once.
          (set-window-buffer (selected-window) buffer)
          (funcall (nth 2 (car calls)))
          (should (= 1 repaints))
          (should-not dl-umbriel-buffer--repaint-timer)
          ;; A change after the fire schedules exactly one more.
          (dl-umbriel-buffer--schedule-repaint)
          (should (= 2 (length calls)))
          (funcall (nth 2 (car (cdr calls))))
          (should (= 2 repaints)))
        ;; Leave no faked timer behind for the kill hook.
        (setq dl-umbriel-buffer--repaint-timer nil)))))

(ert-deftest dl-umbriel-buffer/throttle-hooks-the-state-changed-hook ()
  "VT-3: the mode adds one hook entry, and one hook run schedules one timer."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (dl-umbriel-buffer-test--mode-buffer)
    ;; Entering the mode again does not add a second entry.
    (dl-umbriel-buffer-test--mode-buffer)
    (should (= 1 (seq-count (lambda (function)
                              (eq function #'dl-umbriel-buffer--schedule-repaint))
                            dl-umbriel-state-changed-hook)))
    (dl-umbriel-buffer-test--with-timers calls
      (dotimes (_ 3)
        (run-hooks 'dl-umbriel-state-changed-hook))
      (should (= 1 (length calls)))
      (should (equal dl-umbriel-buffer-repaint-delay (nth 0 (car calls))))
      (setq dl-umbriel-buffer--repaint-timer nil))))

;;;; point, folds and stale (VT-4, EX-4)

(ert-deftest dl-umbriel-buffer/repaint-keeps-point-across-a-reorder ()
  "VT-4a/EX-4: point stays on the same window section when the row moves."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--order-windows 0 0)
                                    (dl-umbriel-buffer-test--point-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (set-window-buffer (selected-window) buffer)
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (goto-char (oref (dl-umbriel-buffer-test--find 'umbriel-window "w-b")
                         start))
        (should (equal "w-b" (oref (magit-current-section) value)))
        (let ((before (line-number-at-pos)))
          ;; w-b moves from the first row to the last.
          (setq dl-umbriel--state
                (dl-umbriel-buffer-test--held
                 (dl-umbriel-buffer-test--order-windows 3 0)
                 (dl-umbriel-buffer-test--point-workspaces)))
          (dl-umbriel-buffer--repaint)
          (should (equal "w-b" (oref (magit-current-section) value)))
          (should (/= before (line-number-at-pos))))))))

(ert-deftest dl-umbriel-buffer/repaint-keeps-a-non-selected-windows-point ()
  "VT-4b/C-5: a window that does not have the buffer selected keeps its point."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--order-windows 0 0)
                                    (dl-umbriel-buffer-test--point-workspaces))
    (let* ((buffer (dl-umbriel-buffer-test--mode-buffer))
           (other (split-window (selected-window))))
      (set-window-buffer other buffer)
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint))
      (set-window-point other
                        (with-current-buffer buffer
                          (oref (dl-umbriel-buffer-test--find 'umbriel-window "w-b")
                                start)))
      ;; Keep the selected window on another buffer.
      (set-window-buffer (selected-window)
                         (get-buffer-create "*umbriel-test-other*"))
      (should-not (eq (selected-window) other))
      (should (eq (window-buffer other) buffer))
      (setq dl-umbriel--state
            (dl-umbriel-buffer-test--held
             (dl-umbriel-buffer-test--order-windows 3 0)
             (dl-umbriel-buffer-test--point-workspaces)))
      (dl-umbriel-buffer--repaint)
      (let* ((section (with-current-buffer buffer
                        (dl-umbriel-buffer-test--find 'umbriel-window "w-b")))
             (point (window-point other)))
        (should (>= point (oref section start)))
        (should (< point (oref section end)))
        (should (= point (oref section start)))))))

(ert-deftest dl-umbriel-buffer/repaint-keeps-a-folded-workspace-folded ()
  "VT-4c/EX-4: hiding a workspace survives a repaint, through magit's cache."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (let ((before (dl-umbriel-buffer-test--find 'umbriel-workspace "DP-1:3")))
          (magit-section-hide before)
          (should (oref before hidden))
          (dl-umbriel-buffer--repaint)
          (let ((after (dl-umbriel-buffer-test--find 'umbriel-workspace "DP-1:3")))
            (should after)
            (should-not (eq after before))
            (should (oref after hidden))
            ;; R-1: a real fold, not just the slot: the body is invisible
            ;; and the heading is not.
            (let ((child (car (dl-umbriel-buffer-test--children after))))
              (should child)
              (should (invisible-p (oref child start)))
              (should (invisible-p (oref after content)))
              (should-not (invisible-p (oref after start))))))))))

(ert-deftest dl-umbriel-buffer/undisplayed-buffer-goes-stale ()
  "VT-4d/C-6: a repaint due while nothing shows the buffer only marks it."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (should-not (get-buffer-window buffer t))
      (let ((text (with-current-buffer buffer
                    (dl-umbriel-buffer-test--text))))
        (dl-umbriel-buffer-test--with-timers calls
          (dl-umbriel-buffer-test--with-repaint-count repaints
            (dl-umbriel-buffer--repaint-due)
            (should (= 0 repaints))
            (should (buffer-local-value 'dl-umbriel-buffer--stale buffer))
            (should (local-variable-p 'dl-umbriel-buffer--stale buffer))
            ;; Marking stale does not edit the buffer.
            (should (equal text (with-current-buffer buffer
                                  (dl-umbriel-buffer-test--text)))))
          (should-not calls)
          (setq dl-umbriel-buffer--repaint-timer nil))))))

(ert-deftest dl-umbriel-buffer/display-hook-schedules-without-editing ()
  "VT-4d/C-7: showing a stale buffer schedules; only the timer repaints."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint-due))
      (should (buffer-local-value 'dl-umbriel-buffer--stale buffer))
      (let ((text (with-current-buffer buffer
                    (dl-umbriel-buffer-test--text))))
        (dl-umbriel-buffer-test--with-timers calls
          (let ((window (selected-window)))
            (set-window-buffer window buffer)
            (should (local-variable-p 'window-buffer-change-functions buffer))
            (let ((entry (seq-find
                          (lambda (function)
                            (eq function #'dl-umbriel-buffer--on-display))
                          (buffer-local-value 'window-buffer-change-functions
                                              buffer))))
              (should entry)
              ;; The display engine runs the hook with the buffer current.
              (dl-umbriel-buffer-test--with-repaint-count repaints
                (with-current-buffer buffer
                  (funcall entry window))
                (should (= 1 (length calls)))
                (should (= 0 repaints))
                (should (equal text (with-current-buffer buffer
                                      (dl-umbriel-buffer-test--text)))))))
          ;; Firing the scheduled repaint renders once and clears stale.
          (funcall (nth 2 (car calls)))
          (with-current-buffer buffer
            ;; Rendered now: the row is a section whose value is the id.
            (should-not (equal "" (dl-umbriel-buffer-test--text)))
            (should (dl-umbriel-buffer-test--find 'umbriel-window "w-abc"))
            (should-not (buffer-local-value 'dl-umbriel-buffer--stale buffer)))
          (setq dl-umbriel-buffer--repaint-timer nil))))))

;;;; no connection (VT-5, EX-5, F-14)

(ert-deftest dl-umbriel-buffer/mode-and-render-never-connect ()
  "VT-5/EX-5: the mode, the render path and the header open no stream."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (should (equal dl-umbriel-buffer-test--socket (getenv "UMBRIEL_SOCKET")))
    (should-not (getenv "WAYLAND_DISPLAY"))
    (let ((forbidden (lambda (&rest _)
                       (ert-fail "the display path opened a stream")))
          (buffer-nil (get-buffer-create dl-umbriel-buffer-name)))
      (unwind-protect
          (cl-letf (((symbol-function 'dl-umbriel-stream-open) forbidden)
                    ((symbol-function 'make-network-process) forbidden))
            (with-current-buffer buffer-nil
              (dl-umbriel-buffer-mode)
              (let ((inhibit-read-only t))
                (erase-buffer)
                (dl-umbriel-buffer--insert (dl-umbriel-workspaces)
                                           (dl-umbriel-windows)))
              (dl-umbriel-buffer--repaint)
              ;; The header pass, over every status the client can hold.
              (dolist (status (list 'open 'never
                                    (list :failure 'rejected "nope")))
                (setq dl-umbriel--state
                      (dl-umbriel-buffer-test--held
                       (dl-umbriel-buffer-test--fixture-windows)
                       (dl-umbriel-buffer-test--fixture-workspaces)
                       status 2))
                (should (stringp (dl-umbriel-buffer--header-text
                                  (dl-umbriel-stream-status)
                                  (dl-umbriel-skipped))))
                (should (stringp (eval (nth 1 header-line-format) t))))))
        (when (buffer-live-p buffer-nil)
          (kill-buffer buffer-nil))))
    ;; The counting stubs saw nothing either.
    (should-not dl-umbriel-buffer-test--stream-log)))

;;;; lifecycle (VT-6, EX-7, F-2)

(ert-deftest dl-umbriel-buffer/my-umbriel-opens-once-and-kill-closes-once ()
  "VT-6/EX-7: creating opens once; bury, quit and re-invoke keep it."
  (dl-umbriel-buffer-test--with-state nil
    (dl-umbriel-buffer-test--with-timers calls
      (my/umbriel)
      (should (= 1 (dl-umbriel-buffer-test--count 'open)))
      (let ((buffer (get-buffer dl-umbriel-buffer-name)))
        (should buffer)
        (should (eq (buffer-local-value 'major-mode buffer)
                    'dl-umbriel-buffer-mode))
        (should (get-buffer-window buffer t))
        ;; C-9/D-1: the kill hook is buffer-local, never a global default.
        (should (memq #'dl-umbriel-buffer--on-kill
                      (buffer-local-value 'kill-buffer-hook buffer)))
        (should-not (memq #'dl-umbriel-buffer--on-kill
                          (default-value 'kill-buffer-hook)))
        ;; Re-invoking opens nothing more.
        (my/umbriel)
        (should (= 1 (dl-umbriel-buffer-test--count 'open)))
        ;; Burying keeps the connection.
        (bury-buffer buffer)
        (should (buffer-live-p buffer))
        (should (= 0 (dl-umbriel-buffer-test--count 'close)))
        ;; Quitting its window keeps it too.
        (my/umbriel)
        (quit-window)
        (should (= 0 (dl-umbriel-buffer-test--count 'close)))
        (should (= 1 (dl-umbriel-buffer-test--count 'open)))
        ;; Killing an unrelated buffer is not our business.
        (kill-buffer (get-buffer-create "*umbriel-test-unrelated*"))
        (should (= 0 (dl-umbriel-buffer-test--count 'close)))
        ;; Killing *umbriel* closes exactly once.
        (kill-buffer buffer)
        (should (= 1 (dl-umbriel-buffer-test--count 'close))))
      (should-not calls))))

(ert-deftest dl-umbriel-buffer/refresh-reconnects-only-when-shut ()
  "VT-6/C-10: `g' repaints when the stream is open, reconnects when not."
  (dl-umbriel-buffer-test--with-state (dl-umbriel-buffer-test--held nil nil 'open 0)
    (dl-umbriel-buffer-test--mode-buffer)
    (dl-umbriel-buffer-test--with-timers calls
      (dl-umbriel-buffer-test--with-repaint-count repaints
        (cl-letf (((symbol-function 'dl-umbriel-send)
                   (lambda (&rest _)
                     (ert-fail "refresh on an open stream sent a request"))))
          (my/umbriel-refresh))
        (should (= 1 repaints))
        (should (= 0 (dl-umbriel-buffer-test--count 'open))))
      (setq dl-umbriel-buffer--repaint-timer nil)))
  (dolist (status (list 'never (list :failure 'closed "x")))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held nil nil status 0)
      (dl-umbriel-buffer-test--mode-buffer)
      (dl-umbriel-buffer-test--with-timers calls
        (my/umbriel-refresh)
        (should (= 1 (dl-umbriel-buffer-test--count 'open)))
        (should (= 0 (dl-umbriel-buffer-test--count 'close)))
        (setq dl-umbriel-buffer--repaint-timer nil)))))

(ert-deftest dl-umbriel-buffer/g-refreshes ()
  "VT-6/C-11: `g' in the buffer map is `my/umbriel-refresh'."
  (should (eq (lookup-key dl-umbriel-buffer-mode-map "g")
              #'my/umbriel-refresh)))

(ert-deftest dl-umbriel-buffer/mode-and-constants ()
  "C-1/C-2: the buffer name, the repaint delay and the mode's parent."
  (dl-umbriel-buffer-test--with-state nil
    (should (equal "*umbriel*" dl-umbriel-buffer-name))
    (should (equal 0.1 dl-umbriel-buffer-repaint-delay))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (with-current-buffer buffer
        (should (eq major-mode 'dl-umbriel-buffer-mode))
        (should (derived-mode-p 'magit-section-mode))
        (should (local-variable-p 'window-buffer-change-functions))
        (should (eq (car-safe header-line-format) :eval))))))

;;;; pending timers and a dead buffer (C-6, C-9)

(ert-deftest dl-umbriel-buffer/kill-cancels-a-pending-repaint ()
  "C-9: killing *umbriel* cancels its pending repaint, exactly once."
  (dl-umbriel-buffer-test--with-state nil
    (let ((fake (list 'fake-timer))
          (cancelled nil))
      (my/umbriel)
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (&rest _) fake))
                ((symbol-function 'cancel-timer)
                 (lambda (timer) (push timer cancelled))))
        (dl-umbriel-buffer--schedule-repaint)
        (should (eq fake dl-umbriel-buffer--repaint-timer))
        (kill-buffer (get-buffer dl-umbriel-buffer-name))
        (should (equal (list fake) cancelled))
        (should-not dl-umbriel-buffer--repaint-timer)
        (should (= 1 (dl-umbriel-buffer-test--count 'close)))))))

(ert-deftest dl-umbriel-buffer/repaint-due-after-kill-is-harmless ()
  "C-6: a repaint due after the buffer died does nothing and signals nothing."
  (dl-umbriel-buffer-test--with-state nil
    (let ((fake (list 'fake-timer))
          (due nil))
      (my/umbriel)
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (_time _repeat function &rest _)
                   (setq due function)
                   fake))
                ((symbol-function 'cancel-timer)
                 (lambda (&rest _) nil)))
        (dl-umbriel-buffer--schedule-repaint)
        (should due)
        (kill-buffer (get-buffer dl-umbriel-buffer-name))
        (should-not (get-buffer dl-umbriel-buffer-name))
        (dl-umbriel-buffer-test--with-repaint-count repaints
          (funcall due)
          (should (= 0 repaints))
          (should-not dl-umbriel-buffer--repaint-timer))))))

(ert-deftest dl-umbriel-buffer/no-buffer-schedules-nothing ()
  "C-6: with no *umbriel* buffer live, scheduling does nothing."
  (dl-umbriel-buffer-test--with-state nil
    (should-not (get-buffer dl-umbriel-buffer-name))
    (let ((calls 0))
      (cl-letf (((symbol-function 'run-at-time)
                 (lambda (&rest _)
                   (cl-incf calls)
                   (list 'fake-timer))))
        (dl-umbriel-buffer--schedule-repaint)
        (should (= 0 calls))
        (should-not dl-umbriel-buffer--repaint-timer)))))

;;;; review fixes (T-3..T-6)

(ert-deftest dl-umbriel-buffer/kill-cancels-after-the-close-announces ()
  "T-3/R-4: the close may run the state hook; the kill still cancels last.
A real `dl-umbriel-stream-close' announces, so a kill that closed first
would see the hook arm a fresh timer; cancelling afterwards leaves none."
  (dl-umbriel-buffer-test--with-state nil
    (let ((fake (list 'fake-timer))
          (events nil))
      (cl-letf (((symbol-function 'dl-umbriel-stream-close)
                 (lambda (&rest _)
                   (push 'close dl-umbriel-buffer-test--stream-log)
                   (push 'close events)
                   (run-hooks 'dl-umbriel-state-changed-hook)))
                ((symbol-function 'run-at-time)
                 (lambda (&rest _)
                   (push 'arm events)
                   fake))
                ((symbol-function 'cancel-timer)
                 (lambda (&rest _) (push 'cancel events))))
        (my/umbriel)
        (dl-umbriel-buffer--schedule-repaint)
        (should (eq fake dl-umbriel-buffer--repaint-timer))
        (setq events nil)
        (kill-buffer (get-buffer dl-umbriel-buffer-name))
        (setq events (nreverse events))
        (should (memq 'close events))
        (should (memq 'cancel events))
        (should-not (memq 'arm (cdr (memq 'cancel events))))
        (should-not dl-umbriel-buffer--repaint-timer)
        (should (= 1 (dl-umbriel-buffer-test--count 'close)))))))

(ert-deftest dl-umbriel-buffer/repaint-unmodifies-and-highlights ()
  "T-4/R-2/R-3: a repaint leaves no modification and re-highlights point."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--fixture-windows)
                                    (dl-umbriel-buffer-test--fixture-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (set-window-buffer (selected-window) buffer)
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (goto-char (oref (dl-umbriel-buffer-test--find 'umbriel-window "w-abc")
                         start))
        (dl-umbriel-buffer--repaint)
        (should (equal "w-abc" (oref (magit-current-section) value)))
        (should-not (buffer-modified-p))
        ;; The erase threw the old highlight away; the repaint puts it back.
        (should magit-section-highlight-overlays)
        (should (seq-some (lambda (overlay)
                            (and (eq (overlay-get overlay 'font-lock-face)
                                     'magit-section-highlight)
                                 (<= (overlay-start overlay) (point))
                                 (<= (point) (overlay-end overlay))))
                          magit-section-highlight-overlays))))))

(ert-deftest dl-umbriel-buffer/repaint-keeps-the-window-start ()
  "T-5/R-5: a repaint leaves the window showing the same top section."
  (dl-umbriel-buffer-test--with-state
      (dl-umbriel-buffer-test--held (dl-umbriel-buffer-test--tall-windows)
                                    (dl-umbriel-buffer-test--point-workspaces))
    (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
      (set-window-buffer (selected-window) buffer)
      (with-current-buffer buffer
        (dl-umbriel-buffer--repaint)
        (let* ((rows (dl-umbriel-buffer-test--children
                      (dl-umbriel-buffer-test--find 'umbriel-workspace "DP-1:3")))
               (top (nth 5 rows))
               (value (oref top value)))
          (should (> (length rows) (window-height)))
          (set-window-start (selected-window) (oref top start))
          (should (= (window-start) (oref top start)))
          (goto-char (oref (nth 7 rows) start))
          (should (> (window-point) (window-start)))
          ;; Grow the tree below the window start: the top row is unchanged.
          (setq dl-umbriel--state
                (dl-umbriel-buffer-test--held
                 (dl-umbriel-buffer-test--tall-windows 3)
                 (dl-umbriel-buffer-test--point-workspaces)))
          (dl-umbriel-buffer--repaint)
          (let ((after (dl-umbriel-buffer-test--find 'umbriel-window value)))
            (should after)
            (should (= (window-start) (oref after start)))
            (should (equal value (oref (magit-section-at (window-start))
                                       value)))))))))

(ert-deftest dl-umbriel-buffer/leaves-a-foreign-buffer-alone ()
  "T-6/R-6: a buffer that merely bears the name is never drawn into."
  (dl-umbriel-buffer-test--with-state nil
    (let ((foreign (get-buffer-create dl-umbriel-buffer-name)))
      (with-current-buffer foreign
        (insert "not umbriel\n"))
      (dl-umbriel-buffer--repaint)
      (with-current-buffer foreign
        (should (equal "not umbriel\n" (dl-umbriel-buffer-test--text)))
        (should-not (eq major-mode 'dl-umbriel-buffer-mode)))
      (dl-umbriel-buffer-test--with-timers calls
        (dl-umbriel-buffer--schedule-repaint)
        (should-not calls)))))

;;; dl-umbriel-buffer-test.el ends here
