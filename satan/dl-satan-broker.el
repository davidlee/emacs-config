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
  stdout-log-path)

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

(defun dl-satan-broker--mint-run-id (name)
  (random t)
  (format "%s-%s-%06x"
          (format-time-string "%Y%m%dT%H%M%S" nil)
          name
          (random (expt 16 6))))

(defun dl-satan-broker--tool-ctx (run-ctx)
  (let* ((mode (dl-satan-run-mode run-ctx))
         (fmt "%Y-%m-%dT%T%:z")
         (start (dl-satan-run-start-time run-ctx)))
    (list :id (dl-satan-run-id run-ctx)
          :mode-name (plist-get mode :name)
          :capabilities (plist-get mode :capabilities)
          :run-dir (dl-satan-run-dir run-ctx)
          :hippocampus-dir dl-satan-hippocampus-dir
          :run-started-at (and start (format-time-string fmt start))
          :time-now (format-time-string fmt))))

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

(defun dl-satan-broker--on-tool-call (run-ctx obj)
  (let* ((mode (dl-satan-run-mode run-ctx))
         (budget (plist-get mode :budget-tool-calls))
         (done (dl-satan-run-tool-calls-done run-ctx)))
    (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'in 'tool-call obj)
    (cond
     ((and (integerp budget) (>= done budget))
      (let ((result (list :type "tool_result"
                          :id (plist-get obj :id)
                          :ok :false
                          :error "tool call budget exhausted")))
        (dl-satan-audit-record (dl-satan-run-audit run-ctx) 'broker 'tool-denied result)
        (dl-satan-broker--send-validated run-ctx result)))
     (t
      (setf (dl-satan-run-tool-calls-done run-ctx) (1+ done))
      (let* ((tool-ctx (dl-satan-broker--tool-ctx run-ctx))
             (result (dl-satan-tool-dispatch
                      obj (plist-get mode :tools) tool-ctx)))
        (dl-satan-audit-record
         (dl-satan-run-audit run-ctx)
         'broker
         (if (eq (plist-get result :ok) t) 'tool-result 'tool-denied)
         result)
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
     status)))

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

(defun dl-satan-broker--update-most-recent (run-id)
  "Repoint `dl-satan-runs-dir/most-recent' at RUN-ID.
Best-effort: failures (read-only fs, race with a concurrent run) are
swallowed so a busted symlink never aborts a run.  Target is stored
relative so the runs dir stays portable."
  (let ((link (expand-file-name "most-recent" dl-satan-runs-dir)))
    (ignore-errors
      (when (or (file-symlink-p link) (file-exists-p link))
        (delete-file link))
      (make-symbolic-link run-id link t))))

(defun dl-satan-broker--write-budget-denied-run (mode run-id dir spent ceiling)
  "Write a slim audit bundle marking RUN-ID as budget-exceeded.
No child is spawned; the run terminates with status `budget-exceeded'
and a synthetic final summarising the gate decision."
  (unless (file-directory-p dir) (make-directory dir t))
  (dl-satan-broker--update-most-recent run-id)
  (let* ((manifest (dl-satan-broker--build-manifest mode run-id))
         (bundle (list :budget-denied t
                       :tokens_spent spent
                       :tokens_ceiling ceiling))
         (audit (dl-satan-audit-open dir manifest bundle))
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
                          'budget-exceeded)))

(defun dl-satan-broker-run (name)
  "Resolve MODE-NAME, spawn jailed harness, drive it to completion.
Returns the run-id.

If today's spend has met or exceeded `dl-satan-budget-daily-tokens',
the broker refuses to spawn: it mints a run-id, writes a minimal audit
bundle with `status=budget-exceeded' under
`dl-satan-runs-dir/<run-id>/', and returns the run-id without
launching the child."
  (let* ((mode (dl-satan-mode-resolve name))
         (run-id (dl-satan-broker--mint-run-id name))
         (dir (expand-file-name run-id dl-satan-runs-dir)))
    (if (dl-satan-budget-exceeded-p dl-satan-runs-dir)
        (let ((spent (dl-satan-budget-today-total dl-satan-runs-dir)))
          (dl-satan-broker--write-budget-denied-run
           mode run-id dir spent dl-satan-budget-daily-tokens)
          run-id)
      (dl-satan-broker--spawn mode run-id dir))))

(defun dl-satan-broker--spawn (mode run-id dir)
  "Spawn the jailed harness for MODE/RUN-ID under DIR.  Returns RUN-ID."
  (let* ((bundle-path (expand-file-name "bundle.json" dir))
         (stdout-log (expand-file-name "stdout.log" dir))
         (stderr-buf (generate-new-buffer
                      (format " *satan-stderr-%s*" run-id))))
    (unless (file-directory-p dir) (make-directory dir t))
    (dl-satan-broker--update-most-recent run-id)
    (unless (file-directory-p dl-satan-hippocampus-dir)
      (make-directory dl-satan-hippocampus-dir t))
    (let* ((bundle (funcall (or (plist-get mode :context-fn) #'ignore) mode))
           (manifest (dl-satan-broker--build-manifest mode run-id))
           (audit (dl-satan-audit-open dir manifest bundle))
           (run-ctx (make-dl-satan-run
                     :id run-id
                     :mode mode
                     :start-time (current-time)
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
                     :stdout-log-path stdout-log)))
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
             (env (append (list (format "SATAN_RUN_ID=%s" run-id)
                                (format "SATAN_RUN_DIR=%s" dir)
                                (format "SATAN_BUNDLE=%s" bundle-path))
                          provider-env
                          (plist-get (plist-get mode :harness) :env)
                          direnv-env))
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
