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
;; PR 3 will extend this file with the write API (`-create' /
;; `-classify' / `-lookup') that handlers call at intervention time.

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
   ");"))

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

(provide 'dl-satan-intervention)
;;; dl-satan-intervention.el ends here
