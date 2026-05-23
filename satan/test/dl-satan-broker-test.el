;;; dl-satan-broker-test.el --- ert tests for dl-satan-broker -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/lisp -L ~/.emacs.d/org \
;;     -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-broker-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-jsonl)
(require 'dl-satan-audit)
(require 'dl-satan-broker)
(require 'dl-satan-tools-notify)
(require 'cl-macs)                       ; cl-letf used in tool-ctx tests

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

(provide 'dl-satan-broker-test)
;;; dl-satan-broker-test.el ends here
