;;; dl-umbriel-buffer-test.el --- ert tests for the *umbriel* buffer -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-umbriel-buffer/ RET.
;;
;; Contract: .doctrine/slice/016/design.md § The buffer and § Actions, and the
;; phase sheets phase-04.md (C-1..C-12, EX-1..EX-7) and phase-05.md
;; (VT-1..VT-5, EX-1..EX-7, D-1..D-8).
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

;;;; actions (PHASE-05)
;;
;; Contract: .doctrine/state/slice/016/phases/phase-05.md (Contract, Gates,
;; D-1..D-8) and design.md sections Actions and Keys.
;;
;; Nothing here reaches a socket either.  Where a test only wants the plan a
;; command built, `dl-umbriel-send-all' is faked; where a test wants the real
;; sequencer, `dl-umbriel-send' is faked in its place.  `--with-state' already
;; points UMBRIEL_SOCKET at a path nothing listens on.

;;;; actions: fixtures

(defun dl-umbriel-buffer-test--action-workspaces ()
  "Three workspaces on two outputs, the DP-1 one the focused one."
  (list (dl-umbriel-buffer-test--workspace :id "DP-1:1" :index 1 :name "web"
                                           :output "DP-1" :focused t)
        (dl-umbriel-buffer-test--workspace :id "DP-1:2" :index 2 :name nil
                                           :named nil :output "DP-1")
        (dl-umbriel-buffer-test--workspace :id "DP-2:1" :index 1 :name "docs"
                                           :output "DP-2")))

(defun dl-umbriel-buffer-test--action-windows ()
  "One window per output, and one whose workspace joins nothing."
  (list (dl-umbriel-buffer-test--window :id "w-dp1" :workspace "DP-1:1"
                                        :app_id "foot" :title "shell")
        (dl-umbriel-buffer-test--window :id "w-dp2" :workspace "DP-2:1"
                                        :app_id "emacs" :title "notes")
        (dl-umbriel-buffer-test--window :id "w-loose" :workspace "DP-9:9"
                                        :app_id "firefox" :title "Docs")))

(defun dl-umbriel-buffer-test--action-workspaces-focusing (id)
  "The action workspaces, the focused one's `focused_window' set to ID.
ID is stored as given: a window id, \"\" or nil.  The plain action
workspaces carry no `focused_window' at all, which DEC-025 reads as
unknown."
  (mapcar (lambda (workspace)
            (if (alist-get 'focused workspace)
                (cons (cons 'focused_window id)
                      (assq-delete-all 'focused_window workspace))
              workspace))
          (dl-umbriel-buffer-test--action-workspaces)))

(defconst dl-umbriel-buffer-test--action-table
  '((my/umbriel-focus "window-focus" window)
    (my/umbriel-toggle-floating "window-toggle-floating" window)
    (my/umbriel-kill "window-kill" window confirm-kill)
    (my/umbriel-center "window-center" focused)
    (my/umbriel-cycle-extent "window-cycle-primary-extent" focused)
    (my/umbriel-cycle-extent-back "window-cycle-primary-extent-back" focused)
    (my/umbriel-column-left "column-move-left" focused)
    (my/umbriel-column-right "column-move-right" focused)
    (my/umbriel-scroll-left "layout-scroll-left" focused)
    (my/umbriel-scroll-right "layout-scroll-right" focused)
    (my/umbriel-move-to-workspace "window-move-to-workspace-silent" focused
                                  workspace)
    (my/umbriel-switch "workspace-switch" workspace)
    (my/umbriel-set-layout "workspace-set-layout" active-workspace layout))
  "The design's action table, as this file expects it to be held.
DEC-025: moving a window to a workspace goes silently, so the plan's
own focus steps are the only ones the user sees.")

;;;; actions: helpers

(defun dl-umbriel-buffer-test--hold (windows workspaces &optional status skipped)
  "Replace the held state with WINDOWS, WORKSPACES, STATUS and SKIPPED."
  (setq dl-umbriel--state
        (dl-umbriel-buffer-test--held windows workspaces status skipped)))

(defun dl-umbriel-buffer-test--spec (addressing action &optional prompt)
  "A table row for ACTION with ADDRESSING, prompting with PROMPT if given."
  (append (list 'test-command action addressing)
          (when prompt (list prompt))))

(defun dl-umbriel-buffer-test--mentions-p (text needle)
  "Non-nil when TEXT mentions NEEDLE, ignoring case."
  (and (stringp text)
       (let ((case-fold-search t))
         (string-match-p (regexp-quote needle) text))))

(defun dl-umbriel-buffer-test--refused (spec target fields workspaces)
  "The refusal `dl-umbriel-buffer--plan' gives SPEC for TARGET.
Fails unless the answer is a string and the same string whether FIELDS
is given or nil: a refusal may not depend on FIELDS (D-3)."
  (let ((with (dl-umbriel-buffer--plan spec target fields workspaces))
        (without (dl-umbriel-buffer--plan spec target nil workspaces)))
    (should (stringp with))
    (should (equal with without))
    with))

(defun dl-umbriel-buffer-test--offered (collection)
  "The strings COLLECTION offers, whether it holds strings or pairs."
  (all-completions "" collection))

