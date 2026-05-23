;;; dl-satan-audit.el --- SATAN run audit log + verifier -*- lexical-binding: t; -*-

;; Append-only artifacts under runs/<run-id>/:
;;   manifest.json    mode / tools / harness / jail / start
;;   bundle.json      frozen input bundle
;;   transcript.jsonl one JSON object per line; :dir in|out|broker, :event, :payload
;;   final.json       validated final from harness, or {status: invalid}
;;   actions.json     {applied, staged, rejected, failed}
;;   stdout.log       raw child stdout (broker tees here)
;;   stderr.log       raw child stderr (process :stderr buffer)
;;   status           terminal: done|failed|timed-out|invalid-protocol
;;
;; `dl-satan-audit-verify-run' answers the six predicates that together prove
;; the SATAN auditability invariant (SATAN.local.md:601-616).

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-jsonl)

(cl-defstruct dl-satan-audit-handle
  dir
  transcript-path
  last-ts
  ;; Phase 0.1: the run_ctx plist built by `dl-satan-broker--prepare'.
  ;; Later phases (sensor alerts, observer) attach pre_spawn / motive
  ;; updates here so audit-close can write them without re-deriving.
  run-ctx)

(defun dl-satan-audit--iso-now ()
  "Return current time as ISO-8601 with microseconds + zone."
  (format-time-string "%Y-%m-%dT%H:%M:%S.%6N%z" nil))

