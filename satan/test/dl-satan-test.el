;;; dl-satan-test.el --- ert tests for SATAN -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     --eval "(require 'package)" \
;;     -l dl-satan-test.el -f ert-run-tests-batch-and-exit
;;
;; Or interactively: M-x ert RET t RET.

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'dl-secret)
(require 'dl-satan-jsonl)
(require 'dl-satan-protocol)
(require 'dl-satan-block)
(require 'dl-satan-tools)
(require 'dl-satan-tools-notify)
(require 'dl-satan-tools-hippocampus)
(require 'dl-satan-tools-inbox)
(require 'dl-satan-tools-org)
(require 'dl-satan-tools-agenda)
(require 'dl-satan-tools-activity)
(require 'dl-satan-tools-notes)
(require 'dl-satan-tools-atsatan)
(require 'dl-satan-tools-sway)
(require 'dl-satan-tools-docs)
(require 'dl-satan-tools-memory)
(require 'dl-satan-tools-motive)
(require 'dl-satan-tools-bough)
(require 'dl-satan-memory)
(require 'dl-satan-context)
(require 'dl-satan-output)
(require 'dl-satan-audit)
(require 'dl-satan-broker)
(require 'dl-satan-budget)
(require 'dl-satan-mode)
(require 'dl-satan-tick)
(require 'dl-satan-percept-test)

;; Shared helpers still used by remaining sections (context :now,
;; context framing rendering).  Move with the next context-test
;; extraction batch.
(defun dl-satan-test--path-suffix-p (suffix sources)
  (cl-some (lambda (s) (string-suffix-p suffix (plist-get s :path)))
           sources))

(defun dl-satan-test--write-framing (path)
  "Write the canonical framing keys to PATH for context-fn tests."
  (with-temp-file path
    (insert "now=# Now\n"
            "today=# Today (raw)\n"
            "sources=# Source files\n")))

(defun dl-satan-test--with-tool-descriptions (alist body-fn)
  "Run BODY-FN with `dl-satan-tools-descriptions-dir' bound to a tmp dir
populated from ALIST `((NAME . CONTENT) …)'.  Still used by remaining
broker manifest + budget sections; will move with those extractions."
  (let ((tmp (make-temp-file "satan-tools-" t)))
    (unwind-protect
        (let ((dl-satan-tools-descriptions-dir tmp))
          (dolist (pair alist)
            (with-temp-file (expand-file-name (concat (car pair) ".md") tmp)
              (insert (cdr pair))))
          (funcall body-fn))
      (delete-directory tmp t))))

;; ---------- dl-satan-tools-notes ----------

(defvar dl-satan-test--notes-fd-calls nil
  "List of (PROGRAM ARGS) recorded by `dl-satan-test--with-fd-stub'.")

(defmacro dl-satan-test--with-notes-root (&rest body)
  "Bind `dl-satan-tools-notes-root' to a temp dir for BODY."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "satan-notes-" t))
          (dl-satan-tools-notes-root dir))
     (unwind-protect (progn ,@body)
       (delete-directory dir t))))

(defmacro dl-satan-test--with-fd-stub (stdout exit-code &rest body)
  "Stub `call-process' so that calls to `dl-satan-tools-notes--fd-program'
return EXIT-CODE and write STDOUT to the capture buffer.  Records each call
into `dl-satan-test--notes-fd-calls'."
  (declare (indent 2))
  `(let ((dl-satan-test--notes-fd-calls nil))
     (cl-letf (((symbol-function 'call-process)
                (lambda (program &optional _infile destination _display &rest args)
                  (push (cons program args) dl-satan-test--notes-fd-calls)
                  (when (and destination (not (eq destination 0)))
                    (let ((out-buf (if (consp destination) (car destination) destination)))
                      (when (bufferp out-buf)
                        (with-current-buffer out-buf
                          (insert ,stdout)))
                      (when (eq out-buf t)
                        (insert ,stdout))))
                  ,exit-code)))
       ,@body)))

(defun dl-satan-test--touch (root rel &optional age-seconds)
  "Create REL under ROOT and set its mtime to now minus AGE-SECONDS (default 0)."
  (let* ((path (expand-file-name rel root))
         (parent (file-name-directory path)))
    (when parent (make-directory parent t))
    (with-temp-file path (insert ""))
    (let ((when (time-subtract (current-time) (or age-seconds 0))))
      (set-file-times path when))
    path))

(ert-deftest dl-satan-notes/builds-correct-fd-argv ()
  "fd is invoked with --changed-after Nh, -t f, --print0, --base-directory, --exclude satan."
  (dl-satan-test--with-notes-root
    (dl-satan-test--with-fd-stub "" 0
      (dl-satan-tool/notes-read '(:since-hours 24 :limit 10) nil)
      (let* ((call (car dl-satan-test--notes-fd-calls))
             (program (car call))
             (args (cdr call)))
        (should (equal program dl-satan-tools-notes--fd-program))
        (should (member "--changed-after" args))
        (should (member "24h" args))
        (should (member "-t" args))
        (should (member "f" args))
        (should (member "--print0" args))
        (should (member "--base-directory" args))
        (should (member dl-satan-tools-notes-root args))
        (should (member "--exclude" args))
        (should (member "satan" args))))))

(ert-deftest dl-satan-notes/parses-output-and-sorts-by-mtime-desc ()
  "Returns files newer-first; relative paths; correct count."
  (dl-satan-test--with-notes-root
    (dl-satan-test--touch dl-satan-tools-notes-root "old.org"    1000)
    (dl-satan-test--touch dl-satan-tools-notes-root "middle.org" 100)
    (dl-satan-test--touch dl-satan-tools-notes-root "newest.org" 1)
    (dl-satan-test--with-fd-stub "old.org\0middle.org\0newest.org\0" 0
      (let* ((res (dl-satan-tool/notes-read '(:since-hours 24) nil))
             (p (cdr res))
             (files (plist-get p :files)))
        (should (eq (car res) 'ok))
        (should (equal (plist-get p :count) 3))
        (should (equal (mapcar (lambda (f) (plist-get f :path)) files)
                       '("newest.org" "middle.org" "old.org")))))))

(ert-deftest dl-satan-notes/limit-default-and-clamp ()
  "Missing :limit applies default; out-of-range clamps to [1, 200]."
  (dl-satan-test--with-notes-root
    (let* ((paths (cl-loop for i from 1 to 250 collect
                           (format "f%03d.org" i)))
           (stdout (mapconcat #'identity paths "\0")))
      (cl-loop for p in paths
               for age from 1
               do (dl-satan-test--touch dl-satan-tools-notes-root p age))
      (dl-satan-test--with-fd-stub (concat stdout "\0") 0
        (let ((default-res (dl-satan-tool/notes-read '(:since-hours 24) nil))
              (hi-res (dl-satan-tool/notes-read '(:since-hours 24 :limit 9999) nil))
              (lo-res (dl-satan-tool/notes-read '(:since-hours 24 :limit 0) nil)))
          (should (equal (plist-get (cdr default-res) :limit)
                         dl-satan-tools-notes-default-limit))
          (should (equal (plist-get (cdr hi-res) :limit)
                         dl-satan-tools-notes--limit-max))
          (should (equal (plist-get (cdr lo-res) :limit) 1))
          (should (equal (length (plist-get (cdr hi-res) :files))
                         dl-satan-tools-notes--limit-max)))))))

(ert-deftest dl-satan-notes/since-hours-default-and-clamp ()
  "Missing :since-hours uses default; out-of-range clamps to [1, 720]."
  (dl-satan-test--with-notes-root
    (cl-flet ((argv-has-hours (hours)
                (let* ((call (car dl-satan-test--notes-fd-calls))
                       (args (cdr call)))
                  (member (format "%dh" hours) args))))
      (dl-satan-test--with-fd-stub "" 0
        (dl-satan-tool/notes-read nil nil)
        (should (argv-has-hours dl-satan-tools-notes-default-hours)))
      (dl-satan-test--with-fd-stub "" 0
        (dl-satan-tool/notes-read '(:since-hours 99999) nil)
        (should (argv-has-hours dl-satan-tools-notes--hours-max)))
      (dl-satan-test--with-fd-stub "" 0
        (dl-satan-tool/notes-read '(:since-hours 0) nil)
        (should (argv-has-hours 1))))))

(ert-deftest dl-satan-notes/parses-denote-filename-metadata ()
  "Denote-style filename → :title spaces + :tags list; plain → :title nil."
  (dl-satan-test--with-notes-root
    (dl-satan-test--touch dl-satan-tools-notes-root
                          "20260520T011750--actually-learn-git-deeply__fundamentals_git_tech.org"
                          1)
    (dl-satan-test--touch dl-satan-tools-notes-root "protocol.org" 2)
    (dl-satan-test--with-fd-stub
        "20260520T011750--actually-learn-git-deeply__fundamentals_git_tech.org\0protocol.org\0"
        0
      (let* ((res (dl-satan-tool/notes-read '(:since-hours 24) nil))
             (files (plist-get (cdr res) :files))
             (denote (cl-find-if (lambda (f)
                                   (string-match-p "actually-learn"
                                                   (plist-get f :path)))
                                 files))
             (plain (cl-find-if (lambda (f)
                                  (equal (plist-get f :path) "protocol.org"))
                                files)))
        (should (eq (car res) 'ok))
        (should (equal (plist-get denote :title) "actually learn git deeply"))
        (should (equal (plist-get denote :tags) '("fundamentals" "git" "tech")))
        (should (equal (plist-get denote :ext) "org"))
        (should (null (plist-get plain :title)))
        (should (null (plist-get plain :tags)))
        (should (equal (plist-get plain :ext) "org"))))))

(ert-deftest dl-satan-notes/fd-failure-returns-error ()
  "Non-zero fd exit → (error . \"fd failed: ...\")."
  (dl-satan-test--with-notes-root
    (dl-satan-test--with-fd-stub "" 1
      (let ((res (dl-satan-tool/notes-read '(:since-hours 24) nil)))
        (should (eq (car res) 'error))
        (should (string-match-p "fd failed" (cdr res)))))))

(ert-deftest dl-satan-notes/empty-stdout-empty-files ()
  "fd returns nothing → ok with :count 0 and :files '()."
  (dl-satan-test--with-notes-root
    (dl-satan-test--with-fd-stub "" 0
      (let* ((res (dl-satan-tool/notes-read '(:since-hours 24) nil))
             (p (cdr res)))
        (should (eq (car res) 'ok))
        (should (equal (plist-get p :count) 0))
        (should (equal (plist-get p :files) '()))))))

;; ---------- dl-satan-budget ----------

(defun dl-satan-test--write-transcript (dir lines)
  "Write LINES (each a plist) as transcript.jsonl under DIR."
  (make-directory dir t)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file (expand-file-name "transcript.jsonl" dir)
      (dolist (l lines)
        (insert (json-serialize
                 (dl-satan-jsonl-prepare l)
                 :null-object :null :false-object :false))
        (insert "\n")))))

(defun dl-satan-test--usage-record (tokens-total)
  (list :ts "2026-05-19T09:00:00.000000+1000"
        :dir "in" :event "log"
        :payload (list :type "log" :kind "usage"
                       :tokens_in 0 :tokens_out 0
                       :tokens_total tokens-total)))

(ert-deftest dl-satan-budget/run-tokens-takes-max-cumulative ()
  (let ((dir (make-temp-file "satan-bud-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           dir (list (dl-satan-test--usage-record 100)
                     (dl-satan-test--usage-record 350)
                     (dl-satan-test--usage-record 350)))
          (should (equal (dl-satan-budget--run-tokens dir) 350)))
      (delete-directory dir t))))

(ert-deftest dl-satan-budget/run-tokens-zero-when-no-usage ()
  (let ((dir (make-temp-file "satan-bud-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           dir (list (list :ts "x" :dir "in" :event "ready"
                           :payload (list :type "ready"))))
          (should (equal (dl-satan-budget--run-tokens dir) 0)))
      (delete-directory dir t))))

(ert-deftest dl-satan-budget/today-total-sums-today-prefix-only ()
  (let* ((root (make-temp-file "satan-bud-root-" t))
         (now (current-time))
         (today (format-time-string "%Y%m%dT" now))
         (yesterday (format-time-string
                     "%Y%m%dT"
                     (time-subtract now (days-to-time 1))))
         (today-a (expand-file-name (concat today "090000-x-aaaaaa") root))
         (today-b (expand-file-name (concat today "100000-x-bbbbbb") root))
         (older   (expand-file-name (concat yesterday "120000-x-cccccc") root)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           today-a (list (dl-satan-test--usage-record 1000)))
          (dl-satan-test--write-transcript
           today-b (list (dl-satan-test--usage-record 2500)))
          (dl-satan-test--write-transcript
           older   (list (dl-satan-test--usage-record 999999)))
          (should (equal (dl-satan-budget-today-total root now) 3500)))
      (delete-directory root t))))

(ert-deftest dl-satan-budget/exceeded-p-respects-ceiling ()
  (let* ((root (make-temp-file "satan-bud-root-" t))
         (now (current-time))
         (today (format-time-string "%Y%m%dT" now))
         (dir (expand-file-name (concat today "090000-x-aaaaaa") root)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           dir (list (dl-satan-test--usage-record 400000)))
          (let ((dl-satan-budget-daily-tokens 400000))
            (should (dl-satan-budget-exceeded-p root now)))
          (let ((dl-satan-budget-daily-tokens 400001))
            (should-not (dl-satan-budget-exceeded-p root now)))
          (let ((dl-satan-budget-daily-tokens nil))
            (should-not (dl-satan-budget-exceeded-p root now))))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/refuses-spawn-when-budget-exceeded ()
  "Pre-spawn gate writes status=budget-exceeded; no child spawned."
  (dl-satan-test--with-tool-descriptions
   '(("org_read_context"       . "Read.")
     ("org_update_owned_block" . "Write owned.")
     ("proposal_stage"         . "Stage.")
     ("notify_send"            . "Notify.")
     ("hippocampus_write"      . "Write hippo.")
     ("inbox_append"           . "Append inbox.")
     ("agenda_read"            . "Read agenda.")
     ("activity_read"          . "Read activity.")
     ("notes_recent"           . "List recent notes.")
     ("notes_at_satan_scan"    . "Scan @satan directives.")
     ("sway_border_set"        . "Retint sway borders.")
     ("sway_border_reset"      . "Restore sway borders.")
     ("bough_read"             . "Read bough.")
     ("memory_mark"            . "Mark.")
     ("memory_resonate"        . "Resonate.")
     ("memory_show_trace"      . "Show.")
     ("docs_list"              . "List docs.")
     ("docs_search"            . "Search docs.")
     ("docs_read"              . "Read doc.")
     ("motive_read"            . "Read motives.")
     ("motive_replace"         . "Replace motive.")
     ("satan_final"            . "Terminate."))
   (lambda ()
     (let* ((root (make-temp-file "satan-bud-broker-" t))
            (now (current-time))
            (today (format-time-string "%Y%m%dT" now))
            (existing (expand-file-name (concat today "080000-x-eeeeee") root))
            (dl-satan-runs-dir root)
            (dl-satan-budget-daily-tokens 400000))
       (unwind-protect
           (progn
             (dl-satan-test--write-transcript
              existing (list (dl-satan-test--usage-record 500000)))
             (let* ((run-id (dl-satan-broker-run "morning"))
                    (dir (dl-satan-broker-locate-run-dir run-id root))
                    (status-path (expand-file-name "status" dir)))
               (should (string-suffix-p ".FAILED" dir))
               (should (file-directory-p dir))
               (should (file-readable-p status-path))
               (should (equal (string-trim
                               (with-temp-buffer
                                 (insert-file-contents status-path)
                                 (buffer-string)))
                              "budget-exceeded"))
               (should (eq (dl-satan-audit-verify-run dir) t))
               (let* ((final-path (expand-file-name "final.json" dir))
                      (final (with-temp-buffer
                               (insert-file-contents final-path)
                               (goto-char (point-min))
                               (json-parse-buffer
                                :object-type 'plist
                                :array-type 'list
                                :null-object :null
                                :false-object :false))))
                 (should (string-match-p "budget-exceeded"
                                         (plist-get final :summary)))
                 (should (equal (plist-get final :reason)
                                "budget_daily_tokens")))))
         (delete-directory root t))))))

;; ---------- dl-satan-audit verifier ----------

(defun dl-satan-test--write-run (dir final actions status &optional transcript)
  (make-directory dir t)
  (let ((audit (dl-satan-audit-open dir
                                    '(:run_id "r" :mode (:name "test"))
                                    '(:bundle t))))
    (dolist (rec (or transcript '()))
      (dl-satan-audit-record audit (nth 0 rec) (nth 1 rec) (nth 2 rec)))
    (dl-satan-audit-close audit final actions status)))

(ert-deftest dl-satan-audit/verifier-ok ()
  (let ((dir (make-temp-file "satan-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))
             (broker tool-result (:id "a" :ok t))))
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

;; ---------- dl-satan-broker pre_spawn threading (Phase 4.4) ----------

(ert-deftest dl-satan-broker/finalize-threads-pre-spawn-into-actions-json ()
  "broker--finalize copies `:pre_spawn' from the prepare run_ctx into the
actions plist passed to `dl-satan-audit-close', which lands the
entries in `actions.json'.  Phase 4.4 — wires the producer side
(Phase 4.3 `sensor-alerts.check') into the audit close (Phase 0.3
schema bump)."
  (let ((dir (make-temp-file "satan-broker-pre-spawn-" t))
        (entries (list (list :kind "sensor_alert"
                             :cause "panopticon_current_stale"
                             :severity "warning"
                             :message "stale 28m"
                             :suppressed :false
                             :dispatched_at "2026-05-22T11:13Z"))))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-22T11:13Z"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil
                              :pre_spawn entries))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 30
                       :budget-tool-calls 1 :capabilities ()))
               (run-ctx (make-dl-satan-run
                         :id "rid"
                         :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir
                         :status 'running
                         :final '(:summary "ok" :actions ())
                         :audit audit
                         :prepare prepare)))
          (cl-letf (((symbol-function 'dl-satan-broker--mark-failed-on-disk)
                     (lambda (&rest _) nil)))
            (dl-satan-broker--finalize run-ctx))
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (let ((ps (plist-get parsed :pre_spawn)))
              (should (listp ps))
              (should (= 1 (length ps)))
              (should (equal "panopticon_current_stale"
                             (plist-get (car ps) :cause)))
              (should (equal "2026-05-22T11:13Z"
                             (plist-get (car ps) :dispatched_at))))
            (should (eq (dl-satan-audit-verify-run dir) t))))
      (delete-directory dir t))))

(ert-deftest dl-satan-broker/finalize-omits-pre-spawn-when-empty ()
  "When `:pre_spawn' is nil on prepare, actions.json omits the key
entirely so untouched runs keep the original four-partition shape."
  (let ((dir (make-temp-file "satan-broker-pre-spawn-empty-" t)))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-22T11:13Z"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil :pre_spawn nil))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 30
                       :budget-tool-calls 1 :capabilities ()))
               (run-ctx (make-dl-satan-run
                         :id "rid"
                         :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir
                         :status 'running
                         :final '(:summary "ok" :actions ())
                         :audit audit
                         :prepare prepare)))
          (cl-letf (((symbol-function 'dl-satan-broker--mark-failed-on-disk)
                     (lambda (&rest _) nil)))
            (dl-satan-broker--finalize run-ctx))
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (should-not (plist-member parsed :pre_spawn))))
      (delete-directory dir t))))

;; ---------- dl-satan-audit pre_spawn (Phase 0.3) ----------

(ert-deftest dl-satan-audit/pre-spawn-key-written-when-present ()
  "`dl-satan-audit-close' writes `:pre_spawn' into actions.json when the
caller supplies it; the four model-action partitions stay untouched."
  (let ((dir (make-temp-file "satan-prespawn-write-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :kind "sensor_alert"
                                        :cause "panopticon_current_stale"
                                        :severity "warning"
                                        :message "stale 28m"
                                        :dispatched_at "2026-05-22T11:13Z")))
           'done)
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (should (equal (plist-get parsed :applied) '()))
            (should (equal (plist-get parsed :staged) '()))
            (should (equal (plist-get parsed :rejected) '()))
            (should (equal (plist-get parsed :failed) '()))
            (let ((ps (plist-get parsed :pre_spawn)))
              (should (listp ps))
              (should (= 1 (length ps)))
              (should (equal (plist-get (car ps) :kind) "sensor_alert"))
              (should (equal (plist-get (car ps) :cause)
                             "panopticon_current_stale")))))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/pre-spawn-omitted-when-absent ()
  "Runs without `:pre_spawn' omit the key entirely from actions.json."
  (let ((dir (make-temp-file "satan-prespawn-absent-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done)
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (should-not (plist-member parsed :pre_spawn))))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-accepts-pre-spawn-run ()
  "A run carrying a single `pre_spawn' sensor_alert and zero model
actions still verifies clean — `pre_spawn' must NOT pollute the
{applied,staged,rejected,failed} partition count invariant against
`final.actions'."
  (let ((dir (make-temp-file "satan-prespawn-verify-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "no model actions, sensor alert pre-spawn"
             :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :kind "sensor_alert"
                                        :cause "panopticon_current_stale"
                                        :severity "warning"
                                        :message "stale 28m"
                                        :remediation "systemctl --user status panopticon-sway"
                                        :suppressed :false
                                        :dispatched_at "2026-05-22T11:13Z")))
           'done)
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-rejects-malformed-pre-spawn ()
  "An entry missing the `kind' discriminator is malformed structure
(distinct from an unknown discriminant value).  Verifier flags it."
  (let ((dir (make-temp-file "satan-prespawn-bad-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "" :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :cause "no_kind_here")))
           'done)
          (let ((res (dl-satan-audit-verify-run dir)))
            (should (consp res))
            (should (assq 'pre-spawn-shape res))))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-accepts-unknown-pre-spawn-kind ()
  "Unknown `kind' discriminants are accepted gracefully (forward-compat);
only malformed STRUCTURE is rejected."
  (let ((dir (make-temp-file "satan-prespawn-unknown-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "" :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :kind "future_thing_v2"
                                        :payload "whatever")))
           'done)
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/validate-actions-pure ()
  "`dl-satan-audit-validate-actions' is a pure (in-memory) validator over
the actions.json shape — usable from fixtures without touching disk."
  (should (null (dl-satan-audit-validate-actions
                 '(:applied () :staged () :rejected () :failed ()))))
  (should (null (dl-satan-audit-validate-actions
                 (list :applied () :staged () :rejected () :failed ()
                       :pre_spawn (list (list :kind "sensor_alert"
                                              :cause "x" :message "y"))))))
  (should (stringp (dl-satan-audit-validate-actions
                    (list :applied () :staged () :rejected () :failed ()
                          :pre_spawn (list (list :cause "no_kind")))))))

(ert-deftest dl-satan-audit/verifier-detects-orphan-call ()
  (let ((dir (make-temp-file "satan-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))))
          (let ((res (dl-satan-audit-verify-run dir)))
            (should (consp res))
            (should (assq 'calls-match-results res))))
      (delete-directory dir t))))

;; ---------- dl-satan-context :now ----------

(ert-deftest dl-satan-context/now-plist-shape ()
  "`:now' carries every key the harness renders into `# Now'."
  (let* ((time (encode-time 0 30 14 19 5 2026 nil nil 36000)) ; +1000
         (now (dl-satan-context-now time)))
    (should (stringp (plist-get now :iso_date)))
    (should (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
                            (plist-get now :iso_date)))
    (should (stringp (plist-get now :weekday)))
    (should (string-match-p "\\`[0-9]\\{4\\}-W[0-9]\\{2\\}\\'"
                            (plist-get now :iso_week)))
    (should (string-match-p "\\`[0-9]\\{2\\}:[0-9]\\{2\\}\\'"
                            (plist-get now :time)))
    (should (stringp (plist-get now :tz_offset)))
    (should (stringp (plist-get now :tz_name)))))

(ert-deftest dl-satan-context/motd-bundle-carries-now ()
  (let* ((tmp (make-temp-file "satan-now-" t))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "system" tmp))
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/p.txt" tmp) (insert "P"))
          (let* ((spec (list :name "motd"
                             :prompt-file (expand-file-name "prompts/p.txt" tmp)))
                 (bundle (dl-satan-context-motd spec))
                 (now (plist-get bundle :now)))
            (should (plistp now))
            (should (stringp (plist-get now :iso_date)))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/tick-bundle-carries-now ()
  (let* ((tmp (make-temp-file "satan-now-" t))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "system" tmp))
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/p.txt" tmp) (insert "P"))
          (let* ((spec (list :name "tick-pulse"
                             :prompt-file (expand-file-name "prompts/p.txt" tmp)))
                 (bundle (dl-satan-context-tick spec))
                 (now (plist-get bundle :now)))
            (should (plistp now))
            (should (stringp (plist-get now :time)))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/self-edit-bundle-carries-now ()
  (let* ((tmp (make-temp-file "satan-now-" t))
         (root (expand-file-name "rrr" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory root t)
          (make-directory (expand-file-name "system" tmp))
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          (with-temp-file (expand-file-name "only.el" root) (insert "x"))
          (let* ((spec (list :name "self-edit-mech"
                             :prompt-file (expand-file-name "prompts/se.txt" tmp)
                             :source-roots (list root)))
                 (bundle (dl-satan-context-self-edit spec))
                 (now (plist-get bundle :now)))
            (should (plistp now))
            (should (stringp (plist-get now :iso_date)))))
      (delete-directory tmp t))))

;; ---------- dl-satan-context framing rendering ----------

(defun dl-satan-test--with-framing (body-fn)
  "Run BODY-FN with `dl-satan-system-framing-file' bound to a temp file."
  (let* ((tmp (make-temp-file "satan-framing-" t))
         (path (expand-file-name "framing.txt" tmp)))
    (unwind-protect
        (let ((dl-satan-system-framing-file path))
          (dl-satan-test--write-framing path)
          (funcall body-fn))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/framing-parses-key-value ()
  (let ((alist (dl-satan-context--parse-framing
                "# comment\nnow=# Now\n\ntoday=# Today (raw)\nsources=# Source files\n")))
    (should (equal (cdr (assoc "now" alist)) "# Now"))
    (should (equal (cdr (assoc "today" alist)) "# Today (raw)"))
    (should (equal (cdr (assoc "sources" alist)) "# Source files"))))

(ert-deftest dl-satan-context/framing-missing-key-errors ()
  (let* ((tmp (make-temp-file "satan-framing-" t))
         (path (expand-file-name "framing.txt" tmp))
         (dl-satan-system-framing-file path))
    (unwind-protect
        (progn
          (with-temp-file path (insert "now=# Now\n"))
          (should-error (dl-satan-context--framing) :type 'error))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/framing-missing-file-errors ()
  (let ((dl-satan-system-framing-file "/tmp/satan-framing-does-not-exist-XYZ.txt"))
    (should-error (dl-satan-context--framing) :type 'error)))

(ert-deftest dl-satan-context/render-prompt-now-block ()
  "Rendered prompt prepends scaffold+mode and emits a `# Now' block."
  (dl-satan-test--with-framing
   (lambda ()
     (let* ((bundle (list :now (list :iso_date "2026-05-19"
                                     :weekday "Tuesday"
                                     :iso_week "2026-W21"
                                     :time "09:00"
                                     :tz_offset "+1000"
                                     :tz_name "AEST")))
            (out (dl-satan-context--render-prompt "ASSEMBLED" bundle)))
       (should (string-prefix-p "ASSEMBLED\n\n# Now\n" out))
       (should (string-match-p "^date: 2026-05-19 (Tuesday, ISO 2026-W21)$" out))
       (should (string-match-p "^time: 09:00 \\+1000 AEST$" out))))))

(ert-deftest dl-satan-context/render-prompt-skips-empty-now ()
  "Missing or empty `:now' produces no `# Now' header."
  (dl-satan-test--with-framing
   (lambda ()
     (let ((out (dl-satan-context--render-prompt "ASSEMBLED" '())))
       (should (equal out "ASSEMBLED"))
       (should-not (string-match-p "^# Now$" out))))))

(ert-deftest dl-satan-context/render-prompt-today-block ()
  "Non-empty `:today_text' produces a `# Today (raw)' block; empty skips."
  (dl-satan-test--with-framing
   (lambda ()
     (let ((with-today (dl-satan-context--render-prompt
                       "ASSEMBLED" (list :today_text "body text"))))
       (should (string-match-p "# Today (raw)\nbody text" with-today)))
     (let ((sans-today (dl-satan-context--render-prompt
                       "ASSEMBLED" (list :today_text ""))))
       (should-not (string-match-p "# Today (raw)" sans-today))))))

(ert-deftest dl-satan-context/render-prompt-sources-block ()
  "Each source emits a fenced `## PATH' subsection under `# Source files'."
  (dl-satan-test--with-framing
   (lambda ()
     (let* ((sources (list (list :path "satan/x.el" :content "(provide 'x)")
                           (list :path "satan/y.py" :content "x = 1")))
            (out (dl-satan-context--render-prompt
                  "ASSEMBLED" (list :sources sources))))
       (should (string-match-p "^# Source files$" out))
       (should (string-match-p "^## satan/x.el$" out))
       (should (string-match-p "(provide 'x)" out))
       (should (string-match-p "^## satan/y.py$" out))
       (should (string-match-p "^x = 1$" out))))))

(ert-deftest dl-satan-context/render-prompt-section-ordering ()
  "Sections render in canonical order: Now, then Today, then Source files."
  (dl-satan-test--with-framing
   (lambda ()
     (let* ((bundle (list :now (list :iso_date "2026-05-19" :time "09:00")
                          :today_text "BODY"
                          :sources (list (list :path "p" :content "c"))))
            (out (dl-satan-context--render-prompt "A" bundle))
            (i-now    (string-match "^# Now$"          out))
            (i-today  (string-match "^# Today (raw)$"  out))
            (i-source (string-match "^# Source files$" out)))
       (should i-now)
       (should i-today)
       (should i-source)
       (should (< i-now i-today))
       (should (< i-today i-source))))))

;; ---------- dl-satan-protocol ----------

(defun dl-satan-test--protocol-fixture-direction (entry)
  (intern (plist-get entry :direction)))

(defun dl-satan-test--wire-fixture-p (entry)
  "Non-nil when ENTRY is a wire-protocol fixture (direction in|out).
Skips Phase-0.4 `actions' fixtures which are validated by
`dl-satan-audit-validate-actions', not the wire protocol module."
  (member (plist-get entry :direction) '("in" "out")))

(ert-deftest dl-satan-protocol/fixtures-valid-pass ()
  "Every wire fixture marked `valid' validates clean."
  (dolist (entry (dl-satan-protocol-fixtures))
    (when (and (string= (plist-get entry :kind) "valid")
               (dl-satan-test--wire-fixture-p entry))
      (let* ((direction (dl-satan-test--protocol-fixture-direction entry))
             (msg (plist-get entry :message))
             (err (dl-satan-protocol-validate direction msg)))
        (should (null err))))))

(ert-deftest dl-satan-protocol/fixtures-invalid-fail ()
  "Every wire fixture marked `invalid' validates to a matching reason."
  (dolist (entry (dl-satan-protocol-fixtures))
    (when (and (string= (plist-get entry :kind) "invalid")
               (dl-satan-test--wire-fixture-p entry))
      (let* ((direction (dl-satan-test--protocol-fixture-direction entry))
             (msg (plist-get entry :message))
             (expected (plist-get entry :reason))
             (name (plist-get entry :name))
             (err (dl-satan-protocol-validate direction msg)))
        (should (not (null err)))
        (should
         (equal expected (plist-get err :reason)))
        (ignore name)))))

(ert-deftest dl-satan-audit/fixtures-actions-valid-pass ()
  "Every actions fixture marked `valid' passes `validate-actions'.
Asserts the suite is non-empty so a fixture-file regression is loud."
  (let ((seen 0))
    (dolist (entry (dl-satan-protocol-fixtures))
      (when (and (string= (plist-get entry :kind) "valid")
                 (string= (plist-get entry :direction) "actions"))
        (cl-incf seen)
        (let* ((msg (plist-get entry :message))
               (err (dl-satan-audit-validate-actions msg))
               (name (plist-get entry :name)))
          (should (null err))
          (ignore name))))
    (should (> seen 0))))

(ert-deftest dl-satan-audit/fixtures-actions-invalid-fail ()
  "Every actions fixture marked `invalid' fails with the fixture's reason."
  (let ((seen 0))
    (dolist (entry (dl-satan-protocol-fixtures))
      (when (and (string= (plist-get entry :kind) "invalid")
                 (string= (plist-get entry :direction) "actions"))
        (cl-incf seen)
        (let* ((msg (plist-get entry :message))
               (expected (plist-get entry :reason))
               (name (plist-get entry :name))
               (err (dl-satan-audit-validate-actions msg)))
          (should (stringp err))
          (should (equal expected err))
          (ignore name))))
    (should (> seen 0))))

(ert-deftest dl-satan-protocol/rejects-bad-direction ()
  (should-error (dl-satan-protocol-validate 'sideways
                                            '(:type "ready" :run_id "x"))))

(ert-deftest dl-satan-protocol/tool-result-ok-true-passes ()
  (should (null (dl-satan-protocol-validate
                 'out
                 '(:type "tool_result" :id "c1" :ok t :result (:content ""))))))

(ert-deftest dl-satan-protocol/tool-result-ok-false-passes ()
  (should (null (dl-satan-protocol-validate
                 'out
                 '(:type "tool_result" :id "c1" :ok :false :error "denied")))))

(provide 'dl-satan-test)
;;; dl-satan-test.el ends here