(defun dl-umbriel-buffer-test--metadata (collection key)
  "What COLLECTION's completion metadata says under KEY.
COLLECTION must be a completion-table function: vertico reads its
`metadata' action and prefers it over `vertico-sort-function', which an
alist or a plain list of strings cannot answer at all."
  (unless (functionp collection)
    (ert-fail (format "the prompt's collection is not a completion table: %S"
                      collection)))
  (alist-get key (funcall collection "" nil 'metadata)))

(defun dl-umbriel-buffer-test--same-set-p (one other)
  "Non-nil when lists ONE and OTHER hold the same elements, in any order."
  (and (null (seq-difference one other))
       (null (seq-difference other one))))

(defun dl-umbriel-buffer-test--switches-p (result)
  "Non-nil when RESULT is a request list holding a `workspace-switch'."
  (and (listp result)
       (seq-some (lambda (request)
                   (equal (alist-get 'action request) "workspace-switch"))
                 result)))

(defun dl-umbriel-buffer-test--call-on-row (command type value)
  "Call COMMAND with point on the TYPE section whose value is VALUE."
  (let ((section (dl-umbriel-buffer-test--find type value)))
    (unless section
      (ert-fail (format "no %s section whose value is %S" type value)))
    (goto-char (oref section start))
    (call-interactively command)))

;;;; actions: isolation

(defvar dl-umbriel-buffer-test--send-all-calls nil
  "Calls to the faked `dl-umbriel-send-all', newest first: (PLAN . CALLBACK).")

(defvar dl-umbriel-buffer-test--refreshes nil
  "Calls to the faked `dl-umbriel-refresh', newest first: CALLBACK.")

(defvar dl-umbriel-buffer-test--prompts nil
  "Prompt calls, newest first: (KIND PROMPT COLLECTION REQUIRE-MATCH).")

(defvar dl-umbriel-buffer-test--prompt-choice nil
  "What the faked `completing-read' answers.")

(defvar dl-umbriel-buffer-test--prompt-confirm t
  "What the faked `y-or-n-p' answers.")

(defvar dl-umbriel-buffer-test--prompt-hook nil
  "Function the faked prompts call before answering, or nil.")

(defvar dl-umbriel-buffer-test--prompt-allowed t
  "When nil, a faked prompt fails the test instead of answering.")

(defvar dl-umbriel-buffer-test--messages nil
  "Messages the faked `message' recorded, newest first.")

(defvar dl-umbriel-buffer-test--fake-timers nil
  "The timers `--with-scheduled' faked for the code under test.")

(defun dl-umbriel-buffer-test--prompting (kind prompt &optional c match)
  "Record a prompt of KIND for PROMPT, C and MATCH; fail when none may run."
  (unless dl-umbriel-buffer-test--prompt-allowed
    (ert-fail (format "%s ran where no prompt may run: %s" kind prompt)))
  (when dl-umbriel-buffer-test--prompt-hook
    (funcall dl-umbriel-buffer-test--prompt-hook))
  (push (list kind prompt c match) dl-umbriel-buffer-test--prompts))

(defmacro dl-umbriel-buffer-test--with-send-all (&rest body)
  "Run BODY with `dl-umbriel-send-all' capturing instead of sending.
The calls land in `--send-all-calls'.  `dl-umbriel-send' and
`make-network-process' fail the test, so no request can leave."
  (declare (indent 0))
  `(let ((dl-umbriel-buffer-test--send-all-calls nil))
     (cl-letf (((symbol-function 'dl-umbriel-send-all)
                (lambda (plan callback)
                  (push (cons plan callback)
                        dl-umbriel-buffer-test--send-all-calls)))
               ((symbol-function 'dl-umbriel-send)
                (lambda (&rest _)
                  (ert-fail "a request bypassed `dl-umbriel-send-all'")))
               ((symbol-function 'make-network-process)
                (lambda (&rest _)
                  (ert-fail "a test opened a socket"))))
       ,@body)))

(defmacro dl-umbriel-buffer-test--with-refresh (&rest body)
  "Run BODY with `dl-umbriel-refresh' recording its callbacks in `--refreshes'."
  (declare (indent 0))
  `(let ((dl-umbriel-buffer-test--refreshes nil))
     (cl-letf (((symbol-function 'dl-umbriel-refresh)
                (lambda (&optional callback)
                  (push callback dl-umbriel-buffer-test--refreshes)
                  nil)))
       ,@body)))

(defmacro dl-umbriel-buffer-test--with-fake-status (variable &rest body)
  "Run BODY with `dl-umbriel-stream-status' answering VARIABLE's value."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'dl-umbriel-stream-status)
              (lambda () ,variable)))
     ,@body))

(defmacro dl-umbriel-buffer-test--with-messages (&rest body)
  "Run BODY with `message' recorded in `--messages' instead of shown."
  (declare (indent 0))
  `(let ((dl-umbriel-buffer-test--messages nil))
     (cl-letf (((symbol-function 'message)
                (lambda (format-string &rest args)
                  (push (condition-case nil
                            (apply #'format format-string args)
                          (error format-string))
                        dl-umbriel-buffer-test--messages)
                  nil)))
       ,@body)))

(defmacro dl-umbriel-buffer-test--with-prompts (&rest body)
  "Run BODY with the prompting functions faked.
`completing-read' answers `--prompt-choice', `y-or-n-p' answers
`--prompt-confirm', and the `read-' family answers "".  Each records
its arguments in `--prompts' and calls `--prompt-hook' first.  With
`--prompt-allowed' nil a prompt fails the test instead: that is how a
callback or a timer is checked for never prompting."
  (declare (indent 0))
  `(let ((dl-umbriel-buffer-test--prompts nil)
         (dl-umbriel-buffer-test--prompt-choice nil)
         (dl-umbriel-buffer-test--prompt-confirm t)
         (dl-umbriel-buffer-test--prompt-hook nil)
         (dl-umbriel-buffer-test--prompt-allowed t))
     (cl-letf (((symbol-function 'completing-read)
                (lambda (prompt collection &optional _predicate require-match
                                 &rest _)
                  (dl-umbriel-buffer-test--prompting 'completing-read prompt
                                                     collection require-match)
                  dl-umbriel-buffer-test--prompt-choice))
               ((symbol-function 'y-or-n-p)
                (lambda (prompt)
                  (dl-umbriel-buffer-test--prompting 'y-or-n-p prompt)
                  dl-umbriel-buffer-test--prompt-confirm))
               ((symbol-function 'read-string)
                (lambda (prompt &rest _)
                  (dl-umbriel-buffer-test--prompting 'read-string prompt)
                  ""))
               ((symbol-function 'read-from-minibuffer)
                (lambda (prompt &rest _)
                  (dl-umbriel-buffer-test--prompting 'read-from-minibuffer prompt)
                  ""))
               ((symbol-function 'read-number)
                (lambda (prompt &rest _)
                  (dl-umbriel-buffer-test--prompting 'read-number prompt)
                  0)))
       ,@body)))

(defmacro dl-umbriel-buffer-test--with-scheduled (calls &rest body)
  "Run BODY with CALLS collecting the timers the code under test schedules.
A `run-at-time' with a delay of 0 and no repeat -- how a reply leaves a
process callback -- is recorded in CALLS as `(TIME REPEAT FUNCTION
ARGS)' and answered with a faked timer.  Every other call, the repaint
throttle included, goes to the original function; `cancel-timer' forgets
our timers and passes foreign ones through."
  (declare (indent 1))
  `(let ((,calls nil)
         (dl-umbriel-buffer-test--fake-timers nil)
         (orig-at-time (symbol-function 'run-at-time))
         (orig-cancel (symbol-function 'cancel-timer)))
     (cl-letf (((symbol-function 'run-at-time)
                (lambda (time repeat function &rest args)
                  (if (and (null repeat) (equal time 0))
                      (let ((timer (list 'fake-timer time repeat)))
                        (push (list time repeat function args) ,calls)
                        (push timer dl-umbriel-buffer-test--fake-timers)
                        timer)
                    (apply orig-at-time time repeat function args))))
               ((symbol-function 'cancel-timer)
                (lambda (timer)
                  (if (memq timer dl-umbriel-buffer-test--fake-timers)
                      nil
                    (funcall orig-cancel timer)))))
       ,@body)))

;;;; actions: the plan (VT-1, EX-1, D-1..D-3)

(ert-deftest dl-umbriel-buffer/plan-window-addressing ()
  "VT-1/EX-1: `window' acts on the row's id and refuses a workspace row."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (window (nth 0 windows))
         (loose (nth 2 windows))
         (id (alist-get 'id window))
         (spec (dl-umbriel-buffer-test--spec 'window "window-toggle-floating"))
         (fields '((quiet . t)))
         (expected (lambda (window-id extra)
                     (list (dl-umbriel-action
                            "window-toggle-floating"
                            (append (list (cons 'window window-id)) extra))))))
    (should (equal (funcall expected id fields)
                   (dl-umbriel-buffer--plan spec (list :window window) fields
                                            workspaces)))
    (should (equal (funcall expected id nil)
                   (dl-umbriel-buffer--plan spec (list :window window) nil
                                            workspaces)))
    ;; An Unassigned window is still a window: the id addresses it.
    (should (equal (funcall expected (alist-get 'id loose) nil)
                   (dl-umbriel-buffer--plan spec (list :window loose) nil
                                            workspaces)))
    ;; `my/umbriel-focus' on a window row is exactly one request.
    (should (equal (list (dl-umbriel-action "window-focus"
                                            (list (cons 'window id))))
                   (dl-umbriel-buffer--plan
                    (dl-umbriel-buffer-test--spec 'window "window-focus")
                    (list :window window) nil workspaces)))
    ;; A workspace row is not a window.
    (let ((refusal (dl-umbriel-buffer-test--refused
                    spec (list :workspace (nth 0 workspaces)) fields workspaces)))
      (should (dl-umbriel-buffer-test--mentions-p refusal "not a window")))))

(ert-deftest dl-umbriel-buffer/plan-focused-addressing ()
  "VT-1/EX-1: `focused' focuses the row's window first; a workspace row acts."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (window (nth 0 windows))
         (loose (nth 2 windows))
         (spec (dl-umbriel-buffer-test--spec 'focused "window-center"))
         (fields '((step . 1))))
    (should (equal (list (dl-umbriel-action "window-focus"
                                            (list (cons 'window (alist-get 'id window))))
                         (dl-umbriel-action "window-center" fields))
                   (dl-umbriel-buffer--plan spec (list :window window) fields
                                            workspaces)))
    (should (equal (list (dl-umbriel-action
                          "window-focus"
                          (list (cons 'window (alist-get 'id loose))))
                         (dl-umbriel-action "window-center" nil))
                   (dl-umbriel-buffer--plan spec (list :window loose) nil
                                            workspaces)))
    (should (equal (list (dl-umbriel-action "window-center" fields))
                   (dl-umbriel-buffer--plan spec
                                            (list :workspace (nth 0 workspaces))
                                            fields workspaces)))
    (should (equal (list (dl-umbriel-action "window-center" nil))
                   (dl-umbriel-buffer--plan spec
                                            (list :workspace (nth 0 workspaces))
                                            nil workspaces)))))

(ert-deftest dl-umbriel-buffer/plan-workspace-addressing ()
  "VT-1/EX-1: `workspace' switches by selector; an Unassigned window refuses."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (window (nth 0 windows))
         (loose (nth 2 windows))
         (spec (dl-umbriel-buffer-test--spec 'workspace "workspace-switch"))
         (its (dl-umbriel-model-window-workspace workspaces window)))
    (should its)
    (should (equal (list (dl-umbriel-action
                          "workspace-switch"
                          (dl-umbriel-model-workspace-selector its)))
                   (dl-umbriel-buffer--plan spec (list :window window) nil
                                            workspaces)))
    (should (equal (list (dl-umbriel-action
                          "workspace-switch"
                          (dl-umbriel-model-workspace-selector (nth 1 workspaces))))
                   (dl-umbriel-buffer--plan spec
                                            (list :workspace (nth 1 workspaces))
                                            nil workspaces)))
    ;; The switch request carries the selector and nothing else.
    (should (equal (list (dl-umbriel-action
                          "workspace-switch"
                          (dl-umbriel-model-workspace-selector its)))
                   (dl-umbriel-buffer--plan spec (list :window window)
                                            '((layout . "master")) workspaces)))
    (let ((refusal (dl-umbriel-buffer-test--refused
                    spec (list :window loose) nil workspaces)))
      (should (dl-umbriel-buffer-test--mentions-p refusal "no workspace")))))

(ert-deftest dl-umbriel-buffer/plan-active-workspace-addressing ()
  "VH-1 Fix 1: `active-workspace' switches there, unless that is the
focused workspace, in which case it only acts.  Switching to a workspace
umbriel already holds active on its output toggles back to the previous
one when the user sets `back_and_forth', so the layout would land on the
wrong workspace."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (focused (nth 0 workspaces))
         (other (nth 1 workspaces))
         (window (nth 0 windows))
         (its (dl-umbriel-model-window-workspace workspaces window))
         (spec (dl-umbriel-buffer-test--spec 'active-workspace
                                             "workspace-set-layout" 'layout))
         (fields '((layout . "master"))))
    (should its)
    ;; Window 0 sits on the focused DP-1:1: act, do not switch.
    (should (equal (alist-get 'id focused) (alist-get 'id its)))
    (should (equal (list (dl-umbriel-action "workspace-set-layout" fields))
                   (dl-umbriel-buffer--plan spec (list :window window) fields
                                            workspaces)))
    ;; A workspace row on another workspace of the same output switches.
    (should (equal (list (dl-umbriel-action
                          "workspace-switch"
                          (dl-umbriel-model-workspace-selector other))
                         (dl-umbriel-action "workspace-set-layout" fields))
                   (dl-umbriel-buffer--plan spec (list :workspace other)
                                            fields workspaces)))
    (let ((refusal (dl-umbriel-buffer-test--refused
                    spec (list :window (nth 2 windows)) fields workspaces)))
      (should (dl-umbriel-buffer-test--mentions-p refusal "no workspace")))))

(ert-deftest dl-umbriel-buffer/plan-active-workspace-on-the-focused-row ()
  "VH-1 Fix 1: a `:workspace' row of the focused workspace plans [ACT] alone."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (focused (dl-umbriel-buffer--focused-workspace workspaces))
         (spec (dl-umbriel-buffer-test--spec 'active-workspace
                                             "workspace-set-layout" 'layout))
         (fields '((layout . "master"))))
    (should focused)
    (dolist (given (list fields nil))
      (let ((plan (dl-umbriel-buffer--plan spec (list :workspace focused) given
                                           workspaces)))
        (should (equal (list (dl-umbriel-action "workspace-set-layout" given))
                       plan))
        (should-not (dl-umbriel-buffer-test--switches-p plan))))))

(ert-deftest dl-umbriel-buffer/plan-workspace-addressing-switches-the-focused-row ()
  "VH-1 Fix 1: `workspace' addressing is unchanged; it always switches,
the focused workspace included (user ruling)."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (focused (nth 0 workspaces))
         (spec (dl-umbriel-buffer-test--spec 'workspace "workspace-switch")))
    (dolist (target (list (list :workspace focused)
                          (list :window (nth 0 windows))))
      (let ((plan (dl-umbriel-buffer--plan spec target nil workspaces)))
        (should (equal (list (dl-umbriel-action
                              "workspace-switch"
                              (dl-umbriel-model-workspace-selector focused)))
                       plan))
        (should (dl-umbriel-buffer-test--switches-p plan))))))

(ert-deftest dl-umbriel-buffer/plan-layout-refuses-a-foreign-output ()
  "VT-2/EX-2/RV-018 F-6: a layout off the pointer's output is refused.
The refusal is a string with no requests in it -- never a partial plan."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (dp2 (nth 2 workspaces))
         (spec (dl-umbriel-buffer-test--spec 'active-workspace
                                             "workspace-set-layout" 'layout))
         (fields '((layout . "master"))))
    (dolist (target (list (list :workspace dp2)
                          (list :window (nth 1 windows))))
      (let ((result (dl-umbriel-buffer-test--refused
                     spec target fields workspaces)))
        (should (dl-umbriel-buffer-test--mentions-p
                 result "layout acts on the output under the pointer"))
        (should-not (dl-umbriel-buffer-test--switches-p result))))
    ;; The same output is fine: switch first, then set the layout.
    (should (equal (list (dl-umbriel-action
                          "workspace-switch"
                          (dl-umbriel-model-workspace-selector (nth 1 workspaces)))
                         (dl-umbriel-action "workspace-set-layout" fields))
                   (dl-umbriel-buffer--plan spec
                                            (list :workspace (nth 1 workspaces))
                                            fields workspaces)))
    ;; D-2: nothing is marked focused, so the output cannot be checked.
    (let* ((unfocused
            (list (dl-umbriel-buffer-test--workspace :id "DP-1:1" :index 1
                                                     :output "DP-1")
                  (dl-umbriel-buffer-test--workspace :id "DP-1:2" :index 2
                                                     :output "DP-1")))
           (result (dl-umbriel-buffer-test--refused
                    spec (list :workspace (nth 0 unfocused))
                    fields unfocused)))
      (should (dl-umbriel-buffer-test--mentions-p
               result "layout acts on the output under the pointer"))
      (should-not (dl-umbriel-buffer-test--switches-p result)))))

(ert-deftest dl-umbriel-buffer/plan-restores-focus-after-acting ()
  "DEC-025: a `focused' plan on a window row ends by restoring PREVIOUS.
PREVIOUS is the focused workspace's `focused_window'; FIELDS belong to
the action, never to the restore, and the loose window restores too."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces-focusing
                      "w-dp2"))
         (windows (dl-umbriel-buffer-test--action-windows))
         (spec (dl-umbriel-buffer-test--spec 'focused "window-center"))
         (fields '((step . 1)))
         (focus (lambda (id)
                  (dl-umbriel-action "window-focus"
                                     (list (cons 'window id))))))
    (dolist (given (list fields nil))
      (should (equal (list (funcall focus "w-dp1")
                           (dl-umbriel-action "window-center" given)
                           (funcall focus "w-dp2"))
                     (dl-umbriel-buffer--plan spec (list :window (nth 0 windows))
                                              given workspaces))))
    (dolist (given (list fields nil))
      (should (equal (list (funcall focus "w-loose")
                           (dl-umbriel-action "window-center" given)
                           (funcall focus "w-dp2"))
                     (dl-umbriel-buffer--plan spec (list :window (nth 2 windows))
                                              given workspaces))))))

(ert-deftest dl-umbriel-buffer/plan-no-restore-when-already-focused ()
  "DEC-025: PREVIOUS equal to the row's window id plans no restore step."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces-focusing
                      "w-dp1"))
         (windows (dl-umbriel-buffer-test--action-windows))
         (spec (dl-umbriel-buffer-test--spec 'focused "window-center"))
         (fields '((step . 1))))
    (should (equal (list (dl-umbriel-action "window-focus"
                                            '((window . "w-dp1")))
                         (dl-umbriel-action "window-center" fields))
                   (dl-umbriel-buffer--plan spec (list :window (nth 0 windows))
                                            fields workspaces)))
    (should (equal (list (dl-umbriel-action "window-focus" '((window . "w-dp1")))
                         (dl-umbriel-action "window-center" nil))
                   (dl-umbriel-buffer--plan spec (list :window (nth 0 windows))
                                            nil workspaces)))))

(ert-deftest dl-umbriel-buffer/plan-no-restore-when-previous-unknown ()
  "DEC-025: an unknown PREVIOUS plans focus-then-act and no restore.
Unknown is: `focused_window' \"\", nil or absent, no focused workspace,
and more than one focused workspace."
  (let* ((windows (dl-umbriel-buffer-test--action-windows))
         (spec (dl-umbriel-buffer-test--spec 'focused "window-center"))
         (fields '((step . 1)))
         (unfocused
          (mapcar (lambda (workspace)
                    (setf (alist-get 'focused workspace) nil)
                    workspace)
                  (dl-umbriel-buffer-test--action-workspaces-focusing "w-dp2")))
         (two-focused
          (let ((both (dl-umbriel-buffer-test--action-workspaces-focusing
                       "w-dp2")))
            (setf (alist-get 'focused (nth 1 both)) t)
            both))
         (cases (list (dl-umbriel-buffer-test--action-workspaces-focusing "")
                      (dl-umbriel-buffer-test--action-workspaces-focusing nil)
                      (dl-umbriel-buffer-test--action-workspaces)
                      unfocused
                      two-focused)))
    (should (= 2 (seq-count (lambda (held) (alist-get 'focused held))
                            two-focused)))
    (should-not (seq-some (lambda (held) (alist-get 'focused held)) unfocused))
    (dolist (workspaces cases)
      (dolist (target (list (list :window (nth 0 windows))
                            (list :window (nth 2 windows))))
        (let* ((id (alist-get 'id (plist-get target :window)))
               (restore (dl-umbriel-action "window-focus"
                                           (list (cons 'window "w-dp2")))))
          (let ((plan (dl-umbriel-buffer--plan spec target fields workspaces)))
            (should (equal (list (dl-umbriel-action "window-focus"
                                                    (list (cons 'window id)))
                                 (dl-umbriel-action "window-center" fields))
                           plan))
            (should-not (member restore plan))))))))

(ert-deftest dl-umbriel-buffer/plan-no-restore-for-a-workspace-row ()
  "DEC-025: `focused' on a workspace row is [ACTION], restore or not."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces-focusing
                      "w-dp2"))
         (spec (dl-umbriel-buffer-test--spec 'focused "window-center"))
         (fields '((step . 1))))
    (dolist (workspace workspaces)
      (dolist (given (list nil fields))
        (should (equal (list (dl-umbriel-action "window-center" given))
                       (dl-umbriel-buffer--plan spec (list :workspace workspace)
                                                given workspaces)))))))

(ert-deftest dl-umbriel-buffer/plan-other-addressing-never-restores ()
  "DEC-025: `window', `workspace' and `active-workspace' plan as before.
A known PREVIOUS adds no `window-focus' step to any of them."
  (let* ((plain (dl-umbriel-buffer-test--action-workspaces))
         (restoring (dl-umbriel-buffer-test--action-workspaces-focusing
                     "w-dp2"))
         (windows (dl-umbriel-buffer-test--action-windows))
         (targets (list (list :window (nth 0 windows))
                        (list :workspace (nth 0 plain))
                        (list :workspace (nth 1 plain))))
         (fields '((step . 1)))
         (restores-p (lambda (plan)
                       (seq-some (lambda (request)
                                   (and (equal "window-focus"
                                               (alist-get 'action request))
                                        (equal "w-dp2"
                                               (alist-get 'window request))))
                                 plan))))
    (dolist (addressing '(window workspace active-workspace))
      (let ((spec (dl-umbriel-buffer-test--spec addressing
                                                "window-center")))
        (dolist (target targets)
          (dolist (given (list nil fields))
            (let ((with (dl-umbriel-buffer--plan spec target given restoring))
                  (without (dl-umbriel-buffer--plan spec target given plain)))
              (should (equal without with))
              ;; A refusal is a string, and no step of it restores anything.
              (when (listp with)
                (should-not (funcall restores-p with))))))))))

;;;; actions: kill (VT-2, EX-3, F-19, D-4)

(ert-deftest dl-umbriel-buffer/kill-refuses-emacs-own-process ()
  "VT-2/EX-3/F-19: killing Emacs's own pid refuses; nothing asked or sent."
  (let ((windows (list (dl-umbriel-buffer-test--window
                        :id "w-self" :workspace "DP-1:1"
                        :app_id "emacs" :title "notes.org"
                        :pid (emacs-pid)))))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held
         windows (dl-umbriel-buffer-test--action-workspaces))
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--with-prompts
                (let ((signalled
                       (should-error
                        (dl-umbriel-buffer-test--call-on-row
                         'my/umbriel-kill 'umbriel-window "w-self")
                        :type 'user-error)))
                  (should (dl-umbriel-buffer-test--mentions-p
                           (error-message-string signalled) "use delete-frame")))
                (should-not dl-umbriel-buffer-test--prompts)
                (should-not dl-umbriel-buffer-test--send-all-calls)
                (should-not dl-umbriel-buffer-test--refreshes)))))))))

(ert-deftest dl-umbriel-buffer/kill-prompt-names-the-window ()
  "VT-2/EX-3: the confirmation names app id, title and pid; -1 as well."
  (dolist (pid (list 4242 -1))
    (let* ((id (format "w-pid-%d" pid))
           (windows (list (dl-umbriel-buffer-test--window
                           :id id :workspace "DP-1:1" :app_id "foot"
                           :title "shell" :pid pid))))
      (dl-umbriel-buffer-test--with-state
          (dl-umbriel-buffer-test--held
           windows (dl-umbriel-buffer-test--action-workspaces))
        (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
          (with-current-buffer buffer
            (dl-umbriel-buffer--repaint)
            (dl-umbriel-buffer-test--with-send-all
              (dl-umbriel-buffer-test--with-prompts
                (setq dl-umbriel-buffer-test--prompt-confirm t)
                (dl-umbriel-buffer-test--call-on-row 'my/umbriel-kill
                                                     'umbriel-window id)
                (let ((call (car dl-umbriel-buffer-test--prompts)))
                  (should call)
                  (should (eq 'y-or-n-p (car call)))
                  (dolist (needle (list "foot" "shell" (number-to-string pid)))
                    (should (dl-umbriel-buffer-test--mentions-p
                             (nth 1 call) needle))))
                (should (equal (list (dl-umbriel-action "window-kill"
                                                        (list (cons 'window id))))
                               (car (car dl-umbriel-buffer-test--send-all-calls))))))))))))

(ert-deftest dl-umbriel-buffer/kill-confirms-the-captured-window ()
  "VT-2/EX-3: point and held state moving under the prompt redirect nothing."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-confirm t)
              (setq dl-umbriel-buffer-test--prompt-hook
                    (lambda ()
                      ;; The row at point and the held state both move on.
                      (goto-char (oref (dl-umbriel-buffer-test--find
                                        'umbriel-window "w-dp2")
                                       start))
                      (dl-umbriel-buffer-test--hold
                       (seq-remove (lambda (window)
                                     (equal "w-dp1" (alist-get 'id window)))
                                   (dl-umbriel-buffer-test--action-windows))
                       workspaces)
                      (dl-umbriel-buffer--repaint)))
              (dl-umbriel-buffer-test--call-on-row 'my/umbriel-kill
                                                   'umbriel-window "w-dp1")
              ;; The prompt really did move both out from under it.
              (should (equal "w-dp2" (oref (magit-current-section) value)))
              (should-not (dl-umbriel-window "w-dp1"))
              (should (equal (list (dl-umbriel-action "window-kill"
                                                      '((window . "w-dp1"))))
                             (car (car dl-umbriel-buffer-test--send-all-calls)))))))))))

(ert-deftest dl-umbriel-buffer/kill-declined-sends-nothing ()
  "VT-2/D-4: answering no sends nothing, refreshes nothing, says nothing."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--with-messages
                (dl-umbriel-buffer-test--with-prompts
                  (setq dl-umbriel-buffer-test--prompt-confirm nil)
                  (dl-umbriel-buffer-test--call-on-row 'my/umbriel-kill
                                                       'umbriel-window "w-dp1")
                  (should (= 1 (length dl-umbriel-buffer-test--prompts)))
                  (should-not dl-umbriel-buffer-test--send-all-calls)
                  (should-not dl-umbriel-buffer-test--refreshes)
                  (should-not dl-umbriel-buffer-test--messages))))))))))

;;;; actions: prompts (D-3)

(ert-deftest dl-umbriel-buffer/workspace-prompt-offers-the-held-workspaces ()
  "Prompts: `m' completes over the model choices and sends the selector."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (let* ((choices (dl-umbriel-model-workspace-choices
                               (dl-umbriel-workspaces)))
                     (label (car (nth 1 choices)))
                     (chosen (cdr (nth 1 choices))))
                (setq dl-umbriel-buffer-test--prompt-choice label)
                (dl-umbriel-buffer-test--call-on-row
                 'my/umbriel-move-to-workspace 'umbriel-window "w-dp1")
                (let ((call (car dl-umbriel-buffer-test--prompts)))
                  (should (eq 'completing-read (car call)))
                  (should (nth 3 call))
                  (should (dl-umbriel-buffer-test--same-set-p
                           (dl-umbriel-buffer-test--offered (nth 2 call))
                           (mapcar #'car choices))))
                (should (equal (list (dl-umbriel-action "window-focus"
                                                        '((window . "w-dp1")))
                                     (dl-umbriel-action
                                      "window-move-to-workspace-silent"
                                      (dl-umbriel-model-workspace-selector chosen)))
                               (car (car dl-umbriel-buffer-test--send-all-calls))))))))))))

(ert-deftest dl-umbriel-buffer/layout-prompt-offers-the-model-layouts ()
  "Prompts: `L' completes over the layouts and sends `(layout . CHOICE)'.
`toggle' goes without a `cycle' field: the request holds the layout only."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (dolist (choice dl-umbriel-model-layouts)
                (setq dl-umbriel-buffer-test--prompts nil)
                (setq dl-umbriel-buffer-test--send-all-calls nil)
                (setq dl-umbriel-buffer-test--prompt-choice choice)
                (dl-umbriel-buffer-test--call-on-row 'my/umbriel-set-layout
                                                     'umbriel-window "w-dp1")
                (let ((call (car dl-umbriel-buffer-test--prompts)))
                  (should (eq 'completing-read (car call)))
                  (should (nth 3 call))
                  (should (dl-umbriel-buffer-test--same-set-p
                           (dl-umbriel-buffer-test--offered (nth 2 call))
                           dl-umbriel-model-layouts)))
                ;; The window's workspace is the focused one: act, no switch.
                (should (equal (list (dl-umbriel-action
                                      "workspace-set-layout"
                                      (list (cons 'layout choice))))
                               (car (car dl-umbriel-buffer-test--send-all-calls))))))))))))

(ert-deftest dl-umbriel-buffer/prompts-keep-the-model-order ()
  "VH-1 Fix 2: both prompt tables pin identity sorts and offer model order.
vertico prefers a table's `display-sort-function' metadata over
`vertico-sort-function', so prescient's recency sort would reorder a
prompt unless the table declares identity for display and cycle."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer))
            (cases (list (list 'my/umbriel-move-to-workspace
                               (mapcar #'car
                                       (dl-umbriel-model-workspace-choices
                                        workspaces)))
                         (list 'my/umbriel-set-layout
                               dl-umbriel-model-layouts))))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (dolist (case cases)
                (let ((command (nth 0 case))
                      (expected (nth 1 case)))
                  (setq dl-umbriel-buffer-test--prompts nil)
                  (setq dl-umbriel-buffer-test--send-all-calls nil)
                  (setq dl-umbriel-buffer-test--prompt-choice (car expected))
                  (dl-umbriel-buffer-test--call-on-row command 'umbriel-window
                                                       "w-dp1")
                  (let ((call (car dl-umbriel-buffer-test--prompts)))
                    (should (eq 'completing-read (car call)))
                    (should (nth 3 call))
                    (dolist (key '(display-sort-function cycle-sort-function))
                      (should (eq 'identity
                                  (dl-umbriel-buffer-test--metadata
                                   (nth 2 call) key))))
                    (should (equal expected
                                   (dl-umbriel-buffer-test--offered
                                    (nth 2 call))))))))))))))

(ert-deftest dl-umbriel-buffer/refused-row-never-prompts ()
  "D-3: a refused row errors before prompting and before sending anything."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--with-prompts
                ;; `L' on an Unassigned window has no workspace to switch to.
                (let ((signalled
                       (should-error
                        (dl-umbriel-buffer-test--call-on-row
                         'my/umbriel-set-layout 'umbriel-window "w-loose")
                        :type 'user-error)))
                  (should (dl-umbriel-buffer-test--mentions-p
                           (error-message-string signalled) "workspace")))
                (should-not dl-umbriel-buffer-test--prompts)
                (should-not dl-umbriel-buffer-test--send-all-calls)
                (should-not dl-umbriel-buffer-test--refreshes)))))))))

(ert-deftest dl-umbriel-buffer/empty-prompt-input-sends-nothing ()
  "`completing-read' allows empty input under REQUIRE-MATCH: nothing is sent."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-choice "")
              (dolist (command '(my/umbriel-move-to-workspace
                                 my/umbriel-set-layout))
                (should-error (dl-umbriel-buffer-test--call-on-row
                               command 'umbriel-window "w-dp1")
                              :type 'user-error))
              (should-error (my/umbriel-set-active-layout) :type 'user-error)
              (should-not dl-umbriel-buffer-test--send-all-calls))))))))

(ert-deftest dl-umbriel-buffer/no-row-at-point-is-a-user-error ()
  "Target: a heading, or an empty buffer, is not an umbriel row."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (dl-umbriel-buffer-test--with-send-all
        (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
          (with-current-buffer buffer
            ;; Empty: there is not even a root section.
            (let ((signalled (should-error (call-interactively 'my/umbriel-focus)
                                           :type 'user-error)))
              (should (dl-umbriel-buffer-test--mentions-p
                       (error-message-string signalled)
                       "No umbriel row at point")))
            (dl-umbriel-buffer--repaint)
            ;; The Unassigned heading is a heading, not a row.
            (let ((signalled
                   (should-error
                    (dl-umbriel-buffer-test--call-on-row
                     'my/umbriel-focus 'umbriel-unassigned nil)
                    :type 'user-error)))
              (should (dl-umbriel-buffer-test--mentions-p
                       (error-message-string signalled)
                       "No umbriel row at point"))))
        (should-not dl-umbriel-buffer-test--send-all-calls))))))

;;;; actions: completion (VT-5, EX-7, DEC-021, D-6)

(ert-deftest dl-umbriel-buffer/completion-refreshes-only-when-shut ()
  "VT-5/EX-7: one refresh, after the reply, and only with the stream shut."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows))
        (status 'open))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-fake-status status
            (dl-umbriel-buffer-test--with-send-all
              (dl-umbriel-buffer-test--with-refresh
                (dl-umbriel-buffer-test--with-messages
                  ;; Open: the reply is silent and refreshes nothing.
                  (dl-umbriel-buffer-test--call-on-row
                   'my/umbriel-toggle-floating 'umbriel-window "w-dp1")
                  (should (= 1 (length dl-umbriel-buffer-test--send-all-calls)))
                  (should-not dl-umbriel-buffer-test--refreshes)
                  (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                           '(:ok nil))
                  (should-not dl-umbriel-buffer-test--refreshes)
                  (should-not dl-umbriel-buffer-test--messages)
                  ;; Shut: exactly one refresh, once the reply has landed.
                  (dolist (shut (list 'never (list :failure 'closed "gone")))
                    (setq dl-umbriel-buffer-test--send-all-calls nil)
                    (setq dl-umbriel-buffer-test--refreshes nil)
                    (setq status shut)
                    (dl-umbriel-buffer-test--call-on-row
                     'my/umbriel-toggle-floating 'umbriel-window "w-dp1")
                    (should-not dl-umbriel-buffer-test--refreshes)
                    (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                             '(:ok nil))
                    (should (= 1 (length dl-umbriel-buffer-test--refreshes)))
                    ;; No argument: the refresh fetches both families.
                    (should-not (car dl-umbriel-buffer-test--refreshes))
                    (should-not dl-umbriel-buffer-test--messages)))))))))))

(ert-deftest dl-umbriel-buffer/completion-reads-the-stream-status-late ()
  "VT-5/DEC-021: the status is read as the reply lands, not when it is sent."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows))
        (status 'open))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-fake-status status
            (dl-umbriel-buffer-test--with-send-all
              (dl-umbriel-buffer-test--with-refresh
                (dl-umbriel-buffer-test--call-on-row
                 'my/umbriel-toggle-floating 'umbriel-window "w-dp1")
                (setq status 'never)
                (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                         '(:ok nil))
                (should (= 1 (length dl-umbriel-buffer-test--refreshes)))
                ;; And the other way round: open by then, no refresh.
                (setq dl-umbriel-buffer-test--send-all-calls nil)
                (setq dl-umbriel-buffer-test--refreshes nil)
                (dl-umbriel-buffer-test--call-on-row
                 'my/umbriel-toggle-floating 'umbriel-window "w-dp1")
                (setq status 'open)
                (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                         '(:ok nil))
                (should-not dl-umbriel-buffer-test--refreshes)))))))))

(ert-deftest dl-umbriel-buffer/completion-echoes-a-failure ()
  "VT-5/EX-7: a failure reaches the echo as its message; no refresh."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows))
        (failure '(:failure rejected "no such window")))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--call-on-row
               'my/umbriel-toggle-floating 'umbriel-window "w-dp1")
              (dl-umbriel-buffer-test--with-messages
                (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                         failure)
                (should (equal (list (dl-umbriel-failure-message failure))
                               dl-umbriel-buffer-test--messages)))
              (should-not dl-umbriel-buffer-test--refreshes))))))))

(ert-deftest dl-umbriel-buffer/completion-stops-at-the-first-failure ()
  "VT-5/EX-7: the real sequencer stops; step two is never sent."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows))
        (sent nil))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-prompts
            (setq dl-umbriel-buffer-test--prompt-choice "master")
            (cl-letf (((symbol-function 'dl-umbriel-send)
                       (lambda (request callback)
                         (push request sent)
                         (funcall callback '(:failure rejected "no such window")))))
              (dl-umbriel-buffer-test--with-refresh
                (dl-umbriel-buffer-test--with-messages
                  ;; `L' on a workspace row of another workspace plans two
                  ;; steps: switch there, then act.
                  (dl-umbriel-buffer-test--call-on-row
                   'my/umbriel-set-layout 'umbriel-workspace "DP-1:2")
                  (should (= 1 (length sent)))
                  (should (equal "workspace-switch"
                                 (alist-get 'action (car sent))))
                  (should (equal (list (dl-umbriel-failure-message
                                        '(:failure rejected "no such window")))
                                 dl-umbriel-buffer-test--messages))
                  (should-not dl-umbriel-buffer-test--refreshes))))))))))

(ert-deftest dl-umbriel-buffer/completion-sends-the-restore-last ()
  "DEC-025/EX-7: focus, act, restore -- three requests, in that order.
Each one leaves only after the previous replied successfully."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces-focusing "w-dp2"))
        (windows (dl-umbriel-buffer-test--action-windows))
        (sent nil))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (cl-letf (((symbol-function 'dl-umbriel-send)
                     (lambda (request callback)
                       (push request sent)
                       (funcall callback '(:ok nil)))))
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--with-messages
                (dl-umbriel-buffer-test--call-on-row 'my/umbriel-center
                                                     'umbriel-window "w-dp1")
                (should (equal (list (dl-umbriel-action
                                      "window-focus" '((window . "w-dp1")))
                                     (dl-umbriel-action "window-center" nil)
                                     (dl-umbriel-action
                                      "window-focus" '((window . "w-dp2"))))
                               (reverse sent)))
                (should-not dl-umbriel-buffer-test--messages)
                (should-not dl-umbriel-buffer-test--refreshes)))))))))

(ert-deftest dl-umbriel-buffer/completion-a-failed-action-skips-the-restore ()
  "DEC-025/EX-7: a failed action stops the plan; the restore is never sent."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces-focusing "w-dp2"))
        (windows (dl-umbriel-buffer-test--action-windows))
        (failure '(:failure rejected "no such window"))
        (sent nil))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (cl-letf (((symbol-function 'dl-umbriel-send)
                     (lambda (request callback)
                       (push request sent)
                       (funcall callback (if (= 2 (length sent))
                                             failure
                                           '(:ok nil))))))
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--with-messages
                (dl-umbriel-buffer-test--call-on-row 'my/umbriel-center
                                                     'umbriel-window "w-dp1")
                (should (equal (list (dl-umbriel-action
                                      "window-focus" '((window . "w-dp1")))
                                     (dl-umbriel-action "window-center" nil))
                               (reverse sent)))
                (should (equal (list (dl-umbriel-failure-message failure))
                               dl-umbriel-buffer-test--messages))
                (should-not dl-umbriel-buffer-test--refreshes)))))))))

(ert-deftest dl-umbriel-buffer/completion-echoes-a-failed-restore ()
  "DEC-025/EX-7: the restore is sent last; its failure echoes like any other."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces-focusing "w-dp2"))
        (windows (dl-umbriel-buffer-test--action-windows))
        (failure '(:failure closed "umbriel went away"))
        (sent nil))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (cl-letf (((symbol-function 'dl-umbriel-send)
                     (lambda (request callback)
                       (push request sent)
                       (funcall callback (if (= 3 (length sent))
                                             failure
                                           '(:ok nil))))))
            (dl-umbriel-buffer-test--with-refresh
              (dl-umbriel-buffer-test--with-messages
                (dl-umbriel-buffer-test--call-on-row 'my/umbriel-center
                                                     'umbriel-window "w-dp1")
                (should (equal (list (dl-umbriel-action
                                      "window-focus" '((window . "w-dp1")))
                                     (dl-umbriel-action "window-center" nil)
                                     (dl-umbriel-action
                                      "window-focus" '((window . "w-dp2"))))
                               (reverse sent)))
                (should (equal (list (dl-umbriel-failure-message failure))
                               dl-umbriel-buffer-test--messages))
                (should-not dl-umbriel-buffer-test--refreshes)))))))))

(ert-deftest dl-umbriel-buffer/row-action-writes-no-held-state ()
  "VT-5/DEC-021: neither the command nor its callback writes held state."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (let ((before (dl-umbriel-state)))
            (cl-letf (((symbol-function 'dl-umbriel--set-family)
                       (lambda (&rest _)
                         (ert-fail "the command wrote the held snapshots")))
                      ((symbol-function 'dl-umbriel--set-status)
                       (lambda (&rest _)
                         (ert-fail "the command wrote the stream status"))))
              (dl-umbriel-buffer-test--with-send-all
                (dl-umbriel-buffer-test--with-refresh
                  (dl-umbriel-buffer-test--with-prompts
                    (setq dl-umbriel-buffer-test--prompt-choice
                          (car (nth 0 (dl-umbriel-model-workspace-choices
                                       workspaces))))
                    (dl-umbriel-buffer-test--call-on-row
                     'my/umbriel-move-to-workspace 'umbriel-window "w-dp1")
                    (should (= 1 (length dl-umbriel-buffer-test--send-all-calls)))
                    (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                             '(:ok nil)))))
            (should (equal before (dl-umbriel-state))))))))))

;;;; actions: the global commands (VT-3, EX-4, D-5, D-7)

(ert-deftest dl-umbriel-buffer/global-switch-refreshes-then-schedules ()
  "VT-3/EX-4/D-5: a shut stream refreshes; the prompt waits for a timer."
  (let ((status 'never)
        (workspaces (dl-umbriel-buffer-test--action-workspaces))
        (choices nil))
    (setq choices (dl-umbriel-model-workspace-choices workspaces))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held nil workspaces)
      (dl-umbriel-buffer-test--with-fake-status status
        (dl-umbriel-buffer-test--with-send-all
          (dl-umbriel-buffer-test--with-refresh
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-allowed nil)
              (dl-umbriel-buffer-test--with-scheduled calls
                ;; The command only refreshes; it prompts nowhere yet.
                (my/umbriel-switch-workspace)
                (should (= 1 (length dl-umbriel-buffer-test--refreshes)))
                (should (car dl-umbriel-buffer-test--refreshes))
                (should-not dl-umbriel-buffer-test--prompts)
                (should-not calls)
                (should-not dl-umbriel-buffer-test--send-all-calls)
                ;; Nor may the reply prompt: it schedules.
                (funcall (car dl-umbriel-buffer-test--refreshes) '(:ok nil))
                (should-not dl-umbriel-buffer-test--prompts)
                (should (= 1 (length calls)))
                (should (equal 0 (nth 0 (car calls))))
                (should-not (nth 1 (car calls)))
                (should (functionp (nth 2 (car calls))))
                (should-not dl-umbriel-buffer-test--send-all-calls)
                ;; The timer's function is where the prompt belongs.
                (setq dl-umbriel-buffer-test--prompt-allowed t)
                (setq dl-umbriel-buffer-test--prompt-choice
                      (car (nth 1 choices)))
                (funcall (nth 2 (car calls)))
                (should (= 1 (length dl-umbriel-buffer-test--prompts)))
                (should (equal (list (dl-umbriel-action
                                      "workspace-switch"
                                      (dl-umbriel-model-workspace-selector
                                       (cdr (nth 1 choices)))))
                               (car (car dl-umbriel-buffer-test--send-all-calls))))))))))))

(ert-deftest dl-umbriel-buffer/global-switch-messages-inside-a-minibuffer ()
  "VT-3/EX-4: a minibuffer already active when the timer runs is respected."
  (let ((status 'never)
        (workspaces (dl-umbriel-buffer-test--action-workspaces)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held nil workspaces)
      (dl-umbriel-buffer-test--with-fake-status status
        (dl-umbriel-buffer-test--with-send-all
          (dl-umbriel-buffer-test--with-refresh
            (dl-umbriel-buffer-test--with-messages
              (dl-umbriel-buffer-test--with-prompts
                (setq dl-umbriel-buffer-test--prompt-allowed nil)
                (dl-umbriel-buffer-test--with-scheduled calls
                  (my/umbriel-switch-workspace)
                  (funcall (car dl-umbriel-buffer-test--refreshes) '(:ok nil))
                  (should (= 1 (length calls)))
                  (cl-letf (((symbol-function 'active-minibuffer-window)
                             (lambda () (selected-window))))
                    (funcall (nth 2 (car calls))))
                  (should-not dl-umbriel-buffer-test--prompts)
                  (should-not dl-umbriel-buffer-test--send-all-calls)
                  (should (= 1 (length dl-umbriel-buffer-test--messages)))
                  (should (dl-umbriel-buffer-test--mentions-p
                           (car dl-umbriel-buffer-test--messages) "retry"))
                  (should (dl-umbriel-buffer-test--mentions-p
                           (car dl-umbriel-buffer-test--messages)
                           "C-c u w")))))))))))

(ert-deftest dl-umbriel-buffer/global-switch-echoes-a-refresh-failure ()
  "VT-3/EX-4: a failed refresh is echoed and schedules nothing."
  (let ((status 'never)
        (workspaces (dl-umbriel-buffer-test--action-workspaces))
        (failure '(:failure closed "stream closed")))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held nil workspaces)
      (dl-umbriel-buffer-test--with-fake-status status
        (dl-umbriel-buffer-test--with-send-all
          (dl-umbriel-buffer-test--with-refresh
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-allowed nil)
              (dl-umbriel-buffer-test--with-scheduled calls
                (my/umbriel-switch-workspace)
                (dl-umbriel-buffer-test--with-messages
                  (funcall (car dl-umbriel-buffer-test--refreshes) failure)
                  (should (equal (list (dl-umbriel-failure-message failure))
                                 dl-umbriel-buffer-test--messages)))
                (should-not calls)
                (should-not dl-umbriel-buffer-test--prompts)
                (should-not dl-umbriel-buffer-test--send-all-calls)))))))))

(ert-deftest dl-umbriel-buffer/global-switch-prompts-at-once-when-open ()
  "D-5/VT-3: an open stream prompts in the command, refreshing nothing first."
  (let ((status 'open)
        (workspaces (dl-umbriel-buffer-test--action-workspaces)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held nil workspaces)
      (dl-umbriel-buffer-test--with-fake-status status
        (dl-umbriel-buffer-test--with-send-all
          (dl-umbriel-buffer-test--with-refresh
            (dl-umbriel-buffer-test--with-prompts
              (let* ((choices (dl-umbriel-model-workspace-choices
                               (dl-umbriel-workspaces)))
                     (chosen (cdr (nth 0 choices))))
                (setq dl-umbriel-buffer-test--prompt-choice
                      (car (nth 0 choices)))
                (my/umbriel-switch-workspace)
                (should-not dl-umbriel-buffer-test--refreshes)
                (should (= 1 (length dl-umbriel-buffer-test--prompts)))
                (should (equal (list (dl-umbriel-action
                                      "workspace-switch"
                                      (dl-umbriel-model-workspace-selector chosen)))
                               (car (car dl-umbriel-buffer-test--send-all-calls))))))))))))

(ert-deftest dl-umbriel-buffer/no-row-callback-prompts ()
  "VT-5/EX-7: no row command's send-all callback opens any prompt."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (dolist (spec dl-umbriel-buffer-test--action-table)
                (setq dl-umbriel-buffer-test--send-all-calls nil)
                (setq dl-umbriel-buffer-test--prompts nil)
                (setq dl-umbriel-buffer-test--prompt-choice
                      (if (eq (nth 3 spec) 'layout)
                          "master"
                        (car (nth 0 (dl-umbriel-model-workspace-choices
                                     workspaces)))))
                (setq dl-umbriel-buffer-test--prompt-confirm t)
                (dl-umbriel-buffer-test--call-on-row (nth 0 spec)
                                                     'umbriel-window "w-dp1")
                (let ((plan (caar dl-umbriel-buffer-test--send-all-calls))
                      (callback (cdar dl-umbriel-buffer-test--send-all-calls))
                      (asked (length dl-umbriel-buffer-test--prompts)))
                  (should plan)
                  (should callback)
                  (setq dl-umbriel-buffer-test--prompt-allowed nil)
                  (funcall callback '(:ok nil))
                  (should (= asked (length dl-umbriel-buffer-test--prompts)))
                  (should (= 1 (length dl-umbriel-buffer-test--send-all-calls)))
                  (setq dl-umbriel-buffer-test--prompt-allowed t))))))))))

(ert-deftest dl-umbriel-buffer/set-active-layout-prompts-the-pointer ()
  "D-7: the global layout command names the pointer and sends the layout."
  (let ((status 'open))
    (dl-umbriel-buffer-test--with-state nil
      (dl-umbriel-buffer-test--with-fake-status status
        (dl-umbriel-buffer-test--with-send-all
          (dl-umbriel-buffer-test--with-refresh
            (dl-umbriel-buffer-test--with-prompts
              (dolist (choice (list "master" "toggle"))
                (setq dl-umbriel-buffer-test--send-all-calls nil)
                (setq dl-umbriel-buffer-test--prompts nil)
                (setq dl-umbriel-buffer-test--prompt-choice choice)
                (my/umbriel-set-active-layout)
                (let ((call (car dl-umbriel-buffer-test--prompts)))
                  (should (eq 'completing-read (car call)))
                  (should (nth 3 call))
                  (should (dl-umbriel-buffer-test--mentions-p (nth 1 call) "pointer"))
                  (should (dl-umbriel-buffer-test--mentions-p (nth 1 call) "output"))
                  (should (dl-umbriel-buffer-test--same-set-p
                           (dl-umbriel-buffer-test--offered (nth 2 call))
                           dl-umbriel-model-layouts)))
                (should (equal (list (dl-umbriel-action
                                      "workspace-set-layout"
                                      (list (cons 'layout choice))))
                               (car (car dl-umbriel-buffer-test--send-all-calls)))))
              ;; Completion as a row command's: one refresh when shut.
              (setq status 'never)
              (setq dl-umbriel-buffer-test--send-all-calls nil)
              (setq dl-umbriel-buffer-test--refreshes nil)
              (setq dl-umbriel-buffer-test--prompt-choice "master")
              (my/umbriel-set-active-layout)
              (should-not dl-umbriel-buffer-test--refreshes)
              (funcall (cdr (car dl-umbriel-buffer-test--send-all-calls))
                       '(:ok nil))
              (should (= 1 (length dl-umbriel-buffer-test--refreshes))))))))))

;;;; actions: keys and commands (VT-4, § Macro)

(ert-deftest dl-umbriel-buffer/row-keys-bind-the-actions ()
  "VT-4: every row key in the sheet's table, and its twin, is bound."
  (dolist (binding '(("RET" . my/umbriel-focus)
                     ("s" . my/umbriel-switch)
                     ("m" . my/umbriel-move-to-workspace)
                     ("t" . my/umbriel-toggle-floating)
                     ("c" . my/umbriel-center)
                     ("k" . my/umbriel-kill)
                     ("L" . my/umbriel-set-layout)
                     ("M-<left>" . my/umbriel-column-left)
                     ("<" . my/umbriel-column-left)
                     ("M-<right>" . my/umbriel-column-right)
                     (">" . my/umbriel-column-right)
                     ("C-<left>" . my/umbriel-scroll-left)
                     ("[" . my/umbriel-scroll-left)
                     ("C-<right>" . my/umbriel-scroll-right)
                     ("]" . my/umbriel-scroll-right)
                     ("e" . my/umbriel-cycle-extent)
                     ("E" . my/umbriel-cycle-extent-back)
                     ("g" . my/umbriel-refresh)
                     ("q" . quit-window)))
    (should (eq (keymap-lookup dl-umbriel-buffer-mode-map (car binding))
                (cdr binding)))))

(ert-deftest dl-umbriel-buffer/action-rows-are-commands ()
  "VT-4/§Macro: every table row is an interactive command with a docstring."
  (dolist (row dl-umbriel-buffer-test--action-table)
    (let ((command (nth 0 row)))
      (should (fboundp command))
      (should (commandp command))
      (let ((doc (documentation command)))
        (should (stringp doc))
        (should-not (string-empty-p doc))
        (dolist (line (split-string doc "\n"))
          (should (<= (length line) 80)))))))

(ert-deftest dl-umbriel-buffer/action-table-is-the-designs ()
  "§Macro: the table holds the design's rows, verbatim, in order."
  (should (equal dl-umbriel-buffer-test--action-table
                 dl-umbriel-buffer-actions)))

;;;; actions: review fixes
;;
;; Contract: .doctrine/state/slice/016/phases/phase-05-review.md, R-1..R-7.
;; T-1..T-6 pin behaviour the review asked for and the implementation did not
;; have yet; T-7 and T-8 pin behaviour it already had.

(ert-deftest dl-umbriel-buffer/layout-refuses-two-focused-workspaces ()
  "T-1/R-1/F-6: two `focused' workspaces is no answer, so refuse."
  (let* ((workspaces
          (list (dl-umbriel-buffer-test--workspace :id "DP-1:1" :index 1
                                                   :output "DP-1" :focused t)
                (dl-umbriel-buffer-test--workspace :id "DP-2:1" :index 1
                                                   :output "DP-2" :focused t)))
         (windows (list (dl-umbriel-buffer-test--window :id "w-dp1"
                                                        :workspace "DP-1:1")
                        (dl-umbriel-buffer-test--window :id "w-dp2"
                                                        :workspace "DP-2:1")))
         (spec (dl-umbriel-buffer-test--spec 'active-workspace
                                             "workspace-set-layout" 'layout))
         (fields '((layout . "master"))))
    (dolist (target (list (list :workspace (nth 0 workspaces))
                          (list :workspace (nth 1 workspaces))
                          (list :window (nth 0 windows))
                          (list :window (nth 1 windows))))
      (let ((result (dl-umbriel-buffer-test--refused
                     spec target fields workspaces)))
        (should-not (dl-umbriel-buffer-test--switches-p result))))))

(ert-deftest dl-umbriel-buffer/unknown-prompt-kind-refuses-to-send ()
  "T-2/R-2: an unknown PROMPT kind fails closed: it signals, sends nothing."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows)))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              ;; A typo'd `confirm-kill' must never confirm, and never send.
              (goto-char (oref (dl-umbriel-buffer-test--find
                                'umbriel-window "w-dp1")
                               start))
              (should-error
               (dl-umbriel-buffer--run
                (dl-umbriel-buffer-test--spec 'window "window-kill"
                                              'confirm-killl))
               :type 'error)
              (should-not dl-umbriel-buffer-test--prompts)
              (should-not dl-umbriel-buffer-test--send-all-calls))))))))

(ert-deftest dl-umbriel-buffer/kill-prompt-keeps-a-newline-out ()
  "T-3/R-3: the confirmation stays one line and still names id, title, pid."
  (let ((windows (list (dl-umbriel-buffer-test--window
                        :id "w-multiline" :workspace "DP-1:1"
                        :app_id "foot" :title "notes\nsecret" :pid 4242))))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held
         windows (dl-umbriel-buffer-test--action-workspaces))
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-confirm nil)
              (dl-umbriel-buffer-test--call-on-row
               'my/umbriel-kill 'umbriel-window "w-multiline")
              (let ((call (car dl-umbriel-buffer-test--prompts)))
                (should (eq 'y-or-n-p (car call)))
                (should-not (string-match-p "\n" (nth 1 call)))
                (dolist (needle (list "foot" "notes" "secret" "4242"))
                  (should (dl-umbriel-buffer-test--mentions-p
                           (nth 1 call) needle))))
              (should-not dl-umbriel-buffer-test--send-all-calls))))))))

(ert-deftest dl-umbriel-buffer/kill-compares-the-pid-numerically ()
  "T-4/R-4: a float pid names the same process; a string pid prompts."
  (let ((windows (list (dl-umbriel-buffer-test--window
                        :id "w-float" :workspace "DP-1:1"
                        :app_id "emacs" :title "notes"
                        :pid (float (emacs-pid)))
                       (dl-umbriel-buffer-test--window
                        :id "w-string" :workspace "DP-1:1"
                        :app_id "foot" :title "shell" :pid "4242"))))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held
         windows (dl-umbriel-buffer-test--action-workspaces))
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-confirm t)
              ;; The compositor's 4242.0 is this Emacs just as 4242 is.
              (let ((signalled
                     (should-error
                      (dl-umbriel-buffer-test--call-on-row
                       'my/umbriel-kill 'umbriel-window "w-float")
                      :type 'user-error)))
                (should (dl-umbriel-buffer-test--mentions-p
                         (error-message-string signalled) "use delete-frame")))
              (should-not dl-umbriel-buffer-test--prompts)
              (should-not dl-umbriel-buffer-test--send-all-calls)
              ;; A pid that arrived as a string takes the normal path.
              (setq dl-umbriel-buffer-test--prompt-confirm nil)
              (dl-umbriel-buffer-test--call-on-row
               'my/umbriel-kill 'umbriel-window "w-string")
              (let ((call (car dl-umbriel-buffer-test--prompts)))
                (should (eq 'y-or-n-p (car call)))
                (should (dl-umbriel-buffer-test--mentions-p
                         (nth 1 call) "4242")))
              (should-not dl-umbriel-buffer-test--send-all-calls))))))))

(ert-deftest dl-umbriel-buffer/unknown-addressing-signals ()
  "T-5/R-6: a plan for an addressing the table does not know signals."
  (let ((workspaces (dl-umbriel-buffer-test--action-workspaces))
        (windows (dl-umbriel-buffer-test--action-windows))
        (spec (dl-umbriel-buffer-test--spec 'sideways "window-focus")))
    (dolist (target (list (list :window (nth 0 windows))
                          (list :workspace (nth 0 workspaces))))
      (should-error (dl-umbriel-buffer--plan spec target nil workspaces)
                    :type 'error))))

(ert-deftest dl-umbriel-buffer/global-switch-with-no-workspaces-held ()
  "T-6/R-7: nothing held still refreshes, then the timer messages."
  (dl-umbriel-buffer-test--with-state (dl-umbriel-buffer-test--held nil nil 'open 0)
    (dl-umbriel-buffer-test--with-send-all
      (dl-umbriel-buffer-test--with-refresh
        (dl-umbriel-buffer-test--with-messages
          (dl-umbriel-buffer-test--with-prompts
            (setq dl-umbriel-buffer-test--prompt-allowed nil)
            (dl-umbriel-buffer-test--with-scheduled calls
              ;; Open, but nothing held: refresh rather than prompt.
              (my/umbriel-switch-workspace)
              (should (= 1 (length dl-umbriel-buffer-test--refreshes)))
              (should-not dl-umbriel-buffer-test--prompts)
              (should-not calls)
              ;; The reply may not prompt either: it schedules.
              (funcall (car dl-umbriel-buffer-test--refreshes) '(:ok nil))
              (should-not dl-umbriel-buffer-test--prompts)
              (should (= 1 (length calls)))
              (should (equal 0 (nth 0 (car calls))))
              ;; The timer runs with the workspaces still empty.
              (funcall (nth 2 (car calls)))
              (should-not dl-umbriel-buffer-test--prompts)
              (should-not dl-umbriel-buffer-test--send-all-calls)
              (should (= 1 (length dl-umbriel-buffer-test--messages)))
              (should (dl-umbriel-buffer-test--mentions-p
                       (car dl-umbriel-buffer-test--messages)
                       "workspace")))))))))

(ert-deftest dl-umbriel-buffer/the-prompt-does-not-re-read-the-held-workspaces ()
  "T-7: the workspaces captured before the prompt are planned with."
  (let* ((workspaces (dl-umbriel-buffer-test--action-workspaces))
         (windows (dl-umbriel-buffer-test--action-windows))
         (target (nth 1 workspaces))
         (moved (list (dl-umbriel-buffer-test--workspace :id "DP-2:1" :index 1
                                                         :name "docs"
                                                         :output "DP-2"
                                                         :focused t)
                      (dl-umbriel-buffer-test--workspace :id "DP-1:2" :index 2
                                                         :name nil :named nil
                                                         :output "DP-1"))))
    (dl-umbriel-buffer-test--with-state
        (dl-umbriel-buffer-test--held windows workspaces)
      (let ((buffer (dl-umbriel-buffer-test--mode-buffer)))
        (with-current-buffer buffer
          (dl-umbriel-buffer--repaint)
          (dl-umbriel-buffer-test--with-send-all
            (dl-umbriel-buffer-test--with-prompts
              (setq dl-umbriel-buffer-test--prompt-choice "master")
              (setq dl-umbriel-buffer-test--prompt-hook
                    (lambda ()
                      ;; Focus moves to the other output under the prompt.
                      (dl-umbriel-buffer-test--hold windows moved)))
              (dl-umbriel-buffer-test--call-on-row
               'my/umbriel-set-layout 'umbriel-workspace "DP-1:2")
              ;; The held state really did move off the target's output.
              (should (equal "DP-2"
                             (alist-get 'output
                                        (seq-find (lambda (held)
                                                    (alist-get 'focused held))
                                                  (dl-umbriel-workspaces)))))
              (should (equal (list (dl-umbriel-action
                                    "workspace-switch"
                                    (dl-umbriel-model-workspace-selector target))
                                   (dl-umbriel-action "workspace-set-layout"
                                                      '((layout . "master"))))
                             (car (car dl-umbriel-buffer-test--send-all-calls)))))))))))

(ert-deftest dl-umbriel-buffer/docstrings-name-their-action ()
  "T-8/§Macro: each generated docstring names its umbriel action string."
  (dolist (row dl-umbriel-buffer-test--action-table)
    (let ((doc (documentation (nth 0 row))))
      (should (stringp doc))
      (should (dl-umbriel-buffer-test--mentions-p doc (nth 1 row))))))

;;;; keys (VT-4, EX-5, EX-6)

(require 'meow)
(require 'dl-keymap)
(meow-setup)

(defconst dl-umbriel-buffer-test--global-keys
  '(("u" . my/umbriel)
    ("w" . my/umbriel-switch-workspace)
    ("l" . my/umbriel-set-active-layout)
    ("f" . dl-umbriel-focus-frame))
  "The `my-umbriel-map' bindings of design § Keys (DEC-024).")

(ert-deftest dl-umbriel-buffer/global-map-binds-the-four-commands ()
  "VT-4: `my-umbriel-map' carries u/w/l/f, and sits on C-c u."
  (pcase-dolist (`(,key . ,command) dl-umbriel-buffer-test--global-keys)
    (should (eq (keymap-lookup my-umbriel-map key) command)))
  (should (eq (keymap-lookup global-map "C-c u") my-umbriel-map)))

(ert-deftest dl-umbriel-buffer/leader-mirrors-the-global-map ()
  "VT-4: `meow-setup' puts `my-umbriel-map' on the leader, SPC u.
The leader map is empty of `u' first, so the binding seen is meow-setup's."
  (let ((meow-keymap-alist (copy-alist meow-keymap-alist)))
    (setf (alist-get 'leader meow-keymap-alist)
          (copy-keymap (alist-get 'leader meow-keymap-alist)))
    (keymap-unset (alist-get 'leader meow-keymap-alist) "u" t)
    (should-not (keymap-lookup (alist-get 'leader meow-keymap-alist) "u"))
    (meow-setup)
    (should (eq (keymap-lookup (alist-get 'leader meow-keymap-alist) "u")
                my-umbriel-map))))

(ert-deftest dl-umbriel-buffer/row-keys-are-not-shadowed-by-motion-state ()
  "EX-5: no row key is bound in the config's meow motion-state map."
  (dolist (key '("RET" "s" "m" "t" "c" "k" "L" "M-<left>" "<" "M-<right>"
                 ">" "C-<left>" "[" "C-<right>" "]" "e" "E" "g" "q"))
    (should-not (keymap-lookup meow-motion-state-keymap key)))
  ;; Each of those keys is in fact a row key.
  (should (keymap-lookup dl-umbriel-buffer-mode-map "RET")))

(ert-deftest dl-umbriel-buffer/buffer-mode-starts-in-motion-state ()
  "EX-5: meow guesses motion state for `dl-umbriel-buffer-mode'."
  (should (eq (alist-get 'dl-umbriel-buffer-mode meow-mode-state-list
                         (with-temp-buffer
                           (dl-umbriel-buffer-mode)
                           (meow--mode-guess-state)))
              'motion)))

(defun dl-umbriel-buffer-test--keys-resolve-in-fresh-emacs (features)
  "Load FEATURES in order in a fresh batch Emacs; return its stdout.
The output lists each C-c u key with its command and `commandp'."
  (let ((expr `(progn
                 (setq load-prefer-newer t load-path ',load-path)
                 (dolist (feature ',features) (require feature))
                 (dolist (key '("u" "w" "l" "f"))
                   (let ((cmd (keymap-lookup global-map (concat "C-c u " key))))
                     (princ (format "%s %S %S\n" key cmd (commandp cmd))))))))
    (with-temp-buffer
      (call-process "timeout" nil t nil "60" (expand-file-name invocation-name
                                                               invocation-directory)
                    "--batch" "-Q" "--eval" (prin1-to-string expr))
      (buffer-string))))

(ert-deftest dl-umbriel-buffer/keys-resolve-in-either-load-order ()
  "EX-6: C-c u u/w/l/f resolve and are commands whichever loads first."
  (skip-unless (file-executable-p (expand-file-name invocation-name
                                                    invocation-directory)))
  (skip-unless (executable-find "timeout"))
  (let ((expected (concat "u my/umbriel t\n"
                          "w my/umbriel-switch-workspace t\n"
                          "l my/umbriel-set-active-layout t\n"
                          "f dl-umbriel-focus-frame t\n")))
    (dolist (order '((dl-keymap dl-umbriel-buffer dl-umbriel-focus)
                     (dl-umbriel-buffer dl-umbriel-focus dl-keymap)))
      (should (equal (dl-umbriel-buffer-test--keys-resolve-in-fresh-emacs order)
                     expected)))))

;;; dl-umbriel-buffer-test.el ends here
