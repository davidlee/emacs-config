;;; dl-satan-observer.el --- SATAN outcome observer (Phase 5) -*- lexical-binding: t; -*-

;; Reads prior-run `transcript.jsonl' files to discover model
;; interventions whose attribution window may have matured, so the
;; broker can credit (or not) the motive that drove each one.  Pure
;; scan — does not call any tool, does not write motive state.
;;
;; Phases 5.2 + 5.3 ship the read half:
;;   - 5.2  intervention-tool defcustom (tunable without re-numbering
;;          keys), per-run transcript walk producing intervention
;;          plists keyed by `(run_id . applied_index)' (unfiltered
;;          `actions.json :applied' position so dedup keys stay
;;          stable across config changes), 24h scan across run dirs.
;;   - 5.3  window-mature gate (`dl-satan-observer--mature-p', A11),
;;          durable dedup state in `dl-satan-observer-state-file'
;;          (A13), public `dl-satan-observer-pending' that returns
;;          interventions ripe for classification and
;;          `dl-satan-observer-mark-classified' that appends a
;;          dedup record atomically.
;;
;; The positive predicate (5.4), motive correlation (5.7), trace
;; writer (5.5), and broker integration (5.8) land in subsequent
;; phases.  See `docs/satan/perceptual-design.md' §S5 / §7 / §A10–A14.

