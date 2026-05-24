;;; dl-satan-broker-test.el --- ert tests for dl-satan-broker -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/lisp -L ~/.emacs.d/org \
;;     -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-broker-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'json)                          ; budget gating test parses final.json
(require 'dl-satan-jsonl)
(require 'dl-satan-audit)
(require 'dl-satan-broker)
(require 'dl-satan-budget)               ; budget gating cross-cutter
(require 'cl-macs)                       ; cl-letf used in tool-ctx tests
(require 'dl-satan-mode)                 ; manifest-tools-shape resolves "morning"
;; Tool modules must be loaded so each registers via `dl-satan-tool-register'
;; before `dl-satan-broker--build-manifest' looks them up.
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

;; Cross-cutter: assertion subject is broker (action-failed audit
;; emission); secondary subject is the tools dispatcher's
;; capability-guard.  Filed under broker per T6 brief.
(ert-deftest dl-satan-broker/capability-denial-emits-failed-action-audit ()
  "On dispatch capability denial, broker writes an `action-failed' audit
record using the canonical failed-action plist shape
`(:action ACTION :reason MSG)' alongside the tool_result record."
  (let* ((mode (list :name "test-mode"
                     :capabilities '(inbox-write)
                     :tools '("notify_send")
                     :budget-tool-calls 4))
         (dir (make-temp-file "satan-cap-audit-" t)))
    (unwind-protect
        (let* ((audit (dl-satan-audit-open
                       dir
                       '(:run_id "rid" :mode (:name "test-mode"))
                       '(:bundle t)
                       (list :run_id "rid"
                             :time_now "2026-05-22T10:00:00+1000")))
               (prepare (list :run_id "rid"
                              :time_now "2026-05-22T10:00:00+1000"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :pre_spawn nil :motive nil))
               (run-ctx (make-dl-satan-run
                         :id "rid" :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir :tool-calls-done 0
                         :status 'running
                         :audit audit
                         :prepare prepare))
               ;; Hold process slot so send-validated has something to call;
               ;; intercept the send instead of touching a real pipe.
               (sent nil))
          (cl-letf (((symbol-function 'dl-satan-jsonl-send)
                     (lambda (_proc obj) (push obj sent))))
            (dl-satan-broker--on-tool-call
             run-ctx
             '(:type "tool_call" :id "c-cap" :name "notify_send"
               :args (:title "t" :body "b"))))
          (let* ((records (dl-satan-audit--read-jsonl
                           (expand-file-name "transcript.jsonl" dir)))
                 (failed-action (cl-find-if
                                 (lambda (r)
                                   (and (equal (plist-get r :dir) "broker")
                                        (equal (plist-get r :event)
                                               "action-failed")))
                                 records)))
            (should failed-action)
            (let ((payload (plist-get failed-action :payload)))
              (should (plistp payload))
              (let ((action (plist-get payload :action))
                    (reason (plist-get payload :reason)))
                (should (plistp action))
                (should (equal (plist-get action :type) "notify_send"))
                (should (equal (plist-get (plist-get action :args) :title) "t"))
                (should (stringp reason))
                (should (string-match-p "capability" reason))
                (should (string-match-p "notify" reason))))))
      (delete-directory dir t))))

;; ---------- dl-satan-broker tool-ctx ----------

(ert-deftest dl-satan-broker/tool-ctx-shape ()
  "Tool-ctx carries run-id, mode, capabilities, dirs, and frozen time fields
read from the prepare-phase run_ctx plist."
  (let* ((mode '(:name morning :capabilities (memory-write)))
         (start (encode-time '(0 0 10 19 5 2026 nil nil 36000)))
         (prepare (list :run_id "20260519T100000-morning-abc123"
                        :time_now "2026-05-19T10:00:00+1000"
                        :start_time start
                        :evidence nil :percept nil
                        :sensor_status nil :pre_spawn nil :motive nil))
         (run-ctx (make-dl-satan-run
                   :id "20260519T100000-morning-abc123"
                   :mode mode
                   :start-time start
                   :dir "/tmp/satan-run-test"
                   :prepare prepare))
         (tool-ctx (dl-satan-broker--tool-ctx run-ctx)))
    (should (equal (plist-get tool-ctx :id)
                   "20260519T100000-morning-abc123"))
    (should (equal (plist-get tool-ctx :mode-name) 'morning))
    (should (equal (plist-get tool-ctx :capabilities) '(memory-write)))
    (should (equal (plist-get tool-ctx :run-dir) "/tmp/satan-run-test"))
    (should (equal (plist-get tool-ctx :run-started-at)
                   "2026-05-19T10:00:00+1000"))
    (should (equal (plist-get tool-ctx :time-now)
                   "2026-05-19T10:00:00+1000"))))

(ert-deftest dl-satan-broker/tool-ctx-does-not-call-format-time-string ()
  "tool-ctx must read time_now from run_ctx, never compute it on demand."
  (let* ((mode '(:name morning :capabilities ()))
         (prepare (list :run_id "rid" :time_now "2026-01-01T00:00:00+0000"
                        :start_time (current-time)
                        :evidence nil :percept nil
                        :sensor_status nil :pre_spawn nil :motive nil))
         (run-ctx (make-dl-satan-run
                   :id "rid" :mode mode
                   :start-time (plist-get prepare :start_time)
                   :dir "/tmp/x" :prepare prepare))
         (called nil))
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (&rest args) (setq called args) "NEVER")))
      (let ((tool-ctx (dl-satan-broker--tool-ctx run-ctx)))
        (should (equal (plist-get tool-ctx :time-now)
                       "2026-01-01T00:00:00+0000"))
        (should (null called))))))

(ert-deftest dl-satan-broker/date-bucket-extracted-from-run-id ()
  (should (equal (dl-satan-broker--date-bucket-for-run-id
                  "20260520T163446-tick-pulse-5e8018")
                 "2026-05-20"))
  (should (null (dl-satan-broker--date-bucket-for-run-id "garbage")))
  (should (null (dl-satan-broker--date-bucket-for-run-id nil))))

(ert-deftest dl-satan-broker/run-id-from-leaf-strips-failed-suffix ()
  (should (equal (dl-satan-broker--run-id-from-leaf
                  "20260520T163446-tick-pulse-5e8018.FAILED")
                 "20260520T163446-tick-pulse-5e8018"))
  (should (equal (dl-satan-broker--run-id-from-leaf
                  "20260520T163446-tick-pulse-5e8018")
                 "20260520T163446-tick-pulse-5e8018")))

(ert-deftest dl-satan-broker/list-run-dirs-walks-both-layouts ()
  "Enumerator returns paths for legacy flat and bucketed runs, plus FAILED."
  (let ((root (make-temp-file "satan-runs-list-" t)))
    (unwind-protect
        (let ((legacy   (expand-file-name "20260519T100000-x-aaaaaa" root))
              (legacy-f (expand-file-name "20260519T110000-x-bbbbbb.FAILED" root))
              (bucket   (expand-file-name "2026-05-20" root))
              (bucketed (expand-file-name
                         "2026-05-20/20260520T120000-x-cccccc" root))
              (bucketed-f (expand-file-name
                           "2026-05-20/20260520T130000-x-dddddd.FAILED" root))
              (noise    (expand-file-name "not-a-run-dir" root))
              (noise-bucket-child
               (expand-file-name "2026-05-20/scratch" root)))
          (dolist (d (list legacy legacy-f bucket bucketed bucketed-f
                           noise noise-bucket-child))
            (make-directory d t))
          (let ((got (dl-satan-broker-list-run-dirs root)))
            (should (member legacy got))
            (should (member legacy-f got))
            (should (member bucketed got))
            (should (member bucketed-f got))
            (should-not (member noise got))
            (should-not (member noise-bucket-child got))
            (should-not (cl-find-if (lambda (p)
                                      (equal (file-name-nondirectory p)
                                             "2026-05-20"))
                                    got))))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/failure-streak-counts-trailing-failed ()
  "Counts consecutive .FAILED dirs back from the newest run-id."
  (let ((root (make-temp-file "satan-runs-streak-" t)))
    (unwind-protect
        (progn
          ;; Empty → 0.
          (should (= 0 (dl-satan-broker--failure-streak-count root)))
          ;; One done run → 0.
          (make-directory
           (expand-file-name "2026-05-20/20260520T100000-x-aaaaaa" root) t)
          (should (= 0 (dl-satan-broker--failure-streak-count root)))
          ;; Add a newer FAILED run → 1.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T110000-x-bbbbbb.FAILED" root) t)
          (should (= 1 (dl-satan-broker--failure-streak-count root)))
          ;; And another → 2.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T120000-x-cccccc.FAILED" root) t)
          (should (= 2 (dl-satan-broker--failure-streak-count root)))
          ;; A done run on top breaks the streak → 0.
          (make-directory
           (expand-file-name "2026-05-20/20260520T130000-x-dddddd" root) t)
          (should (= 0 (dl-satan-broker--failure-streak-count root))))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/announce-failure-syslog-and-streak-gate ()
  "Always logs via syslog; only notifies on streak == 1."
  (let* ((logged nil)
         (notified 0)
         (root (make-temp-file "satan-runs-announce-" t))
         (dl-satan-runs-dir root)
         (dl-satan-failure-syslog t)
         (dl-satan-failure-notify t))
    (unwind-protect
        (cl-letf
            (((symbol-function 'call-process)
              (lambda (cmd &rest args)
                (when (equal cmd "logger") (push args logged))
                0))
             ((symbol-function 'notifications-notify)
              (lambda (&rest _args) (cl-incf notified) 42)))
          ;; No prior runs → streak == 0 before rename; the just-renamed
          ;; dir is what bumps it to 1.  Emulate by creating that dir
          ;; first, then calling announce.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T100000-tick-pulse-aaaaaa.FAILED" root) t)
          (dl-satan-broker--announce-failure
           "20260520T100000-tick-pulse-aaaaaa" "tick-pulse"
           'failed "child-exit-1")
          (should (= 1 (length logged)))
          (should (= 1 notified))
          ;; Second consecutive failure → still logged, NOT notified.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T110000-tick-pulse-bbbbbb.FAILED" root) t)
          (dl-satan-broker--announce-failure
           "20260520T110000-tick-pulse-bbbbbb" "tick-pulse"
           'failed "child-exit-1")
          (should (= 2 (length logged)))
          (should (= 1 notified)))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/announce-failure-respects-disables ()
  "Both syslog and notify are gated by their respective defcustom flags."
  (let* ((logged 0) (notified 0)
         (root (make-temp-file "satan-runs-announce2-" t))
         (dl-satan-runs-dir root)
         (dl-satan-failure-syslog nil)
         (dl-satan-failure-notify nil))
    (unwind-protect
        (cl-letf
            (((symbol-function 'call-process)
              (lambda (&rest _args) (cl-incf logged) 0))
             ((symbol-function 'notifications-notify)
              (lambda (&rest _args) (cl-incf notified) 42)))
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T100000-tick-pulse-aaaaaa.FAILED" root) t)
          (dl-satan-broker--announce-failure
           "20260520T100000-tick-pulse-aaaaaa" "tick-pulse"
           'failed "child-exit-1")
          (should (= 0 logged))
          (should (= 0 notified)))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/locate-run-dir-finds-failed-and-buckets ()
  "Locator falls back through bucketed, bucketed-FAILED, legacy, legacy-FAILED."
  (let ((root (make-temp-file "satan-runs-locate-" t)))
    (unwind-protect
        (progn
          (let ((d (expand-file-name "2026-05-20/20260520T100000-x-aaaaaa"
                                     root)))
            (make-directory d t)
            (should (equal (dl-satan-broker-locate-run-dir
                            "20260520T100000-x-aaaaaa" root)
                           d)))
          (let ((d (expand-file-name
                    "2026-05-20/20260520T110000-x-bbbbbb.FAILED" root)))
            (make-directory d t)
            (should (equal (dl-satan-broker-locate-run-dir
                            "20260520T110000-x-bbbbbb" root)
                           d)))
          (let ((d (expand-file-name "20260520T120000-x-cccccc" root)))
            (make-directory d t)
            (should (equal (dl-satan-broker-locate-run-dir
                            "20260520T120000-x-cccccc" root)
                           d)))
          (should (null (dl-satan-broker-locate-run-dir
                         "20260520T999999-nope-zzzzzz" root))))
      (delete-directory root t))))

;; ---------- dl-satan-broker--prepare (Phase 0.1) ----------

(ert-deftest dl-satan-broker/prepare-plist-shape ()
  "prepare returns a run_ctx plist with frozen run_id + time_now and v0 placeholders."
  (let* ((mode '(:name "tick-pulse"))
         (run-ctx (dl-satan-broker--prepare mode)))
    (should (stringp (plist-get run-ctx :run_id)))
    (should (string-prefix-p (format-time-string "%Y%m%dT")
                             (plist-get run-ctx :run_id)))
    (should (stringp (plist-get run-ctx :time_now)))
    (should (string-match-p
             "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}"
             (plist-get run-ctx :time_now)))
    (dolist (k '(:evidence :percept :sensor_status :pre_spawn :motive))
      (should (plist-member run-ctx k))
      (should (null (plist-get run-ctx k))))))

(ert-deftest dl-satan-broker/prepare-mints-distinct-run-ids ()
  "Two calls to prepare allocate different run_ids."
  (let* ((mode '(:name "x"))
         (a (dl-satan-broker--prepare mode))
         (b (dl-satan-broker--prepare mode)))
    (should-not (equal (plist-get a :run_id) (plist-get b :run_id)))))

(ert-deftest dl-satan-broker/prepare-freezes-time-now-once ()
  "time_now is computed exactly once at prepare; identical across reads."
  (let* ((mode '(:name "tick-pulse"))
         (run-ctx (dl-satan-broker--prepare mode))
         (frozen (plist-get run-ctx :time_now)))
    (sleep-for 0.05)
    (should (equal frozen (plist-get run-ctx :time_now)))))

;; ---------- dl-satan-broker manifest assembly ----------

(defun dl-satan-broker-test--with-tool-descriptions (alist body-fn)
  "Run BODY-FN with `dl-satan-tools-descriptions-dir' bound to a tmp dir
populated from ALIST `((NAME . CONTENT) …)'."
  (let ((tmp (make-temp-file "satan-tools-" t)))
    (unwind-protect
        (let ((dl-satan-tools-descriptions-dir tmp))
          (dolist (pair alist)
            (with-temp-file (expand-file-name (concat (car pair) ".md") tmp)
              (insert (cdr pair))))
          (funcall body-fn))
      (delete-directory tmp t))))

(ert-deftest dl-satan-broker/manifest-tools-shape ()
  "Manifest carries one JSON Schema per allowed tool plus satan_final."
  (dl-satan-broker-test--with-tool-descriptions
   '(("org_read_context"      . "Read a slice of the notes corpus.")
     ("org_update_owned_block" . "Replace a SATAN-owned org block.")
     ("proposal_stage"         . "Stage a proposal.")
     ("notify_send"            . "Send a desktop notification.")
     ("hippocampus_list"       . "List hippocampus entries.")
     ("hippocampus_read"       . "Read a hippocampus entry.")
     ("hippocampus_write"      . "Write to the hippocampus.")
     ("hippocampus_overwrite"  . "Overwrite a hippocampus entry.")
     ("hippocampus_delete"     . "Delete a hippocampus entry.")
     ("hippocampus_grep"       . "Search hippocampus entries.")
     ("hippocampus_rename"     . "Rename a hippocampus entry.")
     ("inbox_append"           . "Append to the inbox.")
     ("agenda_read"            . "Read the agenda.")
     ("activity_read"          . "Read the user's recent activity.")
     ("notes_recent"           . "List recently changed notes files.")
     ("notes_at_satan_scan"    . "Scan @satan directives.")
     ("sway_border_set"        . "Retint sway window borders.")
     ("sway_border_reset"      . "Restore sway borders.")
     ("bough_read"             . "Read from bough.")
     ("memory_mark"            . "Mark a memory trace.")
     ("memory_resonate"        . "Resonate against handles.")
     ("memory_show_trace"      . "Show a memory trace.")
     ("docs_list"              . "List doc chunks.")
     ("docs_search"            . "Filter doc chunks.")
     ("docs_read"              . "Read a doc chunk.")
     ("motive_read"            . "Read motive entries.")
     ("motive_replace"         . "Replace a motive entry.")
     ("satan_final"            . "Terminate the run."))
   (lambda ()
     (let* ((mode (dl-satan-mode-resolve "morning"))
            (manifest (dl-satan-broker--build-manifest mode "test-run"))
            (tools (append (plist-get manifest :tools) nil))
            (names (mapcar (lambda (t-) (plist-get (plist-get t- :function) :name))
                           tools)))
       (should (equal (plist-get manifest :run_id) "test-run"))
       (should (member "org_read_context" names))
       (should (member "org_update_owned_block" names))
       (should (member "notify_send" names))
       (should (member "hippocampus_write" names))
       (should (member "inbox_append" names))
       (should (member "agenda_read" names))
       (should (member "activity_read" names))
       (should (member "notes_recent" names))
       (should (member "satan_final" names))
       ;; Descriptions came from notes files, not elisp.
       (let ((notify (cl-find "notify_send" tools
                              :key (lambda (t-)
                                     (plist-get (plist-get t- :function) :name))
                              :test #'equal)))
         (should (string-match-p
                  "Send a desktop notification"
                  (plist-get (plist-get notify :function) :description))))))))

;; ---------- budget gating (cross-cutter: assertion subject = broker) ----------

(defun dl-satan-broker-test--write-transcript (dir lines)
  "Write LINES (each a plist) as transcript.jsonl under DIR."
  (make-directory dir t)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file (expand-file-name "transcript.jsonl" dir)
      (dolist (l lines)
        (insert (json-serialize
                 (dl-satan-jsonl-prepare l)
                 :null-object :null :false-object :false))
        (insert "\n")))))

(defun dl-satan-broker-test--usage-record (tokens-total)
  (list :ts "2026-05-19T09:00:00.000000+1000"
        :dir "in" :event "log"
        :payload (list :type "log" :kind "usage"
                       :tokens_in 0 :tokens_out 0
                       :tokens_total tokens-total)))

(ert-deftest dl-satan-broker/refuses-spawn-when-budget-exceeded ()
  "Pre-spawn gate writes status=budget-exceeded; no child spawned.
Secondary subject: dl-satan-budget (gating policy)."
  (dl-satan-broker-test--with-tool-descriptions
   '(("org_read_context"       . "Read.")
     ("org_update_owned_block" . "Write owned.")
     ("proposal_stage"         . "Stage.")
     ("notify_send"            . "Notify.")
     ("hippocampus_list"       . "List hippo.")
     ("hippocampus_read"       . "Read hippo.")
     ("hippocampus_write"      . "Write hippo.")
     ("hippocampus_overwrite"  . "Overwrite hippo.")
     ("hippocampus_delete"     . "Delete hippo.")
     ("hippocampus_grep"       . "Search hippo.")
     ("hippocampus_rename"     . "Rename hippo.")
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
             (dl-satan-broker-test--write-transcript
              existing (list (dl-satan-broker-test--usage-record 500000)))
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

;; ---------- pre_spawn threading (Phase 4.4) ----------

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

;; ---------- crash-context event (resilience PR 2) ----------

(ert-deftest dl-satan-broker/crash-context-emitted-on-failed ()
  "Finalize emits a `crash-context' audit record on non-done terminal paths."
  (let ((dir (make-temp-file "satan-broker-crash-ctx-" t)))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-24T10:00:00+1000"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil :pre_spawn nil))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 1800
                       :budget-tool-calls 100 :budget-tokens 300000
                       :capabilities ()))
               (run-ctx (make-dl-satan-run
                         :id "rid"
                         :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir
                         :status 'failed
                         :tool-calls-done 3
                         :audit audit
                         :prepare prepare)))
          (cl-letf (((symbol-function 'dl-satan-broker--mark-failed-on-disk)
                     (lambda (&rest _) nil)))
            (dl-satan-broker--finalize run-ctx))
          (let* ((records (dl-satan-audit--read-jsonl
                           (expand-file-name "transcript.jsonl" dir)))
                 (crash-ctx (cl-find-if
                             (lambda (r)
                               (and (equal (plist-get r :dir) "broker")
                                    (equal (plist-get r :event) "crash-context")))
                             records)))
            (should crash-ctx)
            (let ((p (plist-get crash-ctx :payload)))
              (should (equal (plist-get p :status) "failed"))
              (should (equal (plist-get p :tool_calls_done) 3))
              (should (equal (plist-get p :tool_calls_budget) 100))
              (should (equal (plist-get p :budget_tokens) 300000))
              (should (equal (plist-get p :timeout_seconds) 1800))
              (should (integerp (plist-get p :elapsed_seconds)))
              (should (equal (plist-get p :pre_spawn_completed) t)))))
      (delete-directory dir t))))

(ert-deftest dl-satan-broker/crash-context-not-emitted-on-done ()
  "Successful runs must NOT emit a crash-context record."
  (let ((dir (make-temp-file "satan-broker-crash-ctx-done-" t)))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-24T10:00:00+1000"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil :pre_spawn nil))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 1800
                       :budget-tool-calls 100 :budget-tokens 300000
                       :capabilities ()))
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
          (let* ((records (dl-satan-audit--read-jsonl
                           (expand-file-name "transcript.jsonl" dir)))
                 (crash-ctx (cl-find-if
                             (lambda (r)
                               (and (equal (plist-get r :dir) "broker")
                                    (equal (plist-get r :event) "crash-context")))
                             records)))
            (should-not crash-ctx)))
      (delete-directory dir t))))

