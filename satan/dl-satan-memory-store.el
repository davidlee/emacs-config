;;; dl-satan-memory-store.el --- DB-backed trace store -*- lexical-binding: t; -*-

;; Step 7 of memory.design.md.  Transactional storage and retrieval for
;; the SATAN memory substrate.  Surfaces:
;;
;;   `dl-satan-memory-store-mark'      §5.1  insert one trace
;;   `dl-satan-memory-store-resonate'  §5.2  inverted-index lookup
;;   `dl-satan-memory-store-show'      §5.3  round-trip a trace
;;
;; Implementation: subprocess to `psql' (R3, §6.1).  Multi-step
;; transactions live in SQL functions installed by migration 0003 so
;; the elisp side stays a one-liner per call (`SELECT memory_*(...)').
;;
;; Resonate and show are read-only — `access_count' / `last_accessed_at'
;; stay at their defaults in v1 per §6.4.

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-memory-grammar)

;; ---------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------

(defcustom dl-satan-memory-store-database "satan_memory"
  "Production memory database name."
  :type 'string :group 'dl-satan-memory)

(defcustom dl-satan-memory-store-host "/run/postgresql"
  "Postgres host or socket directory."
  :type 'string :group 'dl-satan-memory)

(defcustom dl-satan-memory-store-psql-program
  (or (executable-find "psql") "psql")
  "Path to the `psql' binary."
  :type 'string :group 'dl-satan-memory)

(defconst dl-satan-memory-store--id-charset
  "abcdefghijklmnopqrstuvwxyz0123456789")

;; ---------------------------------------------------------------------
;; Trace-id minting
;; ---------------------------------------------------------------------

(defun dl-satan-memory-store-trace-id-new (time-iso &optional rand-fn)
  "Build a deterministic-looking id `YYYYMMDDTHHMMSS-<6char>' from
TIME-ISO (ISO8601 string).  RAND-FN is an optional thunk returning the
suffix for testability; defaults to a 6-char base36 random string."
  (let* ((stamp (format-time-string "%Y%m%dT%H%M%S"
                                    (date-to-time time-iso)))
         (suffix (if rand-fn
                     (funcall rand-fn)
                   (cl-loop with s = (make-string 6 ?a)
                            for i below 6
                            do (aset s i
                                     (aref dl-satan-memory-store--id-charset
                                           (random 36)))
                            finally return s))))
    (format "%s-%s" stamp suffix)))

;; ---------------------------------------------------------------------
;; psql plumbing
;; ---------------------------------------------------------------------

(defun dl-satan-memory-store--query (db sql variables)
  "Run SQL against DB with VARIABLES (alist of name . value) bound via
`-v'.  Return (ok . STDOUT-TRIMMED) or (error . MSG).  Use `:''name''
inside SQL to safely splice a string value as a SQL literal.

SQL is fed to psql on stdin via `-f -' because `-c' does not perform
variable substitution.  Field separator is tab so multi-column
SELECTs are unambiguous to parse."
  (let* ((var-args (cl-loop for (k . v) in variables
                            append (list "-v"
                                         (format "%s=%s" k v))))
         (full-args (append (list "-h" dl-satan-memory-store-host
                                  "-d" db
                                  "--no-psqlrc"
                                  "-X" "-A" "-t"
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
                       dl-satan-memory-store-psql-program
                       nil out-buf nil full-args))))
        (if (and (integerp status) (zerop status))
            (cons 'ok (string-trim (buffer-string)))
          (cons 'error (format "psql exit %s on %s: %s"
                                status db
                                (string-trim (buffer-string)))))))))

