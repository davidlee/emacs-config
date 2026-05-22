;;; dl-satan-observer.el --- SATAN outcome observer (Phase 5) -*- lexical-binding: t; -*-

;; Reads prior-run `transcript.jsonl' files to discover model
;; interventions whose attribution window may have matured, so the
;; broker can credit (or not) the motive that drove each one.  Pure
;; scan — does not call any tool, does not write motive state.
;;
;; Phase 5.2 ships only the discovery skeleton:
;;   - intervention-tool defcustom (tunable without re-numbering keys)
;;   - per-run transcript walk producing intervention plists keyed by
;;     `(run_id . applied_index)' — the applied_index is the position
;;     in `actions.json :applied' (unfiltered by the intervention set,
;;     so dedup keys stay stable across config changes)
;;   - flat scan across the prior N hours of run dirs
;;
;; The window-mature gate (5.3), dedup state file (5.3), positive
;; predicate (5.4), motive correlation (5.7), and trace writer (5.5)
;; land in subsequent phases.  See `docs/satan/perceptual-design.md'
;; §S5 / §7 / §A10–A14.

(require 'cl-lib)
(require 'subr-x)
(require 'dl-satan-jsonl)

;; Lazy require — `dl-satan-broker' will require this module in 5.8 to
;; wire the observer into prepare.  Declaring the broker symbols here
;; lets the byte-compiler see them; the actual `require' happens at
;; scan time so observer.el's load does not pull broker.el.
(declare-function dl-satan-broker-list-run-dirs "dl-satan-broker" (runs-dir))
(defvar dl-satan-runs-dir)

;; ---------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------

(defcustom dl-satan-observer-intervention-tools
  '("notify_send" "inbox_append" "proposal_stage"
    "org_update_owned_block" "sway_border_set")
  "Tool names whose `action-applied' transcript records count as
interventions for outcome attribution (§S5).  Reads (`bough_read',
`activity_read', `memory_*') are not interventions.  Tuning this
list does NOT re-number dedup keys — they anchor to the unfiltered
`actions.json :applied' position, so a re-scan after a defcustom
change still recognises previously-classified interventions."
  :type '(repeat string) :group 'dl-satan)

(defcustom dl-satan-observer-scan-window-hours 24
  "Hours of prior-run history to walk on each tick.
Interventions whose run started before `now - this' are ignored.
The v0 attribution window is 30 min; 24 h gives generous slack for
broker gaps (quiet hours, system off) per A11."
  :type 'integer :group 'dl-satan)

;; ---------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------

(defconst dl-satan-observer--failed-suffix ".FAILED"
  "Trailing suffix the broker appends to failed run dirs.
Mirrors `dl-satan-broker--failed-suffix'; observer copies the
constant so it can decode dir leaves without requiring broker at
load time (see lazy-require note above).")

(defun dl-satan-observer--run-id-from-dir (run-dir)
  "Return the run-id stem parsed from RUN-DIR's leaf name."
  (let ((leaf (file-name-nondirectory (directory-file-name run-dir))))
    (if (string-suffix-p dl-satan-observer--failed-suffix leaf)
        (substring leaf 0 (- (length leaf)
                             (length dl-satan-observer--failed-suffix)))
      leaf)))

(defun dl-satan-observer--run-started-at (run-id)
  "Decode RUN-ID's `YYYYMMDDTHHMMSS' prefix into an emacs time value.
Returns nil if RUN-ID lacks a parseable stem.  Decoded in the
ambient TZ (matches how the broker mints ids)."
  (when (and (stringp run-id)
             (string-match
              (concat "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)"
                      "T\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)")
              run-id))
    (encode-time
     (string-to-number (match-string 6 run-id))
     (string-to-number (match-string 5 run-id))
     (string-to-number (match-string 4 run-id))
     (string-to-number (match-string 3 run-id))
     (string-to-number (match-string 2 run-id))
     (string-to-number (match-string 1 run-id)))))

(defun dl-satan-observer--in-scan-window-p (run-id now-t window-seconds)
  "Return non-nil when RUN-ID's start time lies in the scan window.
The window is `[NOW-T - WINDOW-SECONDS, NOW-T]' (inclusive)."
  (let ((started (dl-satan-observer--run-started-at run-id)))
    (and started
         ;; not in the future
         (not (time-less-p now-t started))
         ;; not older than the window
         (not (time-less-p started
                           (time-subtract now-t
                                          (seconds-to-time window-seconds)))))))

(defun dl-satan-observer--applied-interventions-in-run (run-dir)
  "Walk RUN-DIR/`transcript.jsonl' and return a list of intervention
plists for every `action-applied' record whose payload `:type' is in
`dl-satan-observer-intervention-tools'.

Each entry:
  (:run_id STR :run_dir STR
   :applied_index INT
   :tool_name STR
   :intervention_emitted_at ISO
   :payload PLIST)

`applied_index' counts ALL applied actions in transcript order,
NOT just the intervention-tool subset — this keeps the dedup key
stable across `dl-satan-observer-intervention-tools' tuning."
  (let* ((tpath (expand-file-name "transcript.jsonl" run-dir))
         (records (dl-satan-jsonl-read-file tpath))
         (run-id (dl-satan-observer--run-id-from-dir run-dir))
         (applied-index 0)
         out)
    (dolist (rec records)
      (when (and (equal (plist-get rec :dir) "broker")
                 (equal (plist-get rec :event) "action-applied"))
        (let* ((payload (plist-get rec :payload))
               (tool-name (and (listp payload) (plist-get payload :type))))
          (when (member tool-name dl-satan-observer-intervention-tools)
            (push (list :run_id run-id
                        :run_dir run-dir
                        :applied_index applied-index
                        :tool_name tool-name
                        :intervention_emitted_at (plist-get rec :ts)
                        :payload payload)
                  out))
          (setq applied-index (1+ applied-index)))))
    (nreverse out)))

;; ---------------------------------------------------------------------
;; Public entry
;; ---------------------------------------------------------------------

(defun dl-satan-observer-scan-prior-interventions (now &optional runs-dir)
  "Return a flat list of intervention plists drawn from prior runs.
Walks every run under RUNS-DIR (default `dl-satan-runs-dir') whose
start time falls within `[now - dl-satan-observer-scan-window-hours,
now]'.  NOW is an ISO8601 string or an emacs time value.

Order: per-run transcript order, runs concatenated in
`dl-satan-broker-list-run-dirs' order (unspecified — caller sorts
if it matters).  Phase 5.3 layers the window-mature gate and dedup
on top; the raw scan is deterministic per disk state."
  (require 'dl-satan-broker)
  (let* ((now-t (if (stringp now) (date-to-time now) now))
         (window-s (* 3600 dl-satan-observer-scan-window-hours))
         (base (or runs-dir dl-satan-runs-dir))
         (run-dirs (dl-satan-broker-list-run-dirs base))
         out)
    (dolist (run-dir run-dirs)
      (let ((run-id (dl-satan-observer--run-id-from-dir run-dir)))
        (when (dl-satan-observer--in-scan-window-p run-id now-t window-s)
          (setq out (nconc out (dl-satan-observer--applied-interventions-in-run
                                run-dir))))))
    out))

(provide 'dl-satan-observer)
;;; dl-satan-observer.el ends here
