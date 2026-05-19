;;; dl-satan-tank.el --- SATAN observation tank -*- lexical-binding: t; -*-

;; Composite read-only buffer that mirrors what SATAN sees right now.
;; Three sections refresh on a timer (`g' for manual refresh, `q' to
;; quit):
;;
;;   1. EVIDENCE WINDOW   `dl-satan-memory-evidence-assemble' output
;;                        (current panopticon window, focus / browser
;;                        segment counts, active bough nodes, git + cwd)
;;   2. RECENT TRACES     `dl-satan-memory-store-recent' last N rows
;;   3. RECENT EVENTS     tail of run transcripts under `dl-satan-runs-dir'
;;
;; Section renderers are pure (state plist in, string out) so they are
;; tested without DB / panopticon / bough access.  Gatherers wrap the
;; impure reads and swallow errors so a degraded section never breaks
;; the buffer.

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-broker)
(require 'dl-satan-memory-evidence)
(require 'dl-satan-memory-store)
(require 'dl-satan-memory-grammar)

;; ---------------------------------------------------------------------
;; Customisation
;; ---------------------------------------------------------------------

(defgroup dl-satan-tank nil
  "Composite observation surface for the SATAN broker."
  :group 'dl-satan :prefix "dl-satan-tank-")

(defcustom dl-satan-tank-refresh-interval 5
  "Seconds between automatic refreshes; nil disables the timer."
  :type '(choice (number :tag "Seconds") (const :tag "Disabled" nil))
  :group 'dl-satan-tank)

(defcustom dl-satan-tank-trace-limit 10
  "Recent-traces section displays at most this many rows."
  :type 'integer :group 'dl-satan-tank)

(defcustom dl-satan-tank-event-limit 20
  "Recent-events section displays at most this many events."
  :type 'integer :group 'dl-satan-tank)

(defcustom dl-satan-tank-event-window-runs 8
  "Number of most recent runs scanned for events."
  :type 'integer :group 'dl-satan-tank)

(defcustom dl-satan-tank-evidence-history-seconds 1800
  "How far back to anchor the evidence window when the tank is opened
outside an active SATAN run.  Default is 30 minutes."
  :type 'integer :group 'dl-satan-tank)

(defconst dl-satan-tank--buffer-name "*satan-tank*")

(defvar dl-satan-tank--timer nil
  "Singleton refresh timer for the tank buffer.")

;; ---------------------------------------------------------------------
;; Pure helpers
;; ---------------------------------------------------------------------

(defun dl-satan-tank--truncate (s n)
  "Truncate S to N chars, suffixing `…' when shortened."
  (if (<= (length s) n) s
    (concat (substring s 0 (max 0 (1- n))) "…")))

(defun dl-satan-tank--short-ts (ts)
  "Return the HH:MM:SS portion of an ISO8601 TS, or TS unchanged."
  (cond
   ((and (stringp ts) (string-match "T\\([0-9:]+\\)" ts))
    (match-string 1 ts))
   (t (or ts ""))))

(defun dl-satan-tank--short-run (run-id)
  "Pull the mode slug from a RUN-ID like `20260520T082808-tick-pulse-e44377'."
  (cond
   ((and (stringp run-id)
         (string-match "T[0-9]+-\\(.+\\)-[a-z0-9]+\\'" run-id))
    (match-string 1 run-id))
   (t (or run-id ""))))

(defun dl-satan-tank--summarize-args (args)
  "Compact one-line summary of a tool-call ARGS plist."
  (cond
   ((null args) "")
   ((stringp args) (dl-satan-tank--truncate args 40))
   ((listp args)
    (mapconcat
     (lambda (cell)
       (format "%s=%s" (substring (symbol-name (car cell)) 1)
               (dl-satan-tank--truncate (format "%s" (cadr cell)) 20)))
     (cl-loop for (k v) on args by #'cddr
              when (keywordp k) collect (list k v))
     " "))
   (t (format "%s" args))))

