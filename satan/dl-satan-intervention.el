;;; dl-satan-intervention.el --- intervention projection rebuild + API -*- lexical-binding: t; -*-

;; T7 — first-class intervention records.
;;
;; This module owns the projection of intervention audit-events into
;; the `satan_interventions' / `satan_intervention_outcomes' tables
;; created by migration 0006_interventions.sql.  The audit log
;; (transcript.jsonl per run) is the source of truth; the tables are
;; rebuildable.
;;
;; PR 2 lands the rebuild CLI:
;;   - `dl-satan-intervention-rebuild' replays every intervention event
;;     across all runs into the projection in (ts, run-id, seq) order.
;;     Idempotent: a second rebuild yields byte-identical rows.
;;   - `my/satan-rebuild-interventions' is the interactive command;
;;     `satan/bin/satan-rebuild-interventions' is the CLI wrapper.
;;
;; PR 3 adds the write/read API used by handlers and the observer:
;;
;;   (dl-satan-intervention-create &key CTX KIND TARGET-SURFACE MESSAGE
;;                                      RELATED-MOTIVE-ID CUE-HANDLES
;;                                      EXPECTED-OUTCOME OUTCOME-WINDOW-MINUTES
;;                                      SEVERITY)
;;     Mint a stable `<run-id>.iv<NNN>' id, emit `intervention.created' into
;;     the run's transcript.jsonl, and INSERT into `satan_interventions'
;;     (ON CONFLICT DO NOTHING).  Returns the intervention-id string.
;;
;;   (dl-satan-intervention-classify &key CTX INTERVENTION-ID CLASSIFICATION
;;                                        CONFIDENCE EVIDENCE MATURITY
;;                                        NEXT-REVISIT-AT SOURCE CLASSIFIED-AT
;;                                        MARKED-BY NOTES)
;;     Audit-emit + UPSERT a verdict.  Emits `intervention.outcome_classified'
;;     when no prior outcome row exists; `intervention.outcome_revised' (with
;;     `:revises' set to the intervention-id) otherwise.  Returns `ok' or
;;     signals on validation/DB failure.
;;
;;   (dl-satan-intervention-lookup INTERVENTION-ID &optional DB)
;;     Return `(:intervention <row-plist> :outcome <row-plist-or-nil>)' or nil.
;;
;;   (dl-satan-intervention-pending NOW &optional DB)
;;     Return list of intervention plists whose maturity window has elapsed
;;     and which have no outcome row.  NOW is an ISO8601 string.
;;
;; **Transaction discipline:** audit-emit happens first (canonical); the
;; projection INSERT is a separate psql round-trip in the same handler
;; call.  An audit-only success with a failed projection insert is
;; recoverable via `my/satan-rebuild-interventions'.

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-audit)             ; validators + closed-set constants
(require 'dl-satan-jsonl)              ; prepare arrays/alists for json-serialize
(require 'dl-satan-memory-migrate)    ; psql runner + database defcustoms

;; ---------- runs-dir resolution ----------

(defun dl-satan-intervention--runs-dir (&optional override)
  "Return the runs root directory.  OVERRIDE wins; else `dl-satan-runs-dir'."
  (or override
      (and (boundp 'dl-satan-runs-dir) dl-satan-runs-dir)
      (user-error
       "dl-satan-intervention: no runs-dir (set `dl-satan-runs-dir' or pass override)")))

(defun dl-satan-intervention--transcript-files (runs-dir)
  "Return sorted list of transcript.jsonl paths under RUNS-DIR.
Walks YYYY-MM-DD/<run-id>/ buckets; flat runs/<run-id>/ also supported."
  (let ((acc '()))
    (dolist (entry (and (file-directory-p runs-dir)
                        (directory-files runs-dir t "\\`[^.]" t)))
      (when (file-directory-p entry)
        (let ((direct (expand-file-name "transcript.jsonl" entry)))
          (if (file-readable-p direct)
              (push direct acc)
            (dolist (sub (and (file-directory-p entry)
                              (directory-files entry t "\\`[^.]" t)))
              (let ((p (expand-file-name "transcript.jsonl" sub)))
                (when (file-readable-p p) (push p acc))))))))
    (sort acc #'string<)))

;; ---------- transcript reader ----------

(defun dl-satan-intervention--read-jsonl (path)
  "Read PATH as JSONL, returning a list of plists in file order."
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

(defun dl-satan-intervention--run-id-from-path (path)
  "Derive a run-id from PATH (parent directory name)."
  (file-name-nondirectory
   (directory-file-name (file-name-directory path))))

(defun dl-satan-intervention--collect-events (runs-dir)
  "Collect every intervention event under RUNS-DIR.
Returns a list of plists with keys (:ts :event :payload :run_id :seq :path).
SEQ is the within-file record index, used as a tiebreaker."
  (let (out)
    (dolist (path (dl-satan-intervention--transcript-files runs-dir))
      (let ((records (dl-satan-intervention--read-jsonl path))
            (file-run-id (dl-satan-intervention--run-id-from-path path))
            (seq 0))
        (dolist (rec records)
          (let ((event (plist-get rec :event)))
            (when (member event dl-satan-audit-intervention-events)
              (push (list :ts      (plist-get rec :ts)
                          :event   event
                          :payload (plist-get rec :payload)
                          :run_id  file-run-id
                          :seq     seq
                          :path    path)
                    out)))
          (cl-incf seq))))
    (nreverse out)))

(defun dl-satan-intervention--sort-events (events)
  "Order EVENTS by (ts, run_id, seq) ascending."
  (sort (copy-sequence events)
        (lambda (a b)
          (let ((ta (plist-get a :ts)) (tb (plist-get b :ts)))
            (cond
             ((string< ta tb) t)
             ((string< tb ta) nil)
             (t
              (let ((ra (plist-get a :run_id)) (rb (plist-get b :run_id)))
                (cond
                 ((string< ra rb) t)
                 ((string< rb ra) nil)
                 (t (< (plist-get a :seq) (plist-get b :seq)))))))))))

;; ---------- SQL generation ----------

(defun dl-satan-intervention--quote-text (s)
  "Return the SQL literal for S; supports NULL via nil/:null."
  (cond
   ((or (null s) (eq s :null)) "NULL")
   ((stringp s)
    (concat "'" (replace-regexp-in-string "'" "''" s) "'"))
   (t (error "dl-satan-intervention--quote-text: not stringy: %S" s))))

(defun dl-satan-intervention--quote-jsonb (obj)
  "Serialize OBJ as JSON then wrap as an SQL literal `'…'::jsonb'.
Runs OBJ through `dl-satan-jsonl-prepare' so post-JSON-parse lists
become vectors before serialization."
  (let* ((prepared (dl-satan-jsonl-prepare (or obj :null)))
         (coded (json-serialize prepared
                                :null-object :null
                                :false-object :false)))
    (concat (dl-satan-intervention--quote-text coded) "::jsonb")))

(defun dl-satan-intervention--insert-created-sql (payload)
  "Return SQL INSERT for an intervention.created PAYLOAD."
  (concat
   "INSERT INTO satan_interventions ("
   "id, run_id, ts, mode, kind, target_surface, message, "
   "related_motive_id, cue_handles_json, expected_outcome, "
   "outcome_window_minutes, severity) VALUES ("
   (mapconcat
    #'identity
    (list (dl-satan-intervention--quote-text (plist-get payload :intervention_id))
          (dl-satan-intervention--quote-text (plist-get payload :run_id))
          (concat (dl-satan-intervention--quote-text (plist-get payload :ts))
                  "::timestamptz")
          (dl-satan-intervention--quote-text (plist-get payload :mode))
          (dl-satan-intervention--quote-text (plist-get payload :kind))
          (dl-satan-intervention--quote-text (plist-get payload :target_surface))
          (dl-satan-intervention--quote-text (plist-get payload :message))
          (dl-satan-intervention--quote-text (plist-get payload :related_motive_id))
          (dl-satan-intervention--quote-jsonb (or (plist-get payload :cue_handles) '()))
          (dl-satan-intervention--quote-text (plist-get payload :expected_outcome))
          (number-to-string (plist-get payload :outcome_window_minutes))
          (dl-satan-intervention--quote-text (plist-get payload :severity)))
    ", ")
   ") ON CONFLICT (id) DO NOTHING;"))

(defun dl-satan-intervention--upsert-outcome-sql (payload)
  "Return SQL UPSERT for an outcome_classified / outcome_revised PAYLOAD."
  (concat
   "INSERT INTO satan_intervention_outcomes ("
   "intervention_id, classification, confidence, evidence_json, "
   "maturity, next_revisit_at, source, classified_at, revises, "
   "marked_by, notes) VALUES ("
   (mapconcat
    #'identity
    (list (dl-satan-intervention--quote-text (plist-get payload :intervention_id))
          (dl-satan-intervention--quote-text (plist-get payload :classification))
          (dl-satan-intervention--quote-text (plist-get payload :confidence))
          (dl-satan-intervention--quote-jsonb (plist-get payload :evidence))
          (dl-satan-intervention--quote-text (plist-get payload :maturity))
          (concat (dl-satan-intervention--quote-text
                   (plist-get payload :next_revisit_at))
                  "::timestamptz")
          (dl-satan-intervention--quote-text (plist-get payload :source))
          (concat (dl-satan-intervention--quote-text
                   (plist-get payload :classified_at))
                  "::timestamptz")
          (dl-satan-intervention--quote-text (plist-get payload :revises))
          (dl-satan-intervention--quote-text (plist-get payload :marked_by))
          (dl-satan-intervention--quote-text (plist-get payload :notes)))
    ", ")
   ") ON CONFLICT (intervention_id) DO UPDATE SET "
   "classification = EXCLUDED.classification, "
   "confidence = EXCLUDED.confidence, "
   "evidence_json = EXCLUDED.evidence_json, "
   "maturity = EXCLUDED.maturity, "
   "next_revisit_at = EXCLUDED.next_revisit_at, "
   "source = EXCLUDED.source, "
   "classified_at = EXCLUDED.classified_at, "
   "revises = EXCLUDED.revises, "
   "marked_by = EXCLUDED.marked_by, "
   "notes = EXCLUDED.notes;"))

(defun dl-satan-intervention--build-rebuild-script (events)
  "Build the full rebuild transaction SQL for EVENTS (already sorted).
Wraps TRUNCATE + per-event INSERT/UPSERT in a single transaction."
  (let ((lines (list "BEGIN;"
                     "TRUNCATE satan_intervention_outcomes, satan_interventions RESTART IDENTITY;")))
    (dolist (ev events)
      (let ((event (plist-get ev :event))
            (payload (plist-get ev :payload)))
        (push (pcase event
                ("intervention.created"
                 (dl-satan-intervention--insert-created-sql payload))
                ((or "intervention.outcome_classified"
                     "intervention.outcome_revised")
                 (dl-satan-intervention--upsert-outcome-sql payload)))
              lines)))
    (push "COMMIT;" lines)
    (mapconcat #'identity (nreverse lines) "\n")))

;; ---------- public rebuild ----------

(defun dl-satan-intervention-rebuild (&optional db runs-dir)
  "Replay every intervention audit-event under RUNS-DIR into the projection.
DB defaults to `dl-satan-memory-migrate-database'; RUNS-DIR defaults
to `dl-satan-runs-dir'.  Returns a plist:

  (:total N
   :created M
   :outcomes K
   :events EVENTS-LIST
   :validation-error (:idx N :reason STR)?)

On validation failure, the projection is left untouched and the
validation error is returned in the plist (no signal).  Idempotent:
a second invocation against the same audit log yields identical
projection rows.

Streams the entire script through one `psql --single-transaction'
invocation; on SQL failure the transaction rolls back and the
caller sees a `user-error'."
  (let* ((db (or db dl-satan-memory-migrate-database))
         (runs-dir (dl-satan-intervention--runs-dir runs-dir))
         (raw (dl-satan-intervention--collect-events runs-dir))
         (events (dl-satan-intervention--sort-events raw))
         (stream (mapcar (lambda (ev) (cons (plist-get ev :event)
                                            (plist-get ev :payload)))
                         events))
         (verr (dl-satan-audit-validate-intervention-stream stream)))
    (if verr
        (list :total (length events)
              :created 0
              :outcomes 0
              :events events
              :validation-error verr)
      (let* ((script (dl-satan-intervention--build-rebuild-script events))
             (result (dl-satan-memory-migrate--psql
                      db (list "--single-transaction" "-f" "-") script)))
        (pcase result
          (`(ok . ,_)
           (list :total (length events)
                 :created (cl-count-if
                           (lambda (ev) (equal (plist-get ev :event)
                                               "intervention.created"))
                           events)
                 :outcomes (cl-count-if
                            (lambda (ev) (member (plist-get ev :event)
                                                 '("intervention.outcome_classified"
                                                   "intervention.outcome_revised")))
                            events)
                 :events events
                 :validation-error nil))
          (`(error . ,msg)
           (user-error "dl-satan-intervention-rebuild failed: %s" msg)))))))

;;;###autoload
(defun my/satan-rebuild-interventions (&optional db)
  "Rebuild the intervention projection from audit logs.
With prefix arg, prompt for DB."
  (interactive
   (list (if current-prefix-arg
             (read-string "Database: " dl-satan-memory-migrate-database)
           dl-satan-memory-migrate-database)))
  (let ((res (dl-satan-intervention-rebuild db)))
    (if (plist-get res :validation-error)
        (let ((err (plist-get res :validation-error)))
          (message "satan-rebuild-interventions: refused — validation failed at idx %d: %s"
                   (plist-get err :idx)
                   (plist-get err :reason)))
      (message "satan-rebuild-interventions: %d events (%d created, %d outcomes)"
               (plist-get res :total)
               (plist-get res :created)
               (plist-get res :outcomes)))
    res))

;; ---------- write/read API (T7 PR 3) ----------

(defvar dl-satan-intervention--counters (make-hash-table :test 'equal)
  "Per-run counter (run-id string -> integer) used to mint `<run-id>.iv<N>'
intervention ids inside a single emacs session.  Resets on emacs restart;
runs are bound to their broker process so a fresh session always starts
a new run with no carryover.")

(defun dl-satan-intervention--next-counter (run-id)
  "Return the next 1-indexed counter value for RUN-ID."
  (let ((n (1+ (or (gethash run-id dl-satan-intervention--counters) 0))))
    (puthash run-id n dl-satan-intervention--counters)
    n))

(defun dl-satan-intervention--mint-id (run-id)
  "Mint a stable intervention id of shape `<RUN-ID>.iv<NNN>'.
The counter is per-run; ids are dense, ordered, and emit-time-stamped
implicitly through the audit record's `:ts'."
  (format "%s.iv%03d" run-id (dl-satan-intervention--next-counter run-id)))

(defun dl-satan-intervention--reset-counters ()
  "Clear all per-run intervention counters.  For ert use; not for production."
  (clrhash dl-satan-intervention--counters))

(defun dl-satan-intervention--ctx-required (ctx)
  "Validate CTX exposes the keys the write API depends on; signal otherwise."
  (unless (and (plist-member ctx :id)
               (plist-member ctx :mode-name)
               (plist-member ctx :time-now)
               (plist-member ctx :audit))
    (user-error
     "dl-satan-intervention: tool-ctx missing :id/:mode-name/:time-now/:audit")))

(defun dl-satan-intervention--exec-sql (db sql)
  "Run SQL through `psql --single-transaction'.  Signals on failure."
  (let ((result (dl-satan-memory-migrate--psql
                 db (list "--single-transaction" "-f" "-") sql)))
    (pcase result
      (`(ok . ,_) nil)
      (`(error . ,msg) (user-error "dl-satan-intervention SQL: %s" msg)))))

;; --- create ---

(cl-defun dl-satan-intervention-create
    (&key ctx kind target-surface message
          related-motive-id cue-handles
          expected-outcome outcome-window-minutes severity
          (db dl-satan-memory-migrate-database))
  "Create an intervention.  CTX is the broker-supplied tool-ctx plist.
Required keyword args: KIND, TARGET-SURFACE, MESSAGE, EXPECTED-OUTCOME,
OUTCOME-WINDOW-MINUTES, SEVERITY.  Optional: RELATED-MOTIVE-ID,
CUE-HANDLES (list of strings).  DB defaults to the migrate database.

On success: emits `intervention.created' to the run's transcript and
INSERTs the row into the `satan_interventions' projection
\(`ON CONFLICT (id) DO NOTHING' for retry-idempotency).  Returns the
minted intervention-id string.

Signals `user-error' on validator failure or DB failure.  The audit
record is canonical; a DB-side failure leaves the run's audit log
intact for later rebuild."
  (dl-satan-intervention--ctx-required ctx)
  (let* ((run-id (plist-get ctx :id))
         (ts (plist-get ctx :time-now))
         (mode (plist-get ctx :mode-name))
         (audit (plist-get ctx :audit))
         (iv-id (dl-satan-intervention--mint-id run-id))
         (payload
          (list :intervention_id        iv-id
                :run_id                 run-id
                :ts                     ts
                :mode                   mode
                :kind                   kind
                :target_surface         target-surface
                :message                message
                :related_motive_id      (or related-motive-id :null)
                :cue_handles            (or cue-handles '())
                :expected_outcome       expected-outcome
                :outcome_window_minutes outcome-window-minutes
                :severity               severity))
         (verr (dl-satan-audit-validate-intervention-event
                "intervention.created" payload
                (make-hash-table :test 'equal))))
    (when verr
      (user-error "dl-satan-intervention-create: %s" verr))
    (dl-satan-audit-record audit 'broker 'intervention.created payload)
    (dl-satan-intervention--exec-sql
     db (concat "BEGIN;\n"
                (dl-satan-intervention--insert-created-sql payload)
                "\nCOMMIT;\n"))
    iv-id))

;; --- classify ---

(cl-defun dl-satan-intervention-classify
    (&key ctx intervention-id classification confidence evidence
          maturity next-revisit-at source classified-at
          marked-by notes
          (db dl-satan-memory-migrate-database))
  "Record an outcome verdict for INTERVENTION-ID.

When the projection already carries an outcome row for INTERVENTION-ID,
this is a revision: emits `intervention.outcome_revised' with `:revises'
set to INTERVENTION-ID.  Otherwise emits `intervention.outcome_classified'.

CTX is the broker-supplied tool-ctx (provides the audit handle).
DB defaults to the migrate database.  Returns the audit event-name
string on success; signals `user-error' on validator/DB failure."
  (dl-satan-intervention--ctx-required ctx)
  (let* ((audit (plist-get ctx :audit))
         (existing (dl-satan-intervention-lookup intervention-id db))
         (revision-p (and existing (plist-get existing :outcome)))
         (event (if revision-p
                    "intervention.outcome_revised"
                  "intervention.outcome_classified"))
         (payload
          (append
           (list :intervention_id  intervention-id
                 :classification   classification
                 :confidence       confidence
                 :evidence         (or evidence '())
                 :maturity         maturity
                 :next_revisit_at  next-revisit-at
                 :source           source
                 :classified_at    classified-at)
           (when revision-p (list :revises intervention-id))
           (when marked-by (list :marked_by marked-by))
           (when notes (list :notes notes))))
         (created-ids (let ((h (make-hash-table :test 'equal)))
                        (puthash intervention-id t h)
                        h))
         (verr (dl-satan-audit-validate-intervention-event
                event payload created-ids)))
    (when verr
      (user-error "dl-satan-intervention-classify: %s" verr))
    (dl-satan-audit-record audit 'broker (intern event) payload)
    (dl-satan-intervention--exec-sql
     db (concat "BEGIN;\n"
                (dl-satan-intervention--upsert-outcome-sql payload)
                "\nCOMMIT;\n"))
    event))

;; --- query helpers ---

(defconst dl-satan-intervention--lookup-columns
  '("id" "run_id" "ts" "mode" "kind" "target_surface" "message"
    "related_motive_id" "cue_handles_json" "expected_outcome"
    "outcome_window_minutes" "severity"))

(defconst dl-satan-intervention--outcome-columns
  '("classification" "confidence" "evidence_json" "maturity"
    "next_revisit_at" "source" "classified_at" "revises"
    "marked_by" "notes"))

(defun dl-satan-intervention--parse-jsonb (text)
  "Parse a JSONB cell TEXT into elisp; nil/empty → nil."
  (cond
   ((or (null text) (string-empty-p text)) nil)
   (t (condition-case _err
          (json-parse-string text
                             :object-type 'plist
                             :array-type 'list
                             :null-object :null
                             :false-object :false)
        (error nil)))))

(defun dl-satan-intervention--parse-pg-array-text (text)
  "Parse the PostgreSQL textual representation of a `text[]' array.
Handles the standard `{a,b,c}' shape with double-quote escaping;
returns nil for empty `{}'."
  (cond
   ((or (null text) (string-empty-p text)) nil)
   ((not (and (string-prefix-p "{" text) (string-suffix-p "}" text))) nil)
   (t (let ((inner (substring text 1 -1)))
        (cond
         ((string-empty-p inner) nil)
         (t (mapcar (lambda (e)
                      (if (and (string-prefix-p "\"" e)
                               (string-suffix-p "\"" e))
                          (substring e 1 -1)
                        e))
                    (split-string inner ","))))))))

(defun dl-satan-intervention--row-to-intervention (cells)
  "Convert a CELLS list (column-order matches `--lookup-columns') to plist."
  (cl-destructuring-bind
      (id run_id ts mode kind target_surface message
       related_motive_id cue_handles_json expected_outcome
       outcome_window_minutes severity)
      cells
    (list :intervention_id        id
          :run_id                 run_id
          :ts                     ts
          :mode                   mode
          :kind                   kind
          :target_surface         target_surface
          :message                message
          :related_motive_id      (if (string-empty-p related_motive_id)
                                      nil
                                    related_motive_id)
          :cue_handles            (dl-satan-intervention--parse-jsonb
                                   cue_handles_json)
          :expected_outcome       expected_outcome
          :outcome_window_minutes (string-to-number outcome_window_minutes)
          :severity               severity)))

(defun dl-satan-intervention--row-to-outcome (cells)
  "Convert a CELLS list (column-order matches `--outcome-columns') to plist."
  (cl-destructuring-bind
      (classification confidence evidence_json maturity
       next_revisit_at source classified_at revises
       marked_by notes)
      cells
    (list :classification    classification
          :confidence        confidence
          :evidence          (dl-satan-intervention--parse-jsonb evidence_json)
          :maturity          maturity
          :next_revisit_at   next_revisit_at
          :source            source
          :classified_at     classified_at
          :revises           (if (string-empty-p revises) nil revises)
          :marked_by         (if (string-empty-p marked_by) nil marked_by)
          :notes             (if (string-empty-p notes) nil notes))))

(defun dl-satan-intervention-lookup (intervention-id &optional db)
  "Return `(:intervention ROW :outcome ROW|nil)' for INTERVENTION-ID, or nil."
  (let* ((db (or db dl-satan-memory-migrate-database))
         (sql (concat
               "SELECT "
               (mapconcat
                (lambda (c) (concat "COALESCE(i." c "::text, '')"))
                dl-satan-intervention--lookup-columns ", ")
               ", "
               "(o.intervention_id IS NOT NULL)::text, "
               (mapconcat
                (lambda (c) (concat "COALESCE(o." c "::text, '')"))
                dl-satan-intervention--outcome-columns ", ")
               " FROM satan_interventions i "
               "LEFT JOIN satan_intervention_outcomes o "
               "  ON i.id = o.intervention_id "
               "WHERE i.id = "
               (dl-satan-intervention--quote-text intervention-id)))
         (result (dl-satan-memory-migrate--psql
                  db (list "-A" "-t" "-F" "|" "-c" sql))))
    (pcase result
      (`(ok . ,out)
       (let* ((line (string-trim out)))
         (when (and (not (string-empty-p line)))
           (let* ((cells (split-string line "|"))
                  (n-iv (length dl-satan-intervention--lookup-columns))
                  (iv-cells (cl-subseq cells 0 n-iv))
                  (has-outcome (equal "true" (nth n-iv cells)))
                  (out-cells (and has-outcome
                                  (cl-subseq cells (1+ n-iv)))))
             (list :intervention (dl-satan-intervention--row-to-intervention iv-cells)
                   :outcome (and has-outcome
                                 (dl-satan-intervention--row-to-outcome out-cells)))))))
      (`(error . ,msg) (user-error "dl-satan-intervention-lookup: %s" msg)))))

(defun dl-satan-intervention-pending (now &optional db)
  "Return intervention plists whose maturity window ≤ NOW and that lack outcomes.
NOW is an ISO8601 string accepted by PostgreSQL's `timestamptz' parser.
Excludes interventions whose `created_at + outcome_window_minutes' is
later than NOW (still `:pending' — see outcome-semantics §3), whose
`created_at + outcome_window_minutes + 24h' is earlier than NOW
(already `:stale' — auto re-pass forbidden per §6.3, T1.5b PR 3),
and any intervention that already has an outcome row in the
projection."
  (let* ((db (or db dl-satan-memory-migrate-database))
         (now-lit (concat (dl-satan-intervention--quote-text now)
                          "::timestamptz"))
         (sql (concat
               "SELECT "
               (mapconcat
                (lambda (c) (concat "COALESCE(i." c "::text, '')"))
                dl-satan-intervention--lookup-columns ", ")
               " FROM satan_interventions i "
               "LEFT JOIN satan_intervention_outcomes o "
               "  ON i.id = o.intervention_id "
               "WHERE o.intervention_id IS NULL "
               "  AND i.ts + (i.outcome_window_minutes * INTERVAL '1 minute') "
               "      <= " now-lit " "
               "  AND i.ts + (i.outcome_window_minutes * INTERVAL '1 minute') "
               "      + INTERVAL '24 hours' >= " now-lit " "
               "ORDER BY i.ts ASC"))
         (result (dl-satan-memory-migrate--psql
                  db (list "-A" "-t" "-F" "|" "-c" sql))))
    (pcase result
      (`(ok . ,out)
       (cl-loop for line in (split-string out "\n" t)
                for cells = (split-string line "|")
                when (= (length cells)
                        (length dl-satan-intervention--lookup-columns))
                collect (dl-satan-intervention--row-to-intervention cells)))
      (`(error . ,msg) (user-error "dl-satan-intervention-pending: %s" msg)))))

(provide 'dl-satan-intervention)
;;; dl-satan-intervention.el ends here
