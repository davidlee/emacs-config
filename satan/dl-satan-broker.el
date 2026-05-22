;;; dl-satan-broker.el --- SATAN broker driver -*- lexical-binding: t; -*-

;; Lifecycle:
;;   1. resolve mode-spec
;;   2. mint run-id, create runs/<run-id>/
;;   3. assemble bundle, write manifest + bundle
;;   4. open audit handle, log run-start
;;   5. spawn jailed child via make-process (pipe, line-buffered filter)
;;   6. on tool_call: dispatch through dl-satan-tool-dispatch; send tool_result
;;   7. on final: capture, defer to sentinel
;;   8. sentinel: cancel timeout, run output handler, write actions.json + status, close audit
;;   9. timeout: kill process; sentinel handles the rest

(require 'cl-lib)
(require 'subr-x)
(require 'dl-satan-audit)
(require 'dl-satan-budget)
(require 'dl-satan-jsonl)
(require 'dl-satan-protocol)
(require 'dl-satan-tools)
(require 'dl-satan-tools-org)
(require 'dl-satan-mode)
(require 'dl-satan-context)
(require 'dl-satan-output)

(defcustom dl-satan-runs-dir
  (expand-file-name "satan/runs" (or (bound-and-true-p dl-notes-root)
                                     (expand-file-name "~/notes")))
  "Directory holding per-run audit bundles."
  :type 'directory :group 'dl-satan)

(defcustom dl-satan-hippocampus-dir
  (expand-file-name "satan/hippocampus" (or (bound-and-true-p dl-notes-root)
                                            (expand-file-name "~/notes")))
  "Read-write scratch directory inside the jail."
  :type 'directory :group 'dl-satan)

(defcustom dl-satan-direnv-dir
  (expand-file-name user-emacs-directory)
  "Directory whose `.envrc' is sourced into the jailed-harness environment.
If non-nil and `envrc--export' is available, the broker resolves direnv
for this directory and merges the result into `process-environment'
before spawning the child.  Set to nil to disable."
  :type '(choice directory (const nil)) :group 'dl-satan)

(defvar dl-satan-broker-provider-key-vars
  '((openrouter . "OPENROUTER_API_KEY")
    (anthropic  . "ANTHROPIC_API_KEY")
    (openai     . "OPENAI_API_KEY")
    (deepseek   . "DEEPSEEK_API_KEY"))
  "Map SATAN mode `:provider' symbol to its API-key env var name.")

(declare-function my/op-read-env "dl-secret" (var &optional refresh))
(declare-function my/scrub-op-refs-env "dl-secret" (env))
(declare-function notifications-notify "notifications" (&rest args))

(defun dl-satan-broker--read-env (var)
  "Return VAR from the environment, resolving `op://' refs when possible.
Falls back to `getenv' if `my/op-read-env' is unavailable."
  (if (fboundp 'my/op-read-env)
      (my/op-read-env var)
    (getenv var)))

(cl-defstruct dl-satan-run
  id mode start-time dir bundle-path process
  pending-tool-calls tool-calls-done
  applied-actions staged-actions rejected-actions failed-actions
  final status timeout-timer audit
  stdout-log-path
  ;; Phase 0.1: the run_ctx plist built by `dl-satan-broker--prepare'.
  ;; Carries the frozen `:time_now', `:run_id', `:start_time' and v0
  ;; placeholder slots (`:evidence' `:percept' `:sensor_status'
  ;; `:pre_spawn' `:motive') that later phases populate.
  prepare)

(declare-function envrc--export "envrc" (env-dir))
(declare-function envrc--merged-environment "envrc" (process-env pairs))

(defun dl-satan-broker--direnv-env (base-env)
  "Return BASE-ENV merged with the direnv export for `dl-satan-direnv-dir'.
If envrc is not loaded, or the directory has no .envrc, or direnv
returns no vars, BASE-ENV is returned unchanged.  Direnv errors signal."
  (if (and dl-satan-direnv-dir
           (file-directory-p dl-satan-direnv-dir)
           (file-readable-p (expand-file-name ".envrc" dl-satan-direnv-dir))
           (fboundp 'envrc--export))
      (let ((result (envrc--export dl-satan-direnv-dir)))
        (pcase result
          ('error (error "direnv failed for %s" dl-satan-direnv-dir))
          ('none base-env)
          ((pred listp) (envrc--merged-environment base-env result))
          (_ base-env)))
    base-env))

(defun dl-satan-broker--exec-path-from-env (env)
  "Extract PATH from ENV (a `process-environment' value) and split into list."
  (let ((path (cl-some (lambda (kv)
                         (and (string-prefix-p "PATH=" kv)
                              (substring kv 5)))
                       env)))
    (if path (split-string path ":" t) exec-path)))

(defun dl-satan-broker--mint-run-id (name &optional time)
  (random t)
  (format "%s-%s-%06x"
          (format-time-string "%Y%m%dT%H%M%S" time)
          name
          (random (expt 16 6))))

(defconst dl-satan-broker--iso-time-format "%Y-%m-%dT%T%:z"
  "ISO-8601 time format the broker stamps onto run_ctx and tool-ctx.")

(defun dl-satan-broker--prepare (mode)
  "Allocate run_id, freeze time_now, return the v0 run_ctx plist for MODE.
The plist is the single source of truth for the run's identity and
the frozen `time_now' that the percept builder, observer, and tool
handlers all read.  Phase-1+ slots (`:evidence' `:percept'
`:sensor_status' `:pre_spawn' `:motive') are present-with-nil so later
phases can `plist-put' without keyword-arg ordering surprises."
  (let* ((name (plist-get mode :name))
         (start (current-time))
         (run-id (dl-satan-broker--mint-run-id name start))
         (time-now (format-time-string
                    dl-satan-broker--iso-time-format start)))
    (list :run_id run-id
          :time_now time-now
          :start_time start
          :evidence nil
          :percept nil
          :sensor_status nil
          :pre_spawn nil
          :motive nil)))

(defconst dl-satan-broker--failed-suffix ".FAILED"
  "Suffix appended to a run directory when its status is not `done'.
Lets `ls' / glob users see failures at a glance without opening the
`status' file.  Helpers in this file strip the suffix when deriving
the run-id from a leaf directory name.")

(defun dl-satan-broker--date-bucket-for-run-id (run-id)
  "Return the YYYY-MM-DD date bucket parsed from RUN-ID's prefix.
Returns nil if RUN-ID does not start with a YYYYMMDDT date stamp."
  (when (and (stringp run-id)
             (string-match
              "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T"
              run-id))
    (format "%s-%s-%s"
            (match-string 1 run-id)
            (match-string 2 run-id)
            (match-string 3 run-id))))

(defun dl-satan-broker--bucket-name-p (name)
  "Return non-nil when NAME matches the YYYY-MM-DD bucket-dir pattern."
  (and (stringp name)
       (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'" name)))

(defun dl-satan-broker--legacy-run-name-p (name)
  "Return non-nil when NAME matches the pre-bucket flat run-id layout.
Pre-bucket runs sit directly under `dl-satan-runs-dir' with names like
`20260520T163446-tick-pulse-5e8018'."
  (and (stringp name)
       (string-match-p "\\`[0-9]\\{8\\}T[0-9]\\{6\\}-" name)))

(defun dl-satan-broker--run-id-from-leaf (name)
  "Strip the trailing `.FAILED' suffix (if any) from a leaf dir NAME."
  (if (and (stringp name)
           (string-suffix-p dl-satan-broker--failed-suffix name))
      (substring name 0 (- (length name)
                           (length dl-satan-broker--failed-suffix)))
    name))

(defun dl-satan-broker-run-dir-for-id (run-id &optional runs-dir)
  "Return the absolute dir path where RUN-ID's bucket lives.
New runs go under `<runs>/<YYYY-MM-DD>/<run-id>/'.  If RUN-ID lacks
a parsable date prefix (shouldn't happen for minted ids), falls back
to the legacy flat layout."
  (let* ((base (or runs-dir dl-satan-runs-dir))
         (bucket (dl-satan-broker--date-bucket-for-run-id run-id)))
    (if bucket
        (expand-file-name (concat bucket "/" run-id) base)
      (expand-file-name run-id base))))

(defun dl-satan-broker-locate-run-dir (run-id &optional runs-dir)
  "Return the on-disk dir for RUN-ID, or nil if no candidate exists.
Probes (in order): bucketed/<run-id>, bucketed/<run-id>.FAILED,
legacy flat <run-id>, legacy flat <run-id>.FAILED.  Used by readers
that need to find a run regardless of layout migration or terminal
status."
  (let* ((base (or runs-dir dl-satan-runs-dir))
         (bucket (dl-satan-broker--date-bucket-for-run-id run-id))
         (failed dl-satan-broker--failed-suffix)
         (candidates (delq nil
                           (list
                            (and bucket
                                 (expand-file-name
                                  (concat bucket "/" run-id) base))
                            (and bucket
                                 (expand-file-name
                                  (concat bucket "/" run-id failed) base))
                            (expand-file-name run-id base)
                            (expand-file-name (concat run-id failed) base)))))
    (cl-find-if #'file-directory-p candidates)))

(defun dl-satan-broker-list-run-dirs (runs-dir)
  "Return absolute paths of every run dir under RUNS-DIR.
Walks both the bucketed layout (`<runs>/<YYYY-MM-DD>/<run-id>') and
the legacy flat layout (`<runs>/<run-id>'), with or without the
`.FAILED' suffix.  Non-run entries (the `most-recent' symlink, stray
files, malformed names) are skipped.  Order is unspecified."
  (let (acc)
    (when (file-directory-p runs-dir)
      (dolist (entry (directory-files runs-dir nil "\\`[^.]" t))
        (let ((path (expand-file-name entry runs-dir)))
          (when (file-directory-p path)
            (cond
             ((dl-satan-broker--bucket-name-p entry)
              (dolist (child (directory-files path nil "\\`[^.]" t))
                (let ((cpath (expand-file-name child path)))
                  (when (and (file-directory-p cpath)
                             (dl-satan-broker--legacy-run-name-p
                              (dl-satan-broker--run-id-from-leaf child)))
                    (push cpath acc)))))
             ((dl-satan-broker--legacy-run-name-p
               (dl-satan-broker--run-id-from-leaf entry))
              (push path acc)))))))
    acc))

(defun dl-satan-broker-run-dirs-for-date (runs-dir date-prefix)
  "Return absolute paths of run dirs under RUNS-DIR dated DATE-PREFIX.
DATE-PREFIX is YYYYMMDDT (matching the run-id's stem).  Matches both
the bucketed layout (looks under `<runs>/YYYY-MM-DD/') and the legacy
flat layout (filters by prefix on the leaf name)."
  (let ((iso-bucket
         (and (stringp date-prefix)
              (string-match "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T"
                            date-prefix)
              (format "%s-%s-%s"
                      (match-string 1 date-prefix)
                      (match-string 2 date-prefix)
                      (match-string 3 date-prefix)))))
    (cl-remove-if-not
     (lambda (path)
       (let* ((leaf (file-name-nondirectory path))
              (run-id (dl-satan-broker--run-id-from-leaf leaf))
              (parent (file-name-nondirectory (directory-file-name
                                               (file-name-directory path)))))
         (or (and iso-bucket (equal parent iso-bucket))
             (string-prefix-p date-prefix run-id))))
     (dl-satan-broker-list-run-dirs runs-dir))))

(defun dl-satan-broker--tool-ctx (run-ctx)
  "Return the tool-ctx plist handlers see.
Reads frozen `time_now' from RUN-CTX's prepare plist (allocated once
by `dl-satan-broker--prepare') rather than calling `format-time-string'
per tool call.  `run-started-at' aliases the same frozen value — a run
has exactly one starting moment."
  (let* ((mode (dl-satan-run-mode run-ctx))
         (prepare (dl-satan-run-prepare run-ctx))
         (time-now (plist-get prepare :time_now)))
    (list :id (dl-satan-run-id run-ctx)
          :mode-name (plist-get mode :name)
          :capabilities (plist-get mode :capabilities)
          :run-dir (dl-satan-run-dir run-ctx)
          :hippocampus-dir dl-satan-hippocampus-dir
          :run-started-at time-now
          :time-now time-now)))

(defun dl-satan-broker--tee-stdout (path chunk)
  (let ((coding-system-for-write 'utf-8))
    (write-region chunk nil path 'append 'silent)))

(defun dl-satan-broker--send-validated (run-ctx obj)
  "Send OBJ to the harness, auditing a protocol error if it's malformed.
Bad broker output is a bug, not a wire failure — we audit but still send
so the harness sees something rather than blocking on stdin."
  (let ((err (dl-satan-protocol-validate 'out obj)))
    (when err
      (dl-satan-audit-record
       (dl-satan-run-audit run-ctx) 'broker 'protocol-error
       (list :outbound t
             :type (plist-get err :type)
             :reason (plist-get err :reason)
             :raw obj))))
  (dl-satan-jsonl-send (dl-satan-run-process run-ctx) obj))

(defun dl-satan-broker--failed-action-payload (obj reason)
  "Return the canonical failed-action plist for tool-call OBJ + REASON.
Shape is `(:action (:type NAME :args ARGS) :reason MSG)' — see the
failed-action shape note in AGENTS.md.  Used by `--on-tool-call' to
audit every denied dispatch in a structure consumers can grep."
  (list :action (list :type (plist-get obj :name)
                      :args (or (plist-get obj :args) '()))
        :reason reason))

(defun dl-satan-broker--on-tool-call (run-ctx obj)
  (let* ((mode (dl-satan-run-mode run-ctx))
         (budget (plist-get mode :budget-tool-calls))
         (done (dl-satan-run-tool-calls-done run-ctx)))
    (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'in 'tool-call obj)
    (cond
     ((and (integerp budget) (>= done budget))
      (let* ((reason "tool call budget exhausted")
             (result (list :type "tool_result"
                           :id (plist-get obj :id)
                           :ok :false
                           :error reason)))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'tool-denied result)
        (dl-satan-audit-record
         (dl-satan-run-audit run-ctx) 'broker 'action-failed
         (dl-satan-broker--failed-action-payload obj reason))
        (dl-satan-broker--send-validated run-ctx result)))
     (t
      (setf (dl-satan-run-tool-calls-done run-ctx) (1+ done))
      (let* ((tool-ctx (dl-satan-broker--tool-ctx run-ctx))
             (result (dl-satan-tool-dispatch
                      obj (plist-get mode :tools) tool-ctx))
             (ok-p (eq (plist-get result :ok) t)))
        (dl-satan-audit-record
         (dl-satan-run-audit run-ctx)
         'broker
         (if ok-p 'tool-result 'tool-denied)
         result)
        (unless ok-p
          (dl-satan-audit-record
           (dl-satan-run-audit run-ctx) 'broker 'action-failed
           (dl-satan-broker--failed-action-payload
            obj (plist-get result :error))))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'out 'tool-result result)
        (dl-satan-broker--send-validated run-ctx result))))))

(defun dl-satan-broker--on-final (run-ctx obj)
  (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'in 'final obj)
  (setf (dl-satan-run-final run-ctx) obj))

(defun dl-satan-broker--on-log (run-ctx obj)
  (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'in 'log obj))

(defun dl-satan-broker--on-error (run-ctx obj)
  (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'in 'protocol-error obj)
  (setf (dl-satan-run-status run-ctx) 'failed))

(defun dl-satan-broker--dispatch (run-ctx obj)
  (let ((err (dl-satan-protocol-validate 'in obj)))
    (cond
     (err
      (dl-satan-audit-record
       (dl-satan-run-audit run-ctx) 'broker 'protocol-error
       (list :type (plist-get err :type)
             :reason (plist-get err :reason)
             :raw obj))
      (setf (dl-satan-run-status run-ctx) 'invalid-protocol))
     (t
      (pcase (plist-get obj :type)
        ("ready"     (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'in 'ready obj))
        ("log"       (dl-satan-broker--on-log run-ctx obj))
        ("tool_call" (dl-satan-broker--on-tool-call run-ctx obj))
        ("final"     (dl-satan-broker--on-final run-ctx obj))
        ("error"     (dl-satan-broker--on-error run-ctx obj)))))))

(defun dl-satan-broker--make-filter (run-ctx)
  (let ((inner (dl-satan-jsonl-make-filter
                (lambda (obj) (dl-satan-broker--dispatch run-ctx obj))
                (lambda (err)
                  (dl-satan-audit-record
                   (dl-satan-run-audit run-ctx) 'broker 'protocol-error
                   (list :raw-line (car err)
                         :error    (cdr err)))))))
    (lambda (proc chunk)
      (dl-satan-broker--tee-stdout
       (dl-satan-run-stdout-log-path run-ctx) chunk)
      (funcall inner proc chunk))))

(defun dl-satan-broker--finalize (run-ctx)
  "Output handler + audit close.  Idempotent."
  (when (eq (dl-satan-run-status run-ctx) 'running)
    (setf (dl-satan-run-status run-ctx)
          (if (dl-satan-run-final run-ctx) 'done 'failed)))
  (let* ((mode (dl-satan-run-mode run-ctx))
         (final (dl-satan-run-final run-ctx))
         (handler (plist-get mode :output-handler))
         (status (dl-satan-run-status run-ctx))
         (partition
          (when (and final (eq status 'done) handler)
            (condition-case err
                (funcall handler final (dl-satan-broker--tool-ctx run-ctx))
              (error
               (dl-satan-audit-record
                (dl-satan-run-audit run-ctx) 'broker 'action-failed
                (list :error (error-message-string err)))
               nil)))))
    (when partition
      (dolist (a (plist-get partition :applied))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'action-applied a))
      (dolist (a (plist-get partition :staged))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'action-staged a))
      (dolist (a (plist-get partition :rejected))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'action-rejected a))
      (dolist (a (plist-get partition :failed))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'action-failed a)))
    (dl-satan-audit-close
     (dl-satan-run-audit run-ctx)
     final
     (or partition (list :applied [] :staged [] :rejected [] :failed []))
     status)
    (dl-satan-broker--mark-failed-on-disk run-ctx)))

(defun dl-satan-broker--mark-failed-on-disk (run-ctx)
  "If RUN-CTX's status is not `done', rename its dir adding `.FAILED'.
Lets `ls runs/<YYYY-MM-DD>/' surface failures without opening each
`status' file.  Updates the in-memory dir on RUN-CTX and repoints
`runs/most-recent' so the symlink survives the rename.

Also dispatches a syslog warning + a streak-aware desktop notification
via `dl-satan-broker--announce-failure'."
  (let ((status (dl-satan-run-status run-ctx))
        (dir (dl-satan-run-dir run-ctx))
        (run-id (dl-satan-run-id run-ctx)))
    (when (and dir
               (not (eq status 'done))
               (not (string-suffix-p dl-satan-broker--failed-suffix dir))
               (file-directory-p dir))
      (let ((new-dir (concat dir dl-satan-broker--failed-suffix)))
        (unless (file-exists-p new-dir)
          (rename-file dir new-dir)
          (setf (dl-satan-run-dir run-ctx) new-dir)
          (dl-satan-broker--update-most-recent
           run-id dl-satan-broker--failed-suffix)
          (dl-satan-broker--announce-failure
           run-id
           (plist-get (dl-satan-run-mode run-ctx) :name)
           status
           (dl-satan-broker--failure-reason run-ctx)))))))

(defun dl-satan-broker--failure-reason (run-ctx)
  "Return a short reason string for RUN-CTX's failure.
Pulls from the final plist when available, else the status symbol."
  (let* ((final (dl-satan-run-final run-ctx))
         (final-reason (and final (plist-get final :reason))))
    (cond
     ((and (stringp final-reason) (not (string-empty-p final-reason)))
      final-reason)
     (t (symbol-name (dl-satan-run-status run-ctx))))))

(defcustom dl-satan-failure-syslog t
  "When non-nil, broker emits a `logger -t satan -p user.warn' line per failure.
Disable if `logger(1)' is absent or you don't want SATAN failures in
the user journal (`journalctl --user -t satan')."
  :type 'boolean :group 'dl-satan)

(defcustom dl-satan-failure-notify t
  "When non-nil, broker pops a D-Bus notification on the first failure of a streak.
Suppressed once a streak is in progress (subsequent failures are quiet
until at least one `done' run breaks the chain)."
  :type 'boolean :group 'dl-satan)

(defun dl-satan-broker--failure-streak-count (runs-dir)
  "Count consecutive `.FAILED' run dirs from newest backward in RUNS-DIR.
Walks both bucketed and legacy layouts via `dl-satan-broker-list-run-dirs'
and sorts by the run-id leaf (date-stamped, so a string sort is
monotonic-in-time enough for streak detection).  Returns 0 when the
newest run is non-failed or no runs exist."
  (let* ((paths (dl-satan-broker-list-run-dirs runs-dir))
         (sorted (sort paths
                       (lambda (a b)
                         (string-greaterp
                          (dl-satan-broker--run-id-from-leaf
                           (file-name-nondirectory a))
                          (dl-satan-broker--run-id-from-leaf
                           (file-name-nondirectory b))))))
         (streak 0))
    (cl-loop for p in sorted
             while (string-suffix-p dl-satan-broker--failed-suffix p)
             do (cl-incf streak))
    streak))

(defun dl-satan-broker--announce-failure (run-id mode-slug status reason)
  "Emit syslog + (streak-gated) notify-send for a failed run.
RUN-ID, MODE-NAME, STATUS (symbol), REASON (short string) compose the
log line and notification body."
  (let ((line (format "%s %s %s %s"
                      (symbol-name status) mode-slug run-id reason)))
    (when dl-satan-failure-syslog
      (ignore-errors
        (call-process "logger" nil 0 nil
                      "-t" "satan" "-p" "user.warn" line)))
    (when (and dl-satan-failure-notify
               (= 1 (dl-satan-broker--failure-streak-count
                     dl-satan-runs-dir)))
      (ignore-errors
        (require 'notifications)
        (notifications-notify
         :app-name "SATAN"
         :title (format "SATAN %s (%s)" (symbol-name status) mode-slug)
         :body line
         :urgency 'normal
         :timeout 6000)))))

(defun dl-satan-broker--make-sentinel (run-ctx)
  (lambda (_proc event)
    (when (string-match-p "\\(finished\\|exited\\|signal\\|broken\\)" event)
      (let ((tt (dl-satan-run-timeout-timer run-ctx)))
        (when tt (cancel-timer tt)))
      (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'child-exit
                             (list :event (string-trim event)))
      (dl-satan-broker--finalize run-ctx))))

(defun dl-satan-broker--build-manifest (mode run-id)
  "Return the manifest plist for MODE and RUN-ID.
Joins mechanical metadata (tools, capabilities, jail) with the
notes-owned model-facing schemas (`:tools' carries full JSON Schemas
including descriptions read from `dl-satan-tools-descriptions-dir').
The harness consumes `:tools' verbatim."
  (let* ((tool-names (plist-get mode :tools))
         (specs (mapcar (lambda (n)
                          (or (dl-satan-tool-lookup n)
                              (error "SATAN: unknown tool in mode %s: %s"
                                     (plist-get mode :name) n)))
                        tool-names))
         (tools-schema
          (vconcat (mapcar #'dl-satan-tool-json-schema specs)
                   (list (dl-satan-tool-final-schema)))))
    (list :run_id run-id
          :start_time (format-time-string "%Y-%m-%dT%H:%M:%S%z" nil)
          :mode (list :name (plist-get mode :name)
                      :auto_apply (symbol-name (plist-get mode :auto-apply))
                      :timeout_seconds (plist-get mode :timeout-seconds)
                      :budget_tool_calls (plist-get mode :budget-tool-calls))
          :tools_allowed tool-names
          :tools tools-schema
          :capabilities  (mapcar #'symbol-name
                                 (plist-get mode :capabilities))
          :harness (list :cmd (plist-get (plist-get mode :harness) :cmd)
                         :args (or (plist-get (plist-get mode :harness) :args)
                                   []))
          :jail_profile (symbol-name (plist-get mode :jail-profile))
          :context_summary (format "mode=%s date=%s"
                                   (plist-get mode :name)
                                   (format-time-string "%Y-%m-%d" nil)))))

(defun dl-satan-broker--most-recent-target (run-id &optional leaf-suffix)
  "Return the relative symlink target for RUN-ID's run dir.
For a bucketed run-id (the normal case) this is `<bucket>/<run-id>'
optionally with LEAF-SUFFIX appended (e.g. \".FAILED\").  For a run-id
that does not parse as bucketed, returns just the leaf."
  (let* ((bucket (dl-satan-broker--date-bucket-for-run-id run-id))
         (leaf (concat run-id (or leaf-suffix ""))))
    (if bucket (concat bucket "/" leaf) leaf)))

(defun dl-satan-broker--update-most-recent (run-id &optional leaf-suffix)
  "Repoint `dl-satan-runs-dir/most-recent' at RUN-ID's run dir.
LEAF-SUFFIX, when non-nil, is appended to the run-id leaf so the link
follows a post-status rename (e.g. `.FAILED').

Best-effort: failures (read-only fs, race with a concurrent run) are
swallowed so a busted symlink never aborts a run.  Target is stored
relative so the runs dir stays portable."
  (let ((link (expand-file-name "most-recent" dl-satan-runs-dir))
        (target (dl-satan-broker--most-recent-target run-id leaf-suffix)))
    (ignore-errors
      (when (or (file-symlink-p link) (file-exists-p link))
        (delete-file link))
      (make-symbolic-link target link t))))

(defun dl-satan-broker--write-budget-denied-run (mode prepare dir spent ceiling)
  "Write a slim audit bundle marking the run in PREPARE as budget-exceeded.
No child is spawned; the run terminates with status `budget-exceeded'
and a synthetic final summarising the gate decision.  PREPARE is the
prepare-phase run_ctx plist allocated by `dl-satan-broker--prepare'
(carries the frozen run_id + time_now)."
  (unless (file-directory-p dir) (make-directory dir t))
  (let ((run-id (plist-get prepare :run_id)))
    (dl-satan-broker--update-most-recent run-id)
    (let* ((manifest (dl-satan-broker--build-manifest mode run-id))
           (bundle (list :budget-denied t
                         :tokens_spent spent
                         :tokens_ceiling ceiling))
           (audit (dl-satan-audit-open dir manifest bundle prepare))
           (final (list :summary (format "budget-exceeded: %d/%d tokens spent today"
                                         spent ceiling)
                        :actions []
                        :reason "budget_daily_tokens"
                        :tokens_spent spent
                        :tokens_ceiling ceiling)))
      (dl-satan-audit-record audit 'broker 'budget-denied
                             (list :tokens_spent spent
                                   :tokens_ceiling ceiling))
      (dl-satan-audit-close audit final
                            (list :applied [] :staged [] :rejected [] :failed [])
                            'budget-exceeded)
      (let ((new-dir (concat dir dl-satan-broker--failed-suffix)))
        (when (and (file-directory-p dir)
                   (not (file-exists-p new-dir)))
          (rename-file dir new-dir)
          (dl-satan-broker--update-most-recent
           run-id dl-satan-broker--failed-suffix)
          (dl-satan-broker--announce-failure
           run-id (plist-get mode :name) 'budget-exceeded
           (format "%d/%d tokens" spent ceiling)))))))

(defun dl-satan-broker-run (name)
  "Resolve MODE-NAME, spawn jailed harness, drive it to completion.
Returns the run-id.

Single allocation site for `run_id' + `time_now': calls
`dl-satan-broker--prepare' exactly once at the start of the run.  The
returned run_ctx plist is threaded into context assembly, tool
dispatch, and audit.

If today's spend has met or exceeded `dl-satan-budget-daily-tokens',
the broker refuses to spawn: writes a minimal audit bundle with
`status=budget-exceeded' under
`dl-satan-runs-dir/<YYYY-MM-DD>/<run-id>/' and returns the run-id
without launching the child."
  (let* ((mode (dl-satan-mode-resolve name))
         (prepare (dl-satan-broker--prepare mode))
         (run-id (plist-get prepare :run_id))
         (dir (dl-satan-broker-run-dir-for-id run-id)))
    (if (dl-satan-budget-exceeded-p dl-satan-runs-dir)
        (let ((spent (dl-satan-budget-today-total dl-satan-runs-dir)))
          (dl-satan-broker--write-budget-denied-run
           mode prepare dir spent dl-satan-budget-daily-tokens)
          run-id)
      (dl-satan-broker--spawn mode prepare dir))))

(defun dl-satan-broker--spawn (mode prepare dir)
  "Spawn the jailed harness for MODE under DIR.
PREPARE is the run_ctx plist returned by `dl-satan-broker--prepare'
(carries the frozen run_id + time_now and v0 placeholder slots).
Returns the run-id."
  (let* ((run-id (plist-get prepare :run_id))
         (bundle-path (expand-file-name "bundle.json" dir))
         (stdout-log (expand-file-name "stdout.log" dir))
         (stderr-buf (generate-new-buffer
                      (format " *satan-stderr-%s*" run-id))))
    (unless (file-directory-p dir) (make-directory dir t))
    (dl-satan-broker--update-most-recent run-id)
    (unless (file-directory-p dl-satan-hippocampus-dir)
      (make-directory dl-satan-hippocampus-dir t))
    (let* ((bundle (funcall (or (plist-get mode :context-fn) #'ignore)
                            mode prepare))
           (manifest (dl-satan-broker--build-manifest mode run-id))
           (audit (dl-satan-audit-open dir manifest bundle prepare))
           (run-ctx (make-dl-satan-run
                     :id run-id
                     :mode mode
                     :start-time (plist-get prepare :start_time)
                     :dir dir
                     :bundle-path bundle-path
                     :pending-tool-calls (make-hash-table :test 'equal)
                     :tool-calls-done 0
                     :applied-actions nil
                     :staged-actions nil
                     :rejected-actions nil
                     :failed-actions nil
                     :final nil
                     :status 'running
                     :audit audit
                     :stdout-log-path stdout-log
                     :prepare prepare)))
      (let* ((cmd (plist-get (plist-get mode :harness) :cmd))
             (args (plist-get (plist-get mode :harness) :args))
             (provider (plist-get mode :provider))
             (model (plist-get mode :model))
             (budget-tokens (plist-get mode :budget-tokens))
             (key-var (and provider
                           (cdr (assq provider
                                      dl-satan-broker-provider-key-vars))))
             (key-val (and key-var
                           (condition-case _err
                               (dl-satan-broker--read-env key-var)
                             (error nil))))
             (provider-env (delq nil
                                 (list
                                  (when provider
                                    (format "SATAN_PROVIDER=%s" provider))
                                  (when model
                                    (format "SATAN_MODEL=%s" model))
                                  (when budget-tokens
                                    (format "SATAN_BUDGET_TOKENS=%d" budget-tokens))
                                  (when (and key-var key-val)
                                    (format "%s=%s" key-var key-val)))))
             (direnv-env (dl-satan-broker--direnv-env process-environment))
             (env (my/scrub-op-refs-env
                   (append (list (format "SATAN_RUN_ID=%s" run-id)
                                 (format "SATAN_RUN_DIR=%s" dir)
                                 (format "SATAN_BUNDLE=%s" bundle-path))
                           provider-env
                           (plist-get (plist-get mode :harness) :env)
                           direnv-env)))
             (process-environment env)
             (exec-path (dl-satan-broker--exec-path-from-env env))
             (proc
              (make-process
               :name (format "satan-%s" run-id)
               :command (cons cmd args)
               :connection-type 'pipe
               :coding 'utf-8
               :noquery t
               :stderr stderr-buf
               :filter (dl-satan-broker--make-filter run-ctx)
               :sentinel (dl-satan-broker--make-sentinel run-ctx))))
        (setf (dl-satan-run-process run-ctx) proc)
        (let ((to (plist-get mode :timeout-seconds)))
          (when (and (integerp to) (> to 0))
            (setf (dl-satan-run-timeout-timer run-ctx)
                  (run-with-timer
                   to nil
                   (lambda ()
                     (when (process-live-p proc)
                       (dl-satan-audit-record
                        (dl-satan-run-audit run-ctx) 'broker 'timeout
                        (list :after-seconds to))
                       (setf (dl-satan-run-status run-ctx) 'timed-out)
                       (delete-process proc)))))))
        (set-process-sentinel
         proc
         (let ((existing (process-sentinel proc)))
           (lambda (p e)
             (let ((coding-system-for-write 'utf-8))
               (with-current-buffer stderr-buf
                 (write-region (point-min) (point-max)
                               (expand-file-name "stderr.log" dir)
                               nil 'silent)))
             (funcall existing p e)
             (when (buffer-live-p stderr-buf) (kill-buffer stderr-buf)))))
        run-id))))

(provide 'dl-satan-broker)
;;; dl-satan-broker.el ends here