(defun dl-satan-memory-store--parse-pg-array (s)
  "Parse a `{a,b,c}' postgres array literal into a list of strings.
Empty input or `{}' returns nil.  Does not handle escaped commas
inside double-quoted entries; sufficient for handle strings, which
the CHECK constraint restricts to a safe charset."
  (cond
   ((or (null s) (string-empty-p s) (string= s "{}")) nil)
   ((and (string-prefix-p "{" s) (string-suffix-p "}" s))
    (let ((inner (substring s 1 -1)))
      (mapcar
       (lambda (e)
         (if (and (string-prefix-p "\"" e) (string-suffix-p "\"" e))
             (substring e 1 -1)
           e))
       (split-string inner ","))))
   (t (list s))))

(defun dl-satan-memory-store--format-pg-array (values)
  "Format VALUES (list of strings) as a postgres array literal."
  (concat "{"
          (mapconcat
           (lambda (v)
             ;; handle CHECK constraint admits [A-Za-z0-9_.+>:-], all
             ;; safe outside double quotes
             v)
           values ",")
          "}"))

;; ---------------------------------------------------------------------
;; memory_mark
;; ---------------------------------------------------------------------

(cl-defun dl-satan-memory-store-mark
    (&key trace-id kind trace-origin source
          observed-start-at observed-end-at
          payload valence outcome
          (schema-version 1)
          grammar-version
          metadata-json retention-json
          handles links
          (db dl-satan-memory-store-database))
  "Insert one trace via the `memory_mark_trace' SQL function.
Returns (ok . TRACE-ID) or (error . MSG).

Required: KIND, TRACE-ORIGIN, SOURCE, OBSERVED-START-AT,
OBSERVED-END-AT (ISO8601 strings), PAYLOAD (display prose),
GRAMMAR-VERSION, HANDLES (list of plists
  (:handle STR :source PLIST [:grammar_version N])).

Optional: TRACE-ID (else minted from OBSERVED-END-AT), VALENCE,
OUTCOME, METADATA-JSON (any JSON-serializable value), RETENTION-JSON,
LINKS (list of (:relation STR :target_trace_id STR)).

If OUTCOME is non-nil the caller must include a matching
`outcome:<value>' handle (§9.12 invariant; enforced server-side)."
  (let* ((tid (or trace-id
                  (dl-satan-memory-store-trace-id-new
                   (or observed-end-at observed-start-at))))
         (blob (dl-satan-memory-store--build-mark-payload
                tid kind trace-origin source
                observed-start-at observed-end-at
                payload valence outcome
                schema-version grammar-version
                metadata-json retention-json
                handles links))
         (result (dl-satan-memory-store--query
                  db "SELECT memory_mark_trace(:'payload'::jsonb)"
                  `(("payload" . ,blob)))))
    (pcase result
      (`(ok . ,out) (cons 'ok (if (string-empty-p out) tid out)))
      (err err))))

(defun dl-satan-memory-store--null-if-nil (v)
  (if (null v) :null v))

(defun dl-satan-memory-store--prep-plist (plist)
  "Recursively normalize PLIST for `json-serialize':
nil-valued slots become `:null', nested plists are walked, lists of
plists are converted to vectors of plists."
  (cl-loop for (k v) on plist by #'cddr
           collect k
           collect (dl-satan-memory-store--prep-value v)))

(defun dl-satan-memory-store--prep-value (v)
  "Recursively normalise V for `json-serialize'.
Plists become objects; any other list becomes a JSON array (each
element recursively prepared); symbols become strings."
  (cond
   ((null v) :null)
   ((and (consp v) (keywordp (car v)))
    (dl-satan-memory-store--prep-plist v))
   ((listp v)
    (vconcat (mapcar #'dl-satan-memory-store--prep-value v)))
   ((symbolp v) (symbol-name v))
   (t v)))

(defun dl-satan-memory-store--build-mark-payload
    (tid kind origin src start end body val outc sv gv md rt handles links)
  "Internal: build the JSONB blob memory_mark_trace consumes."
  (let ((handle-rows
         (vconcat
          (mapcar
           (lambda (h)
             (dl-satan-memory-store--prep-plist
              (list :handle (plist-get h :handle)
                    :source (or (plist-get h :source) '())
                    :grammar_version (or (plist-get h :grammar_version) gv))))
           handles)))
        (link-rows
         (vconcat
          (mapcar
           (lambda (l)
             (list :relation (plist-get l :relation)
                   :target_trace_id (plist-get l :target_trace_id)))
           links))))
    (json-serialize
     (list :trace_id tid
           :kind kind
           :trace_origin origin
           :source src
           :observed_start_at start
           :observed_end_at end
           :payload body
           :valence (dl-satan-memory-store--null-if-nil val)
           :outcome (dl-satan-memory-store--null-if-nil outc)
           :schema_version sv
           :grammar_version gv
           :metadata_json (or (and md (dl-satan-memory-store--prep-value md))
                              '())
           :retention_json (or (and rt (dl-satan-memory-store--prep-value rt))
                               (list :policy "normal"))
           :handles handle-rows
           :links link-rows))))

;; ---------------------------------------------------------------------
;; memory_resonate
;; ---------------------------------------------------------------------

(cl-defun dl-satan-memory-store-resonate
    (&key cue-handles
          (grammar-version dl-satan-memory-grammar-current-version)
          (min-score 0.0)
          (limit 5)
          kinds
          (db dl-satan-memory-store-database))
  "Inverted-index lookup against `trace_handles' filtered by
CUE-HANDLES.  Returns (ok . LIST) of plists
  (:trace_id ID :score N :matched_handles LIST)
sorted by SCORE desc, or (error . MSG).  No state mutation per §6.4."
  (when (or (null cue-handles) (zerop (length cue-handles)))
    (cl-return-from dl-satan-memory-store-resonate (cons 'ok nil)))
  (let* ((handles-arr (dl-satan-memory-store--format-pg-array cue-handles))
         (kinds-arg (if kinds
                        (concat ":'kinds'::text[]")
                      "NULL::text[]"))
         (vars (append `(("handles" . ,handles-arr))
                       (when kinds
                         `(("kinds" . ,(dl-satan-memory-store--format-pg-array
                                        kinds))))))
         (sql (format
               (concat "SELECT trace_id, score, matched_handles "
                       "FROM memory_resonate(:'handles'::text[], "
                       "%d::smallint, %s::float8, %d::int, %s)")
               grammar-version
               (number-to-string min-score)
               limit
               kinds-arg))
         (result (dl-satan-memory-store--query db sql vars)))
    (pcase result
      (`(ok . ,out)
       (cons 'ok
             (cl-loop for line in (split-string out "\n" t)
                      for parts = (split-string line "\t")
                      when (= 3 (length parts))
                      collect
                      (list :trace_id (nth 0 parts)
                            :score (string-to-number (nth 1 parts))
                            :matched_handles
                            (dl-satan-memory-store--parse-pg-array
                             (nth 2 parts))))))
      (err err))))

;; ---------------------------------------------------------------------
;; memory_show
;; ---------------------------------------------------------------------

(cl-defun dl-satan-memory-store-show
    (trace-id &key (db dl-satan-memory-store-database))
  "Round-trip a single trace by TRACE-ID via `memory_show_trace'.
Returns (ok . PLIST) on success — PLIST has `:trace', `:handles',
`:links'.  Returns (ok . nil) when the trace_id is absent.
Returns (error . MSG) on psql or parse error."
  (let* ((result (dl-satan-memory-store--query
                  db "SELECT memory_show_trace(:'tid')"
                  `(("tid" . ,trace-id)))))
    (pcase result
      (`(ok . ,out)
       (cond
        ((string-empty-p out) (cons 'ok nil))
        (t (condition-case err
               (cons 'ok (json-parse-string out
                                            :object-type 'plist
                                            :array-type 'list
                                            :null-object nil
                                            :false-object :false))
             (error (cons 'error (format "JSON parse: %S" err)))))))
      (err err))))

;; ---------------------------------------------------------------------
;; Recent (by-time access path used by the observation tank)
;; ---------------------------------------------------------------------

(cl-defun dl-satan-memory-store-recent
    (&key (limit 10) kinds grammar-version
          (db dl-satan-memory-store-database))
  "Last LIMIT traces ordered by `observed_end_at' DESC.
Returns (ok . LIST) of plists
  (:trace_id ID :kind STR :valence STR-OR-NIL
   :observed_end_at ISO :payload SINGLE-LINE :handles LIST)
or (error . MSG).

KINDS is an optional list of trace-kind strings to filter on.
GRAMMAR-VERSION is an optional smallint; when nil, all grammar
versions are admitted (unlike `resonate', which scores against a
single version's weights).  Payload newlines/tabs are collapsed
to spaces and the field is truncated to 200 chars so the tab-split
parser stays single-line."
  (let* ((kinds-filter (when kinds " AND t.kind = ANY(:'kinds'::text[])"))
         (gv-filter (when grammar-version
                      (format " AND t.grammar_version = %d::smallint"
                              grammar-version)))
         (vars (append (when kinds
                         `(("kinds" . ,(dl-satan-memory-store--format-pg-array
                                        kinds))))))
         (sql (format
               (concat
                "SELECT t.id, t.kind, "
                "COALESCE(t.valence::text, ''), "
                "to_char(t.observed_end_at AT TIME ZONE 'UTC', "
                "'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"'), "
                "REPLACE(REPLACE("
                "LEFT(t.payload, 200), E'\n', ' '), E'\t', ' '), "
                "COALESCE("
                "(SELECT string_agg(handle, ',' ORDER BY handle) "
                "FROM trace_handles WHERE trace_id = t.id), '') "
                "FROM traces t WHERE TRUE%s%s "
                "ORDER BY t.observed_end_at DESC LIMIT %d")
               (or gv-filter "")
               (or kinds-filter "")
               limit))
         (result (dl-satan-memory-store--query db sql vars)))
    (pcase result
      (`(ok . ,out)
       (cons 'ok
             (cl-loop for line in (split-string out "\n" t)
                      for parts = (split-string line "\t")
                      when (= 6 (length parts))
                      collect
                      (let ((val (nth 2 parts))
                            (handles (nth 5 parts)))
                        (list :trace_id (nth 0 parts)
                              :kind (nth 1 parts)
                              :valence (if (string-empty-p val) nil val)
                              :observed_end_at (nth 3 parts)
                              :payload (nth 4 parts)
                              :handles
                              (if (string-empty-p handles)
                                  nil
                                (split-string handles ",")))))))
      (err err))))

(provide 'dl-satan-memory-store)
;;; dl-satan-memory-store.el ends here
