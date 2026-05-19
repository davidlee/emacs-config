;;; dl-satan-tick.el --- Tick mode family for SATAN -*- lexical-binding: t; -*-

;; Tick modes are short, frequent, lightly-budgeted SATAN runs.  A single
;; systemd timer fires the broker every ~30 minutes; the broker picks one
;; tick mode from `dl-satan-tick-pool' by weight and runs it.  Quiet hours
;; suppress the run entirely so SATAN does not nudge during sleep.
;;
;; Per-tick budget is tight by design (≤10000 tokens, ≤4 tool calls, ≤30s).
;; The daily ceiling in `dl-satan-budget' caps total spend regardless.

(require 'cl-lib)
(require 'subr-x)
(require 'dl-satan-mode)
(require 'dl-satan-context)
(require 'dl-satan-output)

(defcustom dl-satan-tick-pool '(("tick-pulse" . 1))
  "Weighted alist of tick mode names.  Each entry is (MODE-NAME . WEIGHT).
`dl-satan-tick-pick' samples by weight; total weight must be positive."
  :type '(alist :key-type string :value-type integer)
  :group 'dl-satan)

(defcustom dl-satan-tick-quiet-hours nil ; was '(22 . 7); disabled while iterating
  "Quiet-hours window as (START-HOUR . END-HOUR), inclusive of START and
exclusive of END.  Set start ≥ end for a wraparound window (e.g. 22..7
suppresses 22:00 through 06:59).  Set to nil to disable quiet hours."
  :type '(choice (cons (integer :tag "Start hour")
                   (integer :tag "End hour"))
           (const :tag "Disabled" nil))
  :group 'dl-satan)

(defun dl-satan-tick-quiet-p (&optional time)
  "Return non-nil if TIME (or now) falls within `dl-satan-tick-quiet-hours'."
  (when dl-satan-tick-quiet-hours
    (let* ((h (string-to-number (format-time-string "%H" time)))
            (start (car dl-satan-tick-quiet-hours))
            (end   (cdr dl-satan-tick-quiet-hours)))
      (if (< start end)
        (and (>= h start) (< h end))
        (or (>= h start) (< h end))))))

(defun dl-satan-tick-pick (&optional pool)
  "Sample a tick mode name from POOL by weight.  Defaults to
`dl-satan-tick-pool'.  Returns nil if POOL is empty or total weight ≤ 0."
  (let* ((pool (or pool dl-satan-tick-pool))
          (total (apply #'+ (mapcar #'cdr pool))))
    (when (and pool (> total 0))
      (let ((n (random total))
             (acc 0)
             picked)
        (dolist (entry pool)
          (unless picked
            (setq acc (+ acc (cdr entry)))
            (when (< n acc) (setq picked (car entry)))))
        picked))))

(defun dl-satan-tick-register (short-name &rest overrides)
  "Register a tick mode named `tick-SHORT-NAME' using sensible defaults.
OVERRIDES is a plist that wins over the defaults: useful for raising
budgets, swapping the tool list, or pointing at a different prompt.
The prompt file defaults to `<prompts>/tick/SHORT-NAME.txt'."
  (let* ((full-name (concat "tick-" short-name))
          (prompt-file (or (plist-get overrides :prompt-file)
                         (expand-file-name
                           (concat "tick/" short-name ".txt")
                           dl-satan-prompts-dir)))
          (defaults
            (list :name full-name
              :prompt-file prompt-file
              :context-fn 'dl-satan-context-tick
              :tools '("org_read_context" "notify_send" "inbox_append"
                        "activity_read" "notes_recent"
                        "sway_border_set" "sway_border_reset"
                        "bough_read" "memory_mark" "memory_resonate"
                        "memory_show_trace")
              :capabilities '(notify inbox-write memory-write)
              :harness '(:cmd "jailed-satan-gptel-harness" :args () :env nil)
              :jail-profile 'specDev
              :provider 'openrouter
              :model "anthropic/claude-haiku-4.5"
              :budget-tokens 10000
              :output-handler 'dl-satan-output/tick
              :auto-apply 'owned
              :timeout-seconds 30
              :budget-tool-calls 4))
          (spec defaults))
    (cl-loop for (k v) on overrides by #'cddr
      do (setq spec (plist-put spec k v)))
    (dl-satan-mode-register spec)
    full-name))

;; Default registration: a single lightweight pulse tick.
(dl-satan-tick-register "pulse")

(defun my/satan-tick ()
  "Run one tick: pick a mode from `dl-satan-tick-pool', skip in quiet hours.
Returns the run-id, or nil if the tick was suppressed."
  (interactive)
  (cond
    ((dl-satan-tick-quiet-p)
      (when (called-interactively-p 'interactive)
        (message "SATAN tick: skipped (quiet hours)"))
      nil)
    (t
      (let ((name (dl-satan-tick-pick)))
        (cond
          ((null name)
            (when (called-interactively-p 'interactive)
              (message "SATAN tick: empty pool"))
            nil)
          (t
            (let ((run-id (my/satan-run name)))
              (when (called-interactively-p 'interactive)
                (message "SATAN tick %s started: %s" name run-id))
              run-id)))))))

(provide 'dl-satan-tick)
;;; dl-satan-tick.el ends here