(defun dl-satan-tank--event-summary (rec)
  "Build a one-line summary for a transcript JSONL record REC."
  (let* ((event (plist-get rec :event))
         (payload (plist-get rec :payload)))
    (pcase event
      ("tool-call"
       (let ((name (and (listp payload) (plist-get payload :name)))
             (args (and (listp payload) (plist-get payload :arguments))))
         (format "%s(%s)" (or name "?")
                 (dl-satan-tank--summarize-args args))))
      ("tool-result"
       (let ((name (and (listp payload) (plist-get payload :name)))
             (ok (and (listp payload) (plist-get payload :ok))))
         (format "%s → %s" (or name "?")
                 (if (eq ok :false) "error" "ok"))))
      ("log"
       (let ((kind (and (listp payload) (plist-get payload :kind))))
         (or kind "log")))
      ("timeout"
       (format "after %ss" (and (listp payload)
                                (plist-get payload :after-seconds))))
      (_ (or event "")))))

;; ---------------------------------------------------------------------
;; Pure renderers
;; ---------------------------------------------------------------------

(defun dl-satan-tank--section (title)
  ;; #x2500 = BOX DRAWINGS LIGHT HORIZONTAL ('─').  Emacs-overlay's elisp
  ;; parser does not accept multi-byte `?<char>' literals, so the
  ;; integer form is used here to keep `home-manager switch' working.
  (format "%s\n%s\n" title (make-string (length title) #x2500)))

(defun dl-satan-tank--header (now-iso)
  (format "═══ SATAN OBSERVATION TANK · %s ═══\n\n" now-iso))

(defun dl-satan-tank--render-bough-active (nodes max)
  (cond
   ((null nodes) "")
   (t
    (let* ((shown (cl-subseq nodes 0 (min max (length nodes))))
           (rest (max 0 (- (length nodes) max))))
      (concat
       (mapconcat
        (lambda (n)
          (format "  · %-6s %s  (%s)\n"
                  (or (plist-get n :status) "?")
                  (dl-satan-tank--truncate (or (plist-get n :title) "") 60)
                  (or (plist-get n :nanoid) "?")))
        shown "")
       (if (> rest 0) (format "  · …%d more\n" rest) ""))))))

(defun dl-satan-tank--render-evidence (state)
  "Render the EVIDENCE WINDOW section for STATE plist."
  (concat
   (dl-satan-tank--section "EVIDENCE WINDOW")
   (cond
    ((null state) "(unavailable)\n")
    (t
     (let* ((start (plist-get state :window_start_at))
            (end (plist-get state :window_end_at))
            (cw (plist-get state :current_window))
            (focus (plist-get state :focus_segments))
            (browser (plist-get state :browser_segments))
            (active (plist-get state :bough_active))
            (git (plist-get state :git_state))
            (fs (plist-get state :fs_state))
            (truncated (plist-get state :truncated_at))
            (app (and cw (or (plist-get cw :app_id) (plist-get cw :app))))
            (title (and cw (plist-get cw :title)))
            (workspace (and cw (plist-get cw :workspace))))
       (concat
        (format "window:        %s → %s\n" (or start "-") (or end "-"))
        (if cw
            (format "current:       %s · ws=%s · %s\n"
                    (or app "?") (or workspace "?")
                    (dl-satan-tank--truncate (or title "") 60))
          "current:       (no panopticon)\n")
        (format "focus:         %d segments\n" (length focus))
        (format "browser:       %d segments\n" (length browser))
        (format "bough_active:  %d nodes\n" (length active))
        (dl-satan-tank--render-bough-active active 4)
        (if git
            (format "git:           %s%s\n"
                    (or (plist-get git :head_short) "?")
                    (if (plist-get git :dirty) " · dirty" ""))
          "git:           (not a repo)\n")
        (format "cwd:           %s\n" (or (and fs (plist-get fs :cwd)) "?"))
        (if truncated
            (format "truncated_at:  %s\n"
                    (mapconcat (lambda (s) (format "%s" s)) truncated " "))
          "")))))
   "\n"))

(defun dl-satan-tank--render-traces (rows)
  "Render the RECENT TRACES section for ROWS (list of store-recent plists)."
  (concat
   (dl-satan-tank--section
    (format "RECENT TRACES (last %d)" (length rows)))
   (cond
    ((null rows) "(no traces)\n")
    (t
     (mapconcat
      (lambda (r)
        (let* ((kind (plist-get r :kind))
               (val (plist-get r :valence))
               (end (plist-get r :observed_end_at))
               (payload (plist-get r :payload))
               (handles (plist-get r :handles)))
          (format "%s  %-12s %s\n  [%s]\n  %s\n"
                  (or end "-") (or kind "?") (or val "·")
                  (mapconcat #'identity (or handles '()) " ")
                  (dl-satan-tank--truncate (or payload "") 200))))
      rows "\n")))
   "\n"))

(defun dl-satan-tank--render-events (events)
  "Render the RECENT EVENTS section for EVENTS (list of plists)."
  (concat
   (dl-satan-tank--section
    (format "RECENT EVENTS (last %d)" (length events)))
   (cond
    ((null events) "(no events)\n")
    (t
     (mapconcat
      (lambda (e)
        (format "%s  %-14s  %-7s  %-12s  %s"
                (dl-satan-tank--short-ts (or (plist-get e :ts) ""))
                (dl-satan-tank--truncate
                 (or (plist-get e :run) "?") 14)
                (or (plist-get e :dir) "?")
                (or (plist-get e :event) "?")
                (dl-satan-tank--truncate (or (plist-get e :summary) "") 80)))
      events "\n")))
   "\n"))

;; ---------------------------------------------------------------------
;; Gatherers (impure)
;; ---------------------------------------------------------------------

(defun dl-satan-tank--time-iso (&optional time)
  (format-time-string "%Y-%m-%dT%H:%M:%S%:z" time))

(defun dl-satan-tank--gather-evidence ()
  "Assemble the evidence window from current panopticon / bough / git state.
Returns the state plist on success; nil if any read errors."
  (condition-case _err
      (let* ((now (dl-satan-tank--time-iso))
             (back (time-subtract (current-time)
                                  dl-satan-tank-evidence-history-seconds))
             (run-started (dl-satan-tank--time-iso back))
             (ctx (list :time_now now
                        :mode_name "tank"
                        :run_id "tank"
                        :current_grammar_version
                        dl-satan-memory-grammar-current-version)))
        (dl-satan-memory-evidence-assemble
         ctx (list :run_started_at run-started :seg_limit 5)))
    (error nil)))

(defun dl-satan-tank--gather-traces ()
  (pcase (condition-case _err
             (dl-satan-memory-store-recent
              :limit dl-satan-tank-trace-limit)
           (error nil))
    (`(ok . ,rows) rows)
    (_ nil)))

(defun dl-satan-tank--recent-runs ()
  "Most recent N run dirs under `dl-satan-runs-dir', newest first."
  (when (file-directory-p dl-satan-runs-dir)
    (let* ((entries (directory-files dl-satan-runs-dir nil "\\`[^.]" t))
           (sorted (sort entries #'string-greaterp))
           out)
      (cl-loop for e in sorted
               for dir = (expand-file-name e dl-satan-runs-dir)
               while (< (length out) dl-satan-tank-event-window-runs)
               when (file-directory-p dir)
               do (push e out))
      (nreverse out))))

(defun dl-satan-tank--read-run-events (run-id)
  "Read transcript.jsonl from RUN-ID, return list of event plists.
Each returned plist gains a `:run' (mode slug) and `:summary' field."
  (let ((path (expand-file-name
               (format "%s/transcript.jsonl" run-id) dl-satan-runs-dir))
        (slug (dl-satan-tank--short-run run-id))
        out)
    (when (file-readable-p path)
      (let ((coding-system-for-read 'utf-8))
        (with-temp-buffer
          (insert-file-contents path)
          (goto-char (point-min))
          (while (not (eobp))
            (let ((line (buffer-substring-no-properties
                         (point) (line-end-position))))
              (unless (string-empty-p (string-trim line))
                (let ((rec (ignore-errors
                             (json-parse-string
                              line :object-type 'plist
                              :array-type 'list
                              :null-object :null :false-object :false))))
                  (when rec
                    (push (plist-put
                           (plist-put (copy-sequence rec) :run slug)
                           :summary
                           (dl-satan-tank--event-summary rec))
                          out)))))
            (forward-line 1)))))
    (nreverse out)))

(defun dl-satan-tank--gather-events ()
  "Tail the last N events from the most recent runs, newest first."
  (let* ((runs (dl-satan-tank--recent-runs))
         (all (cl-loop for r in runs
                       append (dl-satan-tank--read-run-events r)))
         (sorted (sort all (lambda (a b)
                             (string-greaterp
                              (or (plist-get a :ts) "")
                              (or (plist-get b :ts) ""))))))
    (cl-subseq sorted 0 (min dl-satan-tank-event-limit (length sorted)))))

;; ---------------------------------------------------------------------
;; Buffer + mode
;; ---------------------------------------------------------------------

(defvar dl-satan-tank-mode-map
  (let ((m (make-sparse-keymap)))
    (define-key m (kbd "g") #'dl-satan-tank-refresh)
    (define-key m (kbd "q") #'quit-window)
    m)
  "Keymap for `dl-satan-tank-mode'.")

(define-derived-mode dl-satan-tank-mode special-mode "SatanTank"
  "Read-only buffer surfacing live SATAN state.
\\{dl-satan-tank-mode-map}"
  (buffer-disable-undo)
  (setq-local truncate-lines t)
  (add-hook 'kill-buffer-hook #'dl-satan-tank--cancel-timer nil t))

(defun dl-satan-tank--cancel-timer ()
  (when (timerp dl-satan-tank--timer)
    (cancel-timer dl-satan-tank--timer)
    (setq dl-satan-tank--timer nil)))

(defun dl-satan-tank-refresh ()
  "Re-gather and re-render the tank buffer."
  (interactive)
  (let ((buf (get-buffer dl-satan-tank--buffer-name)))
    (when (and buf (buffer-live-p buf))
      (with-current-buffer buf
        (let ((inhibit-read-only t)
              (point-pos (point)))
          (erase-buffer)
          (insert (dl-satan-tank--header (dl-satan-tank--time-iso)))
          (insert (dl-satan-tank--render-evidence
                   (dl-satan-tank--gather-evidence)))
          (insert (dl-satan-tank--render-traces
                   (dl-satan-tank--gather-traces)))
          (insert (dl-satan-tank--render-events
                   (dl-satan-tank--gather-events)))
          (goto-char (min point-pos (point-max))))))))

(defun dl-satan-tank--start-timer ()
  (dl-satan-tank--cancel-timer)
  (when (and dl-satan-tank-refresh-interval
             (numberp dl-satan-tank-refresh-interval))
    (setq dl-satan-tank--timer
          (run-with-timer dl-satan-tank-refresh-interval
                          dl-satan-tank-refresh-interval
                          #'dl-satan-tank--timer-tick))))

(defun dl-satan-tank--timer-tick ()
  (let ((buf (get-buffer dl-satan-tank--buffer-name)))
    (if (and buf (buffer-live-p buf))
        (dl-satan-tank-refresh)
      (dl-satan-tank--cancel-timer))))

;;;###autoload
(defun my/satan-tank ()
  "Pop open the SATAN observation tank."
  (interactive)
  (let ((buf (get-buffer-create dl-satan-tank--buffer-name)))
    (with-current-buffer buf
      (unless (derived-mode-p 'dl-satan-tank-mode)
        (dl-satan-tank-mode)))
    (dl-satan-tank-refresh)
    (dl-satan-tank--start-timer)
    (pop-to-buffer buf)))

(provide 'dl-satan-tank)
;;; dl-satan-tank.el ends here