(require 'cl-lib)
(require 'subr-x)
(require 'dl-satan-jsonl)
(require 'dl-satan-memory-grammar)
(require 'dl-satan-memory-store)
(require 'dl-satan-motive)
(require 'dl-satan-observer-classify)

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

;; `dl-satan-observer-window-mature-seconds' + `dl-satan-observer-
;; emacs-title-suffix-re' moved to `dl-satan-observer-classify' (T1).

(defcustom dl-satan-observer-state-file
  (expand-file-name "satan/observer.json"
                    (or (getenv "XDG_STATE_HOME")
                        (expand-file-name ".local/state" "~")))
  "Per-intervention dedup state for the outcome observer.
Shared across runs; reads/writes go through tmp + rename for
atomicity (mirrors `dl-satan-sensor-state-file').  Shape:

  (:classified
   ((:run_id STR :applied_index INT
     :classified_at ISO :verdict STR) ...))

A13 — re-running the observer against the same prior transcript
must not double-count a previously-correlated intervention; this
file is the durable side of that invariant."
  :type 'file :group 'dl-satan)

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
;; Maturity gate (A11)
;; ---------------------------------------------------------------------

(defun dl-satan-observer--mature-p (intervention now-t)
  "Return non-nil when INTERVENTION's attribution window has elapsed
at NOW-T (emacs time value).  Maturity threshold is
`dl-satan-observer-window-mature-seconds'.  Interventions without a
parseable `:intervention_emitted_at' are treated as immature — the
observer never classifies records it cannot timestamp."
  (let* ((iso (plist-get intervention :intervention_emitted_at))
         (emitted (and (stringp iso)
                       (condition-case _ (date-to-time iso) (error nil)))))
    (and emitted
         (not (time-less-p
               now-t
               (time-add emitted
                         (seconds-to-time
                          dl-satan-observer-window-mature-seconds)))))))

;; ---------------------------------------------------------------------
;; State file I/O (atomic tmp + rename, mirrors dl-satan-sensor-alerts)
;; ---------------------------------------------------------------------

(defun dl-satan-observer--read-state (path)
  "Return the parsed observer.json plist at PATH, or an empty seed.
Missing file / malformed JSON both seed to `(:classified ())' so the
run proceeds — observer state corruption must not block prepare."
  (cond
   ((not (file-readable-p path)) (list :classified nil))
   (t (condition-case _err
          (with-temp-buffer
            (let ((coding-system-for-read 'utf-8))
              (insert-file-contents path))
            (goto-char (point-min))
            (let ((obj (json-parse-buffer :object-type 'plist
                                          :array-type 'list
                                          :null-object nil
                                          :false-object :false)))
              (or obj (list :classified nil))))
        (error (list :classified nil))))))

(defun dl-satan-observer--write-state (path state)
  "Atomically write STATE plist to PATH as JSON.
Ensures parent dir exists; uses tmp + rename."
  (let ((dir (file-name-directory path)))
    (unless (file-directory-p dir) (make-directory dir t)))
  (let ((tmp (concat path ".tmp"))
        (coding-system-for-write 'utf-8))
    (with-temp-file tmp
      ;; `:classified' is a list of plists — `json-serialize' rejects
      ;; that shape directly.  `dl-satan-jsonl-prepare' walks the
      ;; structure and turns non-plist lists into JSON arrays.
      (insert (json-serialize (dl-satan-jsonl-prepare state)
                              :null-object :null :false-object :false)))
    (rename-file tmp path t)))

(defun dl-satan-observer--key-of (intervention)
  "Return a `(RUN_ID . APPLIED_INDEX)' cons identifying INTERVENTION
for dedup purposes.  Stable across `dl-satan-observer-intervention-
tools' edits because APPLIED_INDEX counts the unfiltered
`actions.json :applied' position."
  (cons (plist-get intervention :run_id)
        (plist-get intervention :applied_index)))

(defun dl-satan-observer--classified-p (intervention state)
  "Return non-nil when STATE already records a verdict for INTERVENTION."
  (let ((key (dl-satan-observer--key-of intervention)))
    (cl-some (lambda (entry)
               (and (equal (car key) (plist-get entry :run_id))
                    (equal (cdr key) (plist-get entry :applied_index))))
             (plist-get state :classified))))

;; ---------------------------------------------------------------------
;; Verdict persistence (Phase 5.6) — counter + trace + dedup
;; ---------------------------------------------------------------------

(defun dl-satan-observer--motive-handle-rows (motive)
  "Convert MOTIVE's `:cue' handles into memory-store-mark handle rows.
Each handle gets a `:rule_id observer.intervention_correlation'
provenance so resonance can later reason about which traces the
observer authored."
  (mapcar
   (lambda (h)
     (list :handle h
           :source (list :rule_id "observer.intervention_correlation"
                         :origin "derived"
                         :evidence_pointer
                         (format "/motive/%s/cue"
                                 (or (plist-get motive :id) "_")))
           :grammar_version dl-satan-memory-grammar-current-version))
   (or (plist-get motive :cue) nil)))

(defun dl-satan-observer--persist-positive (intervention motive verdict now opts)
  "Side-effect bundle for a positive verdict.
Increments MOTIVE's `:worked_count' via the 5.5 rewriter and writes
an `observation' / `auto_rule' trace via
`dl-satan-memory-store-mark'.

NOW is the ISO timestamp (frozen time_now) used as the new
`:last_intervention_at'.  OPTS may contain `:motive-path',
`:touch-footer-fn', `:memory-mark-fn' for test injection.

Returns `(:motive_written BOOL :trace_result CONS :new_worked_count
N)'."
  (let* ((motive-path (or (plist-get opts :motive-path)
                          dl-satan-motive-file))
         (touch-fn (or (plist-get opts :touch-footer-fn)
                       #'dl-satan-motive-touch-footer))
         (mark-fn (or (plist-get opts :memory-mark-fn)
                      #'dl-satan-memory-store-mark))
         (new-count (1+ (or (plist-get motive :worked_count) 0)))
         (motive-written
          (funcall touch-fn (plist-get motive :id) new-count now motive-path))
         (handles (dl-satan-observer--motive-handle-rows motive))
         (metadata
          (list :run_id (plist-get intervention :run_id)
                :applied_index (plist-get intervention :applied_index)
                :tool_name (plist-get intervention :tool_name)
                :motive_id (plist-get motive :id)
                :predicate (plist-get verdict :predicate)
                :verdict (plist-get verdict :verdict)))
         (payload (format "%s: %s applied_index %d → motive %s via %s"
                          (plist-get verdict :verdict)
                          (plist-get intervention :run_id)
                          (plist-get intervention :applied_index)
                          (plist-get motive :id)
                          (or (plist-get verdict :predicate) "_")))
         (trace-result
          (funcall mark-fn
                   :kind "observation"
                   :trace-origin "auto_rule"
                   :source "observer"
                   :observed-start-at
                   (plist-get intervention :intervention_emitted_at)
                   :observed-end-at
                   (dl-satan-observer--window-end-iso intervention)
                   :payload payload
                   :grammar-version dl-satan-memory-grammar-current-version
                   :metadata-json metadata
                   :handles handles)))
    (list :motive_written motive-written
          :trace_result trace-result
          :new_worked_count new-count)))

(defun dl-satan-observer-persist-verdict
    (intervention motive verdict now &optional opts)
  "Persist VERDICT for INTERVENTION against MOTIVE at NOW.

VERDICT is a `dl-satan-observer-classify' output plist.  When
VERDICT's `:verdict' is `\"positive\"', this credits the motive
end-to-end:
  1. text-level rewrite of MOTIVE's footer (`:worked_count' +
     `:last_intervention_at') via `dl-satan-motive-touch-footer'.
  2. observation/auto_rule trace via `dl-satan-memory-store-mark'
     carrying the (run_id, applied_index, motive_id, predicate)
     metadata so a later scorer can reconstruct the correlation.

For any verdict — positive or `\"none\"' — a dedup record is
appended last via `dl-satan-observer-mark-classified'.  Dedup
written LAST: if motive write or trace write fails, the
intervention will be retried on the next tick rather than
silently lost.  v0 trade-off: rare partial-failure may double-
credit; documented and accepted.

OPTS forwards to the lower-level writers (used in tests):
  :motive-path        override `dl-satan-motive-file'
  :state-path         override `dl-satan-observer-state-file'
  :touch-footer-fn    stub `dl-satan-motive-touch-footer'
  :memory-mark-fn     stub `dl-satan-memory-store-mark'

Returns plist:
  (:dedup_written BOOL
   :motive_written BOOL-or-nil
   :trace_result CONS-or-nil
   :new_worked_count N-or-nil)"
  (let* ((opts (or opts '()))
         (positive (equal "positive" (plist-get verdict :verdict)))
         (result (when positive
                   (dl-satan-observer--persist-positive
                    intervention motive verdict now opts))))
    (dl-satan-observer-mark-classified
     intervention (plist-get verdict :verdict) now
     (plist-get opts :state-path))
    (list :dedup_written t
          :motive_written (and result (plist-get result :motive_written))
          :trace_result (and result (plist-get result :trace_result))
          :new_worked_count (and result (plist-get result :new_worked_count)))))

;; ---------------------------------------------------------------------
;; Broker entry (Phase 5.8) — observer.process(run_ctx)
;; ---------------------------------------------------------------------

(defun dl-satan-observer--lookup-motive (motive-id motives)
  "Return the motive plist with id MOTIVE-ID from MOTIVES, or nil."
  (and motive-id
       (cl-find motive-id motives
                :key (lambda (m) (plist-get m :id))
                :test #'equal)))

(defun dl-satan-observer-process (run-ctx &optional opts)
  "Phase 5.8 — classify + persist every pending intervention.
RUN-CTX is the broker prepare plist; `:time_now' supplies NOW.

Sequence:
  1. Read motive file (default `dl-satan-motive-file').
  2. Get pending interventions (5.3) — past maturity gate, not yet
     in dedup state.
  3. For each pending intervention, run
     `dl-satan-observer-classify-for-motives' (5.7) then
     `dl-satan-observer-persist-verdict' (5.6).

Errors during a single intervention's persist are caught and
captured into that entry's `:error' slot; the loop continues so
one bad bundle (or postgres outage) does not block the rest of
the tick.

OPTS forwards to the lower-level helpers (used in tests):
  :motive-path        override `dl-satan-motive-file'
  :state-path         override `dl-satan-observer-state-file'
  :runs-dir           override `dl-satan-runs-dir'
  :motive-fn          stub `dl-satan-motive-read'
  :memory-mark-fn     stub `dl-satan-memory-store-mark'
  :touch-footer-fn    stub `dl-satan-motive-touch-footer'

Returns a summary plist for audit visibility:
  (:processed N
   :positive  N
   :verdicts  LIST-OF (:run_id :applied_index :motive_id :verdict
                       :predicate :reason :error-or-nil))"
  (let* ((opts (or opts '()))
         (now (or (plist-get run-ctx :time_now)
                  (format-time-string "%Y-%m-%dT%T%:z")))
         (motive-path (or (plist-get opts :motive-path)
                          dl-satan-motive-file))
         (state-path (plist-get opts :state-path))
         (runs-dir (plist-get opts :runs-dir))
         (motive-fn (or (plist-get opts :motive-fn)
                        #'dl-satan-motive-read))
         (parsed (funcall motive-fn motive-path))
         (motives (plist-get parsed :motives))
         (pending (condition-case _err
                      (dl-satan-observer-pending now runs-dir state-path)
                    (error nil)))
         (verdicts nil)
         (positive 0))
    (dolist (iv pending)
      (condition-case err
          (let* ((verdict (dl-satan-observer-classify-for-motives iv motives))
                 (motive (dl-satan-observer--lookup-motive
                          (plist-get verdict :motive_id) motives)))
            (dl-satan-observer-persist-verdict iv motive verdict now opts)
            (when (equal "positive" (plist-get verdict :verdict))
              (setq positive (1+ positive)))
            (push (list :run_id (plist-get iv :run_id)
                        :applied_index (plist-get iv :applied_index)
                        :motive_id (plist-get verdict :motive_id)
                        :verdict (plist-get verdict :verdict)
                        :predicate (plist-get verdict :predicate)
                        :reason (plist-get verdict :reason))
                  verdicts))
        (error
         (push (list :run_id (plist-get iv :run_id)
                     :applied_index (plist-get iv :applied_index)
                     :error (error-message-string err))
               verdicts))))
    (list :processed (length pending)
          :positive positive
          :verdicts (nreverse verdicts))))

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

(defun dl-satan-observer-pending (now &optional runs-dir state-path)
  "Return interventions ripe for classification this tick.
Filters `dl-satan-observer-scan-prior-interventions' to entries that
are both (a) past the maturity gate (A11) and (b) not already in the
dedup state file (A13).  NOW is an ISO string or emacs time value.
RUNS-DIR / STATE-PATH default to `dl-satan-runs-dir' and
`dl-satan-observer-state-file'."
  (let* ((now-t (if (stringp now) (date-to-time now) now))
         (state (dl-satan-observer--read-state
                 (or state-path dl-satan-observer-state-file)))
         (all (dl-satan-observer-scan-prior-interventions now runs-dir)))
    (cl-remove-if-not
     (lambda (iv)
       (and (dl-satan-observer--mature-p iv now-t)
            (not (dl-satan-observer--classified-p iv state))))
     all)))

(defun dl-satan-observer-mark-classified (intervention verdict now &optional state-path)
  "Append a dedup record for INTERVENTION + VERDICT to the state file.
VERDICT is a string (e.g. `\"positive\"', `\"none\"').  NOW is an
ISO string or time value used to stamp `:classified_at'.  STATE-PATH
defaults to `dl-satan-observer-state-file'.

Idempotent on `(run_id, applied_index)' — a second call for the
same intervention is a no-op (the earlier verdict wins).  Returns
the state plist that was persisted."
  (let* ((path (or state-path dl-satan-observer-state-file))
         (state (dl-satan-observer--read-state path))
         (now-iso (if (stringp now)
                      now
                    (format-time-string "%Y-%m-%dT%H:%M:%S%z" now))))
    (if (dl-satan-observer--classified-p intervention state)
        state
      (let* ((entry (list :run_id (plist-get intervention :run_id)
                          :applied_index (plist-get intervention :applied_index)
                          :classified_at now-iso
                          :verdict verdict))
             (next (plist-put (copy-sequence state)
                              :classified
                              (append (plist-get state :classified)
                                      (list entry)))))
        (dl-satan-observer--write-state path next)
        next))))

(provide 'dl-satan-observer)
;;; dl-satan-observer.el ends here