(defun dl-satan-audit--write-json (path obj)
  "Write OBJ as JSON to PATH (utf-8, no backup, atomic via rename)."
  (let ((tmp (concat path ".tmp"))
        (coding-system-for-write 'utf-8))
    (with-temp-file tmp
      (insert (json-serialize (dl-satan-jsonl-prepare obj)
                              :null-object :null :false-object :false)))
    (rename-file tmp path t)))

(defun dl-satan-audit--append-line (path line)
  "Append LINE plus newline to PATH."
  (let ((coding-system-for-write 'utf-8))
    (write-region (concat line "\n") nil path 'append 'silent)))

(defun dl-satan-audit-open (dir manifest bundle &optional run-ctx)
  "Create DIR, write MANIFEST and BUNDLE plists, return an audit handle.
RUN-CTX is the prepare-phase run_ctx plist (Phase 0.1); it is stored
on the handle so audit-close can read percept / sensor-status / etc.
without re-deriving them.  Optional for backwards compatibility with
callers that have not been threaded through prepare yet.

BUNDLE may be nil — T7 PR 5 opens the handle before the context-fn
has produced the bundle so the observer can emit
`intervention.outcome_*' events into the run's transcript.  Caller
finishes the open by invoking `dl-satan-audit-attach-bundle' once
the bundle is built."
  (unless (file-directory-p dir) (make-directory dir t))
  (dl-satan-audit--write-json (expand-file-name "manifest.json" dir) manifest)
  (when bundle
    (dl-satan-audit--write-json (expand-file-name "bundle.json" dir) bundle))
  (let ((tp (expand-file-name "transcript.jsonl" dir)))
    (with-temp-file tp (insert ""))
    (make-dl-satan-audit-handle :dir dir :transcript-path tp :last-ts nil
                                :run-ctx run-ctx)))

(defun dl-satan-audit-attach-bundle (handle bundle)
  "Write BUNDLE plist as `bundle.json' under HANDLE's run directory.
Used by the broker when `dl-satan-audit-open' was called with a nil
bundle to allow pre-bundle observer emits (T7 PR 5)."
  (dl-satan-audit--write-json
   (expand-file-name "bundle.json" (dl-satan-audit-handle-dir handle))
   bundle))

(defun dl-satan-audit-record (handle dir event payload)
  "Append a transcript record.
DIR ∈ in|out|broker.  EVENT is a symbol.  PAYLOAD is a plist/list/string."
  (let* ((ts (dl-satan-audit--iso-now))
         (rec (list :ts ts
                    :dir (symbol-name dir)
                    :event (symbol-name event)
                    :payload (or payload :null))))
    (setf (dl-satan-audit-handle-last-ts handle) ts)
    (dl-satan-audit--append-line
     (dl-satan-audit-handle-transcript-path handle)
     (json-serialize (dl-satan-jsonl-prepare rec)
                     :null-object :null :false-object :false))))

(defun dl-satan-audit-close (handle final actions status)
  "Finalize the run.
FINAL is a plist (or nil).  ACTIONS is a plist with the four model-action
partition keys (:applied :staged :rejected :failed) and OPTIONAL
keys for broker-emitted pre-spawn material:
  :pre_spawn  Phase 0.3 — sensor-alert dispatches and suppressions.
  :observer   Phase 5.8 — outcome observer summary (per-tick
              classification of prior-run interventions).
STATUS is a symbol."
  (let ((dir (dl-satan-audit-handle-dir handle))
        (pre-spawn (plist-get actions :pre_spawn))
        (observer  (plist-get actions :observer)))
    (dl-satan-audit--write-json
     (expand-file-name "final.json" dir)
     (or final (list :status "invalid")))
    (dl-satan-audit--write-json
     (expand-file-name "actions.json" dir)
     (append
      (list :applied  (or (plist-get actions :applied)  [])
            :staged   (or (plist-get actions :staged)   [])
            :rejected (or (plist-get actions :rejected) [])
            :failed   (or (plist-get actions :failed)   []))
      (when pre-spawn (list :pre_spawn pre-spawn))
      (when observer  (list :observer  observer))))
    (let ((coding-system-for-write 'utf-8))
      (write-region (concat (symbol-name status) "\n") nil
                    (expand-file-name "status" dir) nil 'silent))))

(defun dl-satan-audit--list-of-plists-p (val)
  "Non-nil when VAL is a (possibly empty) list of plist-like objects."
  (and (listp val)
       (cl-every (lambda (e)
                   (and (listp e)
                        (or (null e) (keywordp (car e)))))
                 val)))

(defun dl-satan-audit-validate-actions (obj)
  "Return nil if OBJ is a valid actions.json plist, else an error string.
Pure in-memory validator usable from fixtures.  Checks:
  - the four model-action partition keys (`:applied' `:staged'
    `:rejected' `:failed') are arrays of objects;
  - `:pre_spawn', when present, is an array of objects each carrying
    a `:kind' string discriminator.  Unknown discriminant values are
    accepted gracefully (forward compatibility).

The validator deliberately does NOT cross-check counts against
`final.actions' — that invariant belongs to
`dl-satan-audit-p/actions-partition-final', which reads from disk
and knows about `final.json'."
  (cond
   ((not (listp obj)) "actions must be plist")
   ((not (dl-satan-audit--list-of-plists-p (plist-get obj :applied)))
    "applied must be array")
   ((not (dl-satan-audit--list-of-plists-p (plist-get obj :staged)))
    "staged must be array")
   ((not (dl-satan-audit--list-of-plists-p (plist-get obj :rejected)))
    "rejected must be array")
   ((not (dl-satan-audit--list-of-plists-p (plist-get obj :failed)))
    "failed must be array")
   ((plist-member obj :pre_spawn)
    (dl-satan-audit--validate-pre-spawn (plist-get obj :pre_spawn)))))

(defun dl-satan-audit--validate-pre-spawn (val)
  "Return nil if VAL is a valid pre_spawn entry list, else an error string."
  (cond
   ((not (or (null val) (listp val))) "pre_spawn must be array")
   (t
    (let ((idx 0) (err nil))
      (catch 'done
        (dolist (entry val)
          (cond
           ((not (and (listp entry) (or (null entry) (keywordp (car entry)))))
            (setq err (format "pre_spawn[%d] must be object" idx))
            (throw 'done nil))
           ((not (plist-member entry :kind))
            (setq err (format "pre_spawn[%d] missing kind" idx))
            (throw 'done nil))
           ((not (stringp (plist-get entry :kind)))
            (setq err (format "pre_spawn[%d] kind must be string" idx))
            (throw 'done nil)))
          (cl-incf idx)))
      err))))

;; ---------- Intervention event validators (T7) ----------
;;
;; Three audit-log event kinds carry intervention lifecycle per
;; `docs/satan/attributes/outcome-semantics.md' §9.  The validator is
;; broker-internal: it checks payloads before/after they hit
;; `transcript.jsonl', and it checks replay-safety (every
;; `outcome_classified' / `outcome_revised' references a previously-seen
;; `created' in the same stream).
;;
;; Strings (not keywords) at the audit boundary: every closed-set
;; value below is matched against its JSON-string form (e.g. "worked",
;; not :worked).  Elisp keywords survive only inside the classifier.

(defconst dl-satan-audit-intervention-events
  '("intervention.created"
    "intervention.outcome_classified"
    "intervention.outcome_revised")
  "Closed set of intervention audit-event names.")

(defconst dl-satan-audit-intervention-classifications
  '("worked" "neutral" "ignored" "contradicted" "harmful" "unknown")
  "Closed set of outcome classifications (outcome-semantics §1).")

(defconst dl-satan-audit-intervention-confidences
  '("low" "medium" "high")
  "Closed set of confidence levels (outcome-semantics §4).")

(defconst dl-satan-audit-intervention-maturities
  '("pending" "mature" "stale")
  "Closed set of maturity states (outcome-semantics §3).")

(defconst dl-satan-audit-intervention-sources
  '("auto" "manual")
  "Closed set of verdict-emit sources (outcome-semantics §2).")

(defconst dl-satan-audit-intervention-severities
  '("low" "medium" "high")
  "Closed set of intervention severities (attributes.brief §3.1).")

(defconst dl-satan-audit-intervention-kinds
  '("inbox" "notify" "visible_sign" "proposal" "patch_job"
    "accuse" "ask" "delay" "quarantine" "surface")
  "Closed set of intervention kinds (attributes.brief §3.1).")

(defun dl-satan-audit--iv-key-name (key)
  (substring (symbol-name key) 1))

(defun dl-satan-audit--iv-require-string (payload key)
  "Require KEY in PAYLOAD to be a non-empty string."
  (cond
   ((not (plist-member payload key))
    (format "missing required field: %s" (dl-satan-audit--iv-key-name key)))
   ((not (stringp (plist-get payload key)))
    (format "field %s must be string" (dl-satan-audit--iv-key-name key)))
   ((string-empty-p (plist-get payload key))
    (format "field %s must be non-empty" (dl-satan-audit--iv-key-name key)))))

(defun dl-satan-audit--iv-require-enum (payload key allowed)
  "Require KEY in PAYLOAD to be a string drawn from ALLOWED."
  (or (dl-satan-audit--iv-require-string payload key)
      (unless (member (plist-get payload key) allowed)
        (format "field %s must be one of %S, got %S"
                (dl-satan-audit--iv-key-name key)
                allowed
                (plist-get payload key)))))

(defun dl-satan-audit--iv-require-integer (payload key)
  "Require KEY in PAYLOAD to be a non-negative integer."
  (cond
   ((not (plist-member payload key))
    (format "missing required field: %s" (dl-satan-audit--iv-key-name key)))
   ((not (integerp (plist-get payload key)))
    (format "field %s must be integer" (dl-satan-audit--iv-key-name key)))
   ((< (plist-get payload key) 0)
    (format "field %s must be non-negative" (dl-satan-audit--iv-key-name key)))))

(defun dl-satan-audit--iv-require-array (payload key)
  "Require KEY in PAYLOAD to be a JSON array (nil counts as the empty array)."
  (cond
   ((not (plist-member payload key))
    (format "missing required field: %s" (dl-satan-audit--iv-key-name key)))
   ((not (listp (plist-get payload key)))
    (format "field %s must be array" (dl-satan-audit--iv-key-name key)))))

(defun dl-satan-audit--iv-require-object (payload key)
  "Require KEY in PAYLOAD to be a JSON object (plist; nil treated as `{}')."
  (cond
   ((not (plist-member payload key))
    (format "missing required field: %s" (dl-satan-audit--iv-key-name key)))
   (t
    (let ((v (plist-get payload key)))
      (cond
       ((eq v :null) nil)
       ((null v) nil)
       ((and (consp v) (keywordp (car v))) nil)
       (t (format "field %s must be object"
                  (dl-satan-audit--iv-key-name key))))))))

(defun dl-satan-audit--iv-require-string-or-null (payload key)
  "Require KEY in PAYLOAD to be a string OR null (`:null'/nil)."
  (cond
   ((not (plist-member payload key))
    (format "missing required field: %s" (dl-satan-audit--iv-key-name key)))
   (t (let ((v (plist-get payload key)))
        (unless (or (eq v :null) (null v) (stringp v))
          (format "field %s must be string or null"
                  (dl-satan-audit--iv-key-name key)))))))

(defun dl-satan-audit--validate-intervention-created (payload)
  "Validate an `intervention.created' payload.  Return error string or nil."
  (or (dl-satan-audit--iv-require-string  payload :intervention_id)
      (dl-satan-audit--iv-require-string  payload :run_id)
      (dl-satan-audit--iv-require-string  payload :ts)
      (dl-satan-audit--iv-require-string  payload :mode)
      (dl-satan-audit--iv-require-enum    payload :kind
                                          dl-satan-audit-intervention-kinds)
      (dl-satan-audit--iv-require-string  payload :target_surface)
      (dl-satan-audit--iv-require-string  payload :message)
      (dl-satan-audit--iv-require-string-or-null payload :related_motive_id)
      (dl-satan-audit--iv-require-array   payload :cue_handles)
      (dl-satan-audit--iv-require-string  payload :expected_outcome)
      (dl-satan-audit--iv-require-integer payload :outcome_window_minutes)
      (dl-satan-audit--iv-require-enum    payload :severity
                                          dl-satan-audit-intervention-severities)))

(defun dl-satan-audit--validate-intervention-outcome (payload revision-p created-ids)
  "Validate an outcome payload.  REVISION-P t for `outcome_revised'.
CREATED-IDS hash-table (string → t) of seen intervention_ids.  Returns
nil or an error string."
  (or (dl-satan-audit--iv-require-string payload :intervention_id)
      (let ((iid (plist-get payload :intervention_id)))
        (unless (gethash iid created-ids)
          (format "intervention_id %S has no prior intervention.created" iid)))
      (dl-satan-audit--iv-require-enum payload :classification
                                       dl-satan-audit-intervention-classifications)
      (dl-satan-audit--iv-require-enum payload :confidence
                                       dl-satan-audit-intervention-confidences)
      (dl-satan-audit--iv-require-object payload :evidence)
      (dl-satan-audit--iv-require-enum payload :maturity
                                       dl-satan-audit-intervention-maturities)
      (dl-satan-audit--iv-require-string payload :next_revisit_at)
      (dl-satan-audit--iv-require-enum payload :source
                                       dl-satan-audit-intervention-sources)
      (dl-satan-audit--iv-require-string payload :classified_at)
      ;; §9 invariants — classifications restricted to manual source in v1.
      (let ((cls (plist-get payload :classification))
            (src (plist-get payload :source)))
        (cond
         ((and (equal cls "harmful") (equal src "auto"))
          "classification=harmful requires source=manual (outcome-semantics §2 invariant 1)")
         ((and (equal cls "contradicted") (equal src "auto"))
          "classification=contradicted requires source=manual in v1 (outcome-semantics §2 invariant 2)")))
      ;; §2 invariant 3 — pending maturity ⇒ unknown classification.
      (let ((mat (plist-get payload :maturity))
            (cls (plist-get payload :classification)))
        (when (and (equal mat "pending") (not (equal cls "unknown")))
          "maturity=pending requires classification=unknown (outcome-semantics §2 invariant 3)"))
      (when revision-p
        (or (dl-satan-audit--iv-require-string payload :revises)
            (let ((rid (plist-get payload :revises)))
              (unless (gethash rid created-ids)
                (format "revises %S has no prior intervention.created" rid)))))))

(defun dl-satan-audit-validate-intervention-event (event payload created-ids)
  "Validate an intervention audit-log EVENT with PAYLOAD.
EVENT is the event-name string (one of
`dl-satan-audit-intervention-events').  CREATED-IDS is a hash-table
\(string → t) of intervention_ids whose `intervention.created' has
appeared earlier in the same audit stream.  Returns nil on success or
an error string on failure.  Does NOT mutate CREATED-IDS — the caller
inserts after a successful `created' record."
  (cond
   ((not (stringp event)) "event must be string")
   ((not (member event dl-satan-audit-intervention-events))
    (format "unknown intervention event: %s" event))
   ((not (or (null payload) (and (consp payload) (keywordp (car payload)))))
    "payload must be plist")
   (t
    (pcase event
      ("intervention.created"
       (dl-satan-audit--validate-intervention-created payload))
      ("intervention.outcome_classified"
       (dl-satan-audit--validate-intervention-outcome payload nil created-ids))
      ("intervention.outcome_revised"
       (dl-satan-audit--validate-intervention-outcome payload t created-ids))))))

(defun dl-satan-audit-validate-intervention-stream (events)
  "Validate EVENTS (list of (EVENT . PAYLOAD) in transcript order).
Maintains the created-ids set across the stream so replay-safety
\(`outcome_classified' / `outcome_revised' must follow a `created' with
the same `intervention_id') is enforced.

Returns nil on success or `(:idx N :reason STR)' on the first failure."
  (let ((created-ids (make-hash-table :test 'equal))
        (idx 0)
        (failure nil))
    (catch 'done
      (dolist (rec events)
        (let* ((event (car rec))
               (payload (cdr rec))
               (err (dl-satan-audit-validate-intervention-event
                     event payload created-ids)))
          (if err
              (progn
                (setq failure (list :idx idx :reason err))
                (throw 'done nil))
            (when (equal event "intervention.created")
              (puthash (plist-get payload :intervention_id) t created-ids))))
        (cl-incf idx)))
    failure))

;; ---------- Verifier ----------

(defun dl-satan-audit--read-json (path)
  "Read PATH as JSON, return plist or signal."
  (let ((coding-system-for-read 'utf-8))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (json-parse-buffer :object-type 'plist
                         :array-type 'list
                         :null-object :null
                         :false-object :false))))

(defun dl-satan-audit--read-jsonl (path)
  "Read PATH as JSONL, return list of plists in order."
  (let ((coding-system-for-read 'utf-8))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (let (out)
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (point) (line-end-position))))
            (unless (string-empty-p (string-trim line))
              (push (json-parse-string line
                                       :object-type 'plist
                                       :array-type 'list
                                       :null-object :null
                                       :false-object :false)
                    out))
            (forward-line 1)))
        (nreverse out)))))

(defun dl-satan-audit-p/has-manifest (dir)
  (and (file-readable-p (expand-file-name "manifest.json" dir))
       (ignore-errors (dl-satan-audit--read-json
                       (expand-file-name "manifest.json" dir)))
       t))

(defun dl-satan-audit-p/has-bundle (dir)
  (and (file-readable-p (expand-file-name "bundle.json" dir))
       (ignore-errors (dl-satan-audit--read-json
                       (expand-file-name "bundle.json" dir)))
       t))

(defun dl-satan-audit-p/transcript-monotonic (dir)
  (let ((records (dl-satan-audit--read-jsonl
                  (expand-file-name "transcript.jsonl" dir)))
        (prev nil)
        (ok t))
    (dolist (r records)
      (let ((ts (plist-get r :ts)))
        (when (and prev (string< ts prev)) (setq ok nil))
        (setq prev ts)))
    ok))

(defun dl-satan-audit-p/calls-match-results (dir)
  "Every tool-call id has a matching tool-result id."
  (let ((records (dl-satan-audit--read-jsonl
                  (expand-file-name "transcript.jsonl" dir)))
        (calls (make-hash-table :test 'equal))
        (results (make-hash-table :test 'equal)))
    (dolist (r records)
      (let ((ev (plist-get r :event))
            (p  (plist-get r :payload)))
        (cond
         ((equal ev "tool-call")
          (when-let ((id (plist-get p :id))) (puthash id t calls)))
         ((or (equal ev "tool-result") (equal ev "tool-denied"))
          (when-let ((id (plist-get p :id))) (puthash id t results))))))
    (let ((ok t))
      (maphash (lambda (id _) (unless (gethash id results) (setq ok nil))) calls)
      ok)))

(defun dl-satan-audit-p/actions-partition-final (dir)
  "Union of applied|staged|rejected|failed equals final.actions (count)."
  (let* ((final   (ignore-errors
                    (dl-satan-audit--read-json
                     (expand-file-name "final.json" dir))))
         (actions (ignore-errors
                    (dl-satan-audit--read-json
                     (expand-file-name "actions.json" dir))))
         (fa (and final (plist-get final :actions)))
         (sum (+ (length (or (plist-get actions :applied)  '()))
                 (length (or (plist-get actions :staged)   '()))
                 (length (or (plist-get actions :rejected) '()))
                 (length (or (plist-get actions :failed)   '())))))
    (cond
     ((null final) nil)
     ((eq fa :null) (= 0 sum))
     ((listp fa) (= (length fa) sum))
     (t nil))))

(defun dl-satan-audit-p/pre-spawn-shape (dir)
  "Return t when actions.json's optional `pre_spawn' is structurally valid.
Absent key is fine; present means each entry is an object with a
`:kind' string discriminator.  Pre_spawn entries do not count toward
the {applied,staged,rejected,failed} partition invariant."
  (let* ((actions (ignore-errors
                    (dl-satan-audit--read-json
                     (expand-file-name "actions.json" dir)))))
    (cond
     ((null actions) nil)
     ((not (plist-member actions :pre_spawn)) t)
     (t (null (dl-satan-audit--validate-pre-spawn
               (plist-get actions :pre_spawn)))))))

(defun dl-satan-audit-p/status-terminal (dir)
  (let ((p (expand-file-name "status" dir)))
    (and (file-readable-p p)
         (let ((s (string-trim
                   (with-temp-buffer
                     (insert-file-contents p) (buffer-string)))))
           (member s '("done" "failed" "timed-out" "invalid-protocol"
                       "budget-exceeded"))))))

(defun dl-satan-audit-verify-run (dir)
  "Return t if all audit predicates pass for DIR.
Otherwise return an alist of (PREDICATE-SYMBOL . nil) pairs."
  (let ((checks
         (list
          (cons 'has-manifest        (dl-satan-audit-p/has-manifest dir))
          (cons 'has-bundle          (dl-satan-audit-p/has-bundle dir))
          (cons 'transcript-monotonic (dl-satan-audit-p/transcript-monotonic dir))
          (cons 'calls-match-results (dl-satan-audit-p/calls-match-results dir))
          (cons 'actions-partition-final (dl-satan-audit-p/actions-partition-final dir))
          (cons 'pre-spawn-shape     (dl-satan-audit-p/pre-spawn-shape dir))
          (cons 'status-terminal     (dl-satan-audit-p/status-terminal dir)))))
    (let ((failed (cl-remove-if #'cdr checks)))
      (if (null failed) t failed))))

(provide 'dl-satan-audit)
;;; dl-satan-audit.el ends here