(ert-deftest dl-satan-broker/crash-context-emitted-on-timed-out ()
  "Timeout paths also emit crash-context."
  (let ((dir (make-temp-file "satan-broker-crash-ctx-timeout-" t)))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-24T10:00:00+1000"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil :pre_spawn nil))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 1800
                       :budget-tool-calls 100 :budget-tokens 300000
                       :capabilities ()))
               (run-ctx (make-dl-satan-run
                         :id "rid"
                         :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir
                         :status 'timed-out
                         :tool-calls-done 7
                         :audit audit
                         :prepare prepare)))
          (cl-letf (((symbol-function 'dl-satan-broker--mark-failed-on-disk)
                     (lambda (&rest _) nil)))
            (dl-satan-broker--finalize run-ctx))
          (let* ((records (dl-satan-audit--read-jsonl
                           (expand-file-name "transcript.jsonl" dir)))
                 (crash-ctx (cl-find-if
                             (lambda (r)
                               (and (equal (plist-get r :dir) "broker")
                                    (equal (plist-get r :event) "crash-context")))
                             records)))
            (should crash-ctx)
            (let ((p (plist-get crash-ctx :payload)))
              (should (equal (plist-get p :status) "timed-out"))
              (should (equal (plist-get p :tool_calls_done) 7)))))
      (delete-directory dir t))))

(provide 'dl-satan-broker-test)
;;; dl-satan-broker-test.el ends here
