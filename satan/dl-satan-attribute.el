;;; dl-satan-attribute.el --- Broker → daemon outcome enqueue -*- lexical-binding: t; -*-

;; Broker-side surface for the attribute layer (T-attr-1c slice 2).
;;
;; Two responsibilities:
;;
;;   1. The `attribute-updates-enabled' switch (design-contract §9 + §17.5).
;;      Forwarded to the daemon in every outcome payload so the daemon can
;;      write `disabled=true' events without UPSERTing the projection.
;;
;;   2. The enqueue helper that classify path in `dl-satan-intervention'
;;      calls after writing its own audit + outcome projection rows.  Inserts
;;      one row into `satan_outcome_inbox' carrying the contract §17.3 v1.0
;;      payload, then `pg_notify satan_outcome_inbox <id>'.
;;
;; LISTEN consumer + transcript-write side live in
;; `dl-satan-attribute-listener.el'.

(require 'cl-lib)
(require 'json)
(require 'subr-x)

(defgroup dl-satan-attribute nil
  "SATAN attribute layer broker surface."
  :group 'dl-satan)

(defcustom dl-satan-attribute-updates-enabled t
  "When non-nil, broker forwards outcome events to the attribute daemon.

When nil the broker still enqueues the source event (so the daemon records
a `disabled=true' row in `satan_attribute_events' — `satan-attrd rebuild
--include-disabled' can replay it later) but the daemon skips the
projection UPSERT.  Operator rollback path for the attributes tranche
\(design-contract §9)."
  :type 'boolean :group 'dl-satan-attribute)

(defcustom dl-satan-attribute-database "satan_memory"
  "Database name carrying the satan_outcome_inbox queue."
  :type 'string :group 'dl-satan-attribute)

(defcustom dl-satan-attribute-host "/run/postgresql"
  "Postgres host or socket directory."
  :type 'string :group 'dl-satan-attribute)

(defcustom dl-satan-attribute-psql-program
  (or (executable-find "psql") "psql")
  "Path to the `psql' binary."
  :type 'string :group 'dl-satan-attribute)

(defconst dl-satan-attribute-payload-schema-version "1.0"
  "Wire-shape `schema_version' the broker stamps on outbound payloads
\(design-contract §17.3).  Daemon rejects unknown major.")

;; ---------------------------------------------------------------------
;; JSON helpers (shared shape with dl-satan-patch-store)
;; ---------------------------------------------------------------------

(defun dl-satan-attribute--prep-value (v)
  "Recursively normalise V for `json-serialize'.
Plists become objects; lists become arrays; symbols become strings; nil
becomes :null.  Booleans (`t' and `:false') are passed through verbatim
so `json-serialize' renders JSON `true`/`false`."
  (cond
   ((null v) :null)
   ((eq v t) t)
   ((eq v :false) :false)
   ((eq v :null) :null)
   ((and (consp v) (keywordp (car v)))
    (cl-loop for (k x) on v by #'cddr
             collect k
             collect (dl-satan-attribute--prep-value x)))
   ((listp v) (vconcat (mapcar #'dl-satan-attribute--prep-value v)))
   ((symbolp v) (symbol-name v))
   (t v)))

(defun dl-satan-attribute--json (v)
  "Serialise V to a JSON string."
  (json-serialize (dl-satan-attribute--prep-value v)))

;; ---------------------------------------------------------------------
;; psql plumbing
;; ---------------------------------------------------------------------

(defun dl-satan-attribute--query (db sql variables)
  "Run SQL against DB with VARIABLES (alist NAME . VALUE).  Return
\(ok . STDOUT-TRIMMED) or (error . MSG)."
  (let* ((var-args (cl-loop for (k . v) in variables
                            append (list "-v" (format "%s=%s" k v))))
         (full-args (append (list "-h" dl-satan-attribute-host
                                  "-d" db
                                  "--no-psqlrc"
                                  "-X" "-A" "-t" "-q"
                                  "-F" "\t"
                                  "-v" "ON_ERROR_STOP=1")
                            var-args
                            (list "-f" "-"))))
    (with-temp-buffer
      (let* ((out-buf (current-buffer))
             (status
              (with-temp-buffer
                (insert sql)
                (apply #'call-process-region
                       (point-min) (point-max)
                       dl-satan-attribute-psql-program
                       nil out-buf nil full-args))))
        (if (and (integerp status) (zerop status))
            (cons 'ok (string-trim (buffer-string)))
          (cons 'error (format "psql exit %s on %s: %s"
                               status db
                               (string-trim (buffer-string)))))))))

;; ---------------------------------------------------------------------
;; payload construction
;; ---------------------------------------------------------------------

(cl-defun dl-satan-attribute-build-outcome-payload
    (&key run-id ts intervention-id classification confidence
          intervention-kind related-motive-id cue-handles related-trace-ids
          is-revision revises)
  "Construct the broker → daemon outcome payload (design-contract §17.3 v1.0).

`is-revision' MUST be t or nil; `revises' MUST be the prior outcome
pointer string when `is-revision' is t.  The current
`dl-satan-attribute-updates-enabled' value is stamped on the payload —
the daemon honours it per §17.5 (disabled events still write event rows
but skip the projection UPSERT)."
  (list :schema_version  dl-satan-attribute-payload-schema-version
        :run_id          run-id
        :ts              ts
        :intervention_id intervention-id
        :classification  classification
        :confidence      confidence
        :evidence (list :intervention_kind  (or intervention-kind :null)
                        :related_motive_id  (or related-motive-id :null)
                        :cue_handles        (or cue-handles '())
                        :related_trace_ids  (or related-trace-ids '()))
        :is_revision     (if is-revision t :false)
        :revises         (or revises :null)
        :enabled         (if dl-satan-attribute-updates-enabled t :false)))

;; ---------------------------------------------------------------------
;; enqueue
;; ---------------------------------------------------------------------

(defun dl-satan-attribute-enqueue-outcome (payload &optional db)
  "Insert PAYLOAD into satan_outcome_inbox + NOTIFY satan_outcome_inbox.

PAYLOAD is a plist (typically built via
`dl-satan-attribute-build-outcome-payload'); serialised to JSONB.
Returns (ok . ID) carrying the inserted row id, or (error . MSG)."
  (let* ((database (or db dl-satan-attribute-database))
         (json (dl-satan-attribute--json payload))
         (sql (concat
               "WITH ins AS ("
               " INSERT INTO satan_outcome_inbox (payload_json) "
               " VALUES (:'payload'::jsonb) "
               " RETURNING id"
               ") "
               "SELECT id, pg_notify('satan_outcome_inbox', id::text) "
               "FROM ins"))
         (result (dl-satan-attribute--query
                  database sql `(("payload" . ,json)))))
    (pcase result
      (`(ok . ,out)
       (let* ((parts (split-string out "\t"))
              (id-str (car parts)))
         (cons 'ok (and id-str (not (string-empty-p id-str))
                        (string-to-number id-str)))))
      (err err))))

(provide 'dl-satan-attribute)
;;; dl-satan-attribute.el ends here
