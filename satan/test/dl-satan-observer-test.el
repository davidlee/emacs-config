;;; dl-satan-observer-test.el --- Phase 5.2 observer skeleton ert -*- lexical-binding: t; -*-

;; Covers `dl-satan-observer-scan-prior-interventions' and its
;; helpers.  Window-mature gate / dedup / predicate / writer are
;; tested in subsequent phase test files.

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-jsonl)
(require 'dl-satan-observer)

;; ---------------------------------------------------------------------
;; Fixture helpers
;; ---------------------------------------------------------------------

(defun dl-satan-observer-test--date-bucket (run-id)
  "Return the YYYY-MM-DD bucket dir name for RUN-ID."
  (when (string-match "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T"
                      run-id)
    (format "%s-%s-%s"
            (match-string 1 run-id)
            (match-string 2 run-id)
            (match-string 3 run-id))))

(defun dl-satan-observer-test--write-jsonl (path records)
  "Write RECORDS (list of plists) as JSONL lines to PATH."
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file path
      (dolist (rec records)
        (insert (json-serialize (dl-satan-jsonl-prepare rec)
                                :null-object :null
                                :false-object :false)
                "\n")))))

(defun dl-satan-observer-test--make-run (runs-root run-id records)
  "Materialise a minimal run dir under RUNS-ROOT for RUN-ID.
RECORDS is the list of transcript plists to write.  Returns the
absolute run dir path."
  (let* ((bucket (dl-satan-observer-test--date-bucket run-id))
         (dir (expand-file-name (concat bucket "/" run-id) runs-root)))
    (make-directory dir t)
    (dl-satan-observer-test--write-jsonl
     (expand-file-name "transcript.jsonl" dir)
     records)
    dir))

(defun dl-satan-observer-test--applied-record (ts type &optional args)
  "Build a transcript `action-applied' record."
  (list :ts ts :dir "broker" :event "action-applied"
        :payload (list :type type :args (or args '()))))

(defun dl-satan-observer-test--in-tmp (body-fn)
  "Run BODY-FN with a temporary runs root path, cleaning up after."
  (let ((root (make-temp-file "satan-observer-runs-" t)))
    (unwind-protect (funcall body-fn root)
      (delete-directory root t))))

;; ---------------------------------------------------------------------
;; Per-run transcript walk
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-observer/extracts-applied-intervention ()
  "An `action-applied' record for an intervention tool produces one
intervention entry with the broker-side `:ts' as
`:intervention_emitted_at' and `:applied_index' 0."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((run-id "20260522T100000-tick-aaa")
            (dir (dl-satan-observer-test--make-run
                  root run-id
                  (list
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:01.123456+1000"
                    "notify_send"
                    '(:title "x" :body "y")))))
            (out (dl-satan-observer--applied-interventions-in-run dir)))
       (should (= 1 (length out)))
       (let ((e (car out)))
         (should (equal run-id (plist-get e :run_id)))
         (should (equal dir (plist-get e :run_dir)))
         (should (= 0 (plist-get e :applied_index)))
         (should (equal "notify_send" (plist-get e :tool_name)))
         (should (equal "2026-05-22T10:00:01.123456+1000"
                        (plist-get e :intervention_emitted_at))))))))

(ert-deftest dl-satan-observer/skips-non-intervention-tools ()
  "Tools outside `dl-satan-observer-intervention-tools' yield no
intervention entries (reads should never count)."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (dl-satan-observer-test--make-run
                  root "20260522T100000-tick-bbb"
                  (list
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:01.000000+1000"
                    "bough_read"
                    '(:scope "day"))
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:02.000000+1000"
                    "memory_resonate"
                    '(:cue ("app:firefox"))))))
            (out (dl-satan-observer--applied-interventions-in-run dir)))
       (should (null out))))))

(ert-deftest dl-satan-observer/applied-index-counts-unfiltered-position ()
  "`:applied_index' is the position of the action in the unfiltered
applied sequence — tuning the intervention-tool defcustom must not
re-number an existing intervention's key."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (dl-satan-observer-test--make-run
                  root "20260522T100000-tick-ccc"
                  (list
                   ;; index 0: a read (not an intervention)
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:01.000000+1000"
                    "bough_read"
                    '(:scope "day"))
                   ;; index 1: an intervention
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:02.000000+1000"
                    "notify_send"
                    '(:title "x"))
                   ;; index 2: another read
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:03.000000+1000"
                    "memory_show_trace"
                    '(:trace_id "tid"))
                   ;; index 3: another intervention
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:04.000000+1000"
                    "inbox_append"
                    '(:body "z")))))
            (out (dl-satan-observer--applied-interventions-in-run dir)))
       (should (= 2 (length out)))
       (should (= 1 (plist-get (nth 0 out) :applied_index)))
       (should (equal "notify_send" (plist-get (nth 0 out) :tool_name)))
       (should (= 3 (plist-get (nth 1 out) :applied_index)))
       (should (equal "inbox_append" (plist-get (nth 1 out) :tool_name)))))))

(ert-deftest dl-satan-observer/ignores-non-broker-records ()
  "Inbound model tool-calls and other non-broker events are not
`action-applied' records and must not advance `applied_index'."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (dl-satan-observer-test--make-run
                  root "20260522T100000-tick-ddd"
                  (list
                   (list :ts "2026-05-22T10:00:00.000000+1000"
                         :dir "in" :event "tool_call"
                         :payload (list :name "notify_send"))
                   (dl-satan-observer-test--applied-record
                    "2026-05-22T10:00:01.000000+1000"
                    "notify_send"
                    '(:title "x"))
                   (list :ts "2026-05-22T10:00:02.000000+1000"
                         :dir "out" :event "tool_result"
                         :payload (list :status "ok")))))
            (out (dl-satan-observer--applied-interventions-in-run dir)))
       (should (= 1 (length out)))
       (should (= 0 (plist-get (car out) :applied_index)))))))

(ert-deftest dl-satan-observer/handles-missing-transcript ()
  "A run dir without `transcript.jsonl' returns an empty list — no
error.  Broker may have crashed before the first record landed."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((bucket "2026-05-22")
            (dir (expand-file-name
                  (concat bucket "/20260522T100000-tick-eee") root)))
       (make-directory dir t)
       (should (null (dl-satan-observer--applied-interventions-in-run dir)))))))

(ert-deftest dl-satan-observer/strips-failed-suffix-from-run-id ()
  "A `.FAILED' run dir leaf still decodes to the bare run-id stem."
  (let ((dir "/tmp/runs/2026-05-22/20260522T100000-tick-fff.FAILED"))
    (should (equal "20260522T100000-tick-fff"
                   (dl-satan-observer--run-id-from-dir dir)))))

;; ---------------------------------------------------------------------
;; Scan window
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-observer/scan-skips-runs-older-than-window ()
  "Runs whose start time falls outside the configured window are
ignored.  Default window is 24 h; pin it explicitly so the test is
not coupled to the defcustom default."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dl-satan-observer-scan-window-hours 24)
            (old (dl-satan-observer-test--make-run
                  root "20260521T080000-tick-old"
                  (list (dl-satan-observer-test--applied-record
                         "2026-05-21T08:00:01.000000+1000"
                         "notify_send" '(:title "old")))))
            (recent (dl-satan-observer-test--make-run
                     root "20260522T090000-tick-recent"
                     (list (dl-satan-observer-test--applied-record
                            "2026-05-22T09:00:01.000000+1000"
                            "notify_send" '(:title "recent")))))
            (now "2026-05-22T10:00:00+1000")
            (out (dl-satan-observer-scan-prior-interventions now root)))
       (ignore old)
       (should (= 1 (length out)))
       (should (equal "20260522T090000-tick-recent"
                      (plist-get (car out) :run_id)))
       (should (equal recent (plist-get (car out) :run_dir)))))))

(ert-deftest dl-satan-observer/scan-skips-future-runs ()
  "Defensive: a run dated in the future of `now' (clock skew, replay)
is excluded — observer attributes only past interventions."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dl-satan-observer-scan-window-hours 24)
            (future (dl-satan-observer-test--make-run
                     root "20260523T100000-tick-future"
                     (list (dl-satan-observer-test--applied-record
                            "2026-05-23T10:00:01.000000+1000"
                            "notify_send" '(:title "future")))))
            (now "2026-05-22T10:00:00+1000")
            (out (dl-satan-observer-scan-prior-interventions now root)))
       (ignore future)
       (should (null out))))))

(ert-deftest dl-satan-observer/scan-walks-multiple-date-buckets ()
  "Two runs in distinct date buckets, both within the window, are
both returned (broker's `list-run-dirs' walks every bucket)."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dl-satan-observer-scan-window-hours 24)
            (_ (dl-satan-observer-test--make-run
                root "20260521T230000-tick-yday"
                (list (dl-satan-observer-test--applied-record
                       "2026-05-21T23:00:01.000000+1000"
                       "notify_send" '(:title "yday")))))
            (_ (dl-satan-observer-test--make-run
                root "20260522T060000-tick-today"
                (list (dl-satan-observer-test--applied-record
                       "2026-05-22T06:00:01.000000+1000"
                       "inbox_append" '(:body "today")))))
            (now "2026-05-22T10:00:00+1000")
            (out (dl-satan-observer-scan-prior-interventions now root))
            (tools (sort (mapcar (lambda (e) (plist-get e :tool_name)) out)
                         #'string-lessp)))
       (should (= 2 (length out)))
       (should (equal '("inbox_append" "notify_send") tools))))))

(ert-deftest dl-satan-observer/scan-accepts-time-value-for-now ()
  "`now' may be passed as a parsed emacs time value (avoids redundant
string round-trip when caller already has the broker's frozen
`time_now')."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dl-satan-observer-scan-window-hours 24)
            (_ (dl-satan-observer-test--make-run
                root "20260522T090000-tick-x"
                (list (dl-satan-observer-test--applied-record
                       "2026-05-22T09:00:01.000000+1000"
                       "notify_send" '(:title "x")))))
            (now-t (date-to-time "2026-05-22T10:00:00+1000"))
            (out (dl-satan-observer-scan-prior-interventions now-t root)))
       (should (= 1 (length out)))))))

(ert-deftest dl-satan-observer/scan-defcustom-tool-set-is-applied ()
  "Rebinding `dl-satan-observer-intervention-tools' filters
classification but does NOT change `applied_index'."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dl-satan-observer-scan-window-hours 24)
            (_ (dl-satan-observer-test--make-run
                root "20260522T090000-tick-y"
                (list
                 (dl-satan-observer-test--applied-record
                  "2026-05-22T09:00:01.000000+1000"
                  "notify_send" '(:title "x"))
                 (dl-satan-observer-test--applied-record
                  "2026-05-22T09:00:02.000000+1000"
                  "inbox_append" '(:body "y")))))
            (now "2026-05-22T10:00:00+1000"))
       ;; Default set: both classified.
       (should (= 2 (length
                     (dl-satan-observer-scan-prior-interventions now root))))
       ;; Restricted set: only notify_send; inbox_append's
       ;; applied_index (=1) is unaffected and notify_send keeps =0.
       (let* ((dl-satan-observer-intervention-tools '("notify_send"))
              (out (dl-satan-observer-scan-prior-interventions now root)))
         (should (= 1 (length out)))
         (should (equal "notify_send" (plist-get (car out) :tool_name)))
         (should (= 0 (plist-get (car out) :applied_index))))))))

;; ---------------------------------------------------------------------
;; Phase 5.3 — window-mature gate (A11)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-observer/mature-true-after-30m ()
  (let ((dl-satan-observer-window-mature-seconds 1800)
        (iv (list :intervention_emitted_at "2026-05-22T09:00:00+1000"))
        (now (date-to-time "2026-05-22T09:35:00+1000")))
    (should (dl-satan-observer--mature-p iv now))))

(ert-deftest dl-satan-observer/mature-false-before-30m ()
  (let ((dl-satan-observer-window-mature-seconds 1800)
        (iv (list :intervention_emitted_at "2026-05-22T09:00:00+1000"))
        (now (date-to-time "2026-05-22T09:20:00+1000")))
    (should-not (dl-satan-observer--mature-p iv now))))

(ert-deftest dl-satan-observer/mature-edge-exactly-at-window ()
  "Exactly `emitted + window' is mature (inclusive)."
  (let ((dl-satan-observer-window-mature-seconds 1800)
        (iv (list :intervention_emitted_at "2026-05-22T09:00:00+1000"))
        (now (date-to-time "2026-05-22T09:30:00+1000")))
    (should (dl-satan-observer--mature-p iv now))))

(ert-deftest dl-satan-observer/mature-honours-custom-seconds ()
  (let ((dl-satan-observer-window-mature-seconds 60)
        (iv (list :intervention_emitted_at "2026-05-22T09:00:00+1000"))
        (now (date-to-time "2026-05-22T09:02:00+1000")))
    (should (dl-satan-observer--mature-p iv now))))

(ert-deftest dl-satan-observer/mature-skips-missing-timestamp ()
  "Defensive — an intervention without a parseable timestamp never
matures.  Observer cannot stamp what it cannot read."
  (let ((now (date-to-time "2026-05-22T09:30:00+1000")))
    (should-not (dl-satan-observer--mature-p '() now))
    (should-not (dl-satan-observer--mature-p
                 (list :intervention_emitted_at "garbage") now))))

;; ---------------------------------------------------------------------
;; Phase 5.3 — state I/O
;; ---------------------------------------------------------------------

(defmacro dl-satan-observer-test--with-state-path (sym &rest body)
  "Bind SYM to a temp state file path; clean up after BODY."
  (declare (indent 1))
  `(let* ((,sym (make-temp-file "satan-observer-state-" nil ".json"))
          ;; The fixture creates the file but we want the cold-start
          ;; semantics for read-state; delete first.
          (_ (delete-file ,sym)))
     (unwind-protect (progn ,@body)
       (when (file-exists-p ,sym) (delete-file ,sym))
       (when (file-exists-p (concat ,sym ".tmp"))
         (delete-file (concat ,sym ".tmp"))))))

(ert-deftest dl-satan-observer/read-state-missing-file-seeds-empty ()
  (dl-satan-observer-test--with-state-path path
    (should (equal '(:classified nil)
                   (dl-satan-observer--read-state path)))))

(ert-deftest dl-satan-observer/read-state-malformed-json-seeds-empty ()
  "Corrupt state must not block the observer — seed and proceed."
  (dl-satan-observer-test--with-state-path path
    (let ((coding-system-for-write 'utf-8))
      (with-temp-file path (insert "{not valid json")))
    (should (equal '(:classified nil)
                   (dl-satan-observer--read-state path)))))

(ert-deftest dl-satan-observer/write-state-round-trip ()
  (dl-satan-observer-test--with-state-path path
    (let ((state (list :classified
                       (list (list :run_id "20260522T100000-tick-a"
                                   :applied_index 0
                                   :classified_at "2026-05-22T10:30:00+1000"
                                   :verdict "positive")))))
      (dl-satan-observer--write-state path state)
      (should (file-exists-p path))
      (let ((round (dl-satan-observer--read-state path)))
        (should (= 1 (length (plist-get round :classified))))
        (let ((entry (car (plist-get round :classified))))
          (should (equal "20260522T100000-tick-a"
                         (plist-get entry :run_id)))
          (should (= 0 (plist-get entry :applied_index)))
          (should (equal "positive" (plist-get entry :verdict))))))))

(ert-deftest dl-satan-observer/write-state-creates-parent-dir ()
  (let* ((root (make-temp-file "satan-observer-mkdir-" t))
         (path (expand-file-name "deep/nested/observer.json" root)))
    (unwind-protect
        (progn
          (dl-satan-observer--write-state path '(:classified nil))
          (should (file-exists-p path)))
      (delete-directory root t))))

;; ---------------------------------------------------------------------
;; Phase 5.3 — classified-p
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-observer/classified-p-matches-key ()
  (let* ((state (list :classified
                      (list (list :run_id "rA" :applied_index 1
                                  :verdict "positive"))))
         (iv-hit (list :run_id "rA" :applied_index 1))
         (iv-miss-run (list :run_id "rB" :applied_index 1))
         (iv-miss-index (list :run_id "rA" :applied_index 2)))
    (should (dl-satan-observer--classified-p iv-hit state))
    (should-not (dl-satan-observer--classified-p iv-miss-run state))
    (should-not (dl-satan-observer--classified-p iv-miss-index state))))

;; ---------------------------------------------------------------------
;; Phase 5.3 — `dl-satan-observer-pending'
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-observer/pending-excludes-immature ()
  "Mature interventions survive the filter; immature ones don't.
NOW is set so only the first action's 30-min window has elapsed."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (dl-satan-observer-test--with-state-path spath
       (let* ((dl-satan-observer-scan-window-hours 24)
              (dl-satan-observer-window-mature-seconds 1800)
              (_ (dl-satan-observer-test--make-run
                  root "20260522T080000-tick-mature"
                  (list (dl-satan-observer-test--applied-record
                         "2026-05-22T08:00:01.000000+1000"
                         "notify_send" '(:title "old")))))
              (_ (dl-satan-observer-test--make-run
                  root "20260522T094500-tick-young"
                  (list (dl-satan-observer-test--applied-record
                         "2026-05-22T09:45:01.000000+1000"
                         "notify_send" '(:title "young")))))
              (now "2026-05-22T10:00:00+1000")
              (out (dl-satan-observer-pending now root spath)))
         (should (= 1 (length out)))
         (should (equal "20260522T080000-tick-mature"
                        (plist-get (car out) :run_id))))))))

(ert-deftest dl-satan-observer/pending-excludes-already-classified ()
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (dl-satan-observer-test--with-state-path spath
       (let* ((dl-satan-observer-scan-window-hours 24)
              (dl-satan-observer-window-mature-seconds 1800)
              (run-id "20260522T080000-tick-done")
              (_ (dl-satan-observer-test--make-run
                  root run-id
                  (list (dl-satan-observer-test--applied-record
                         "2026-05-22T08:00:01.000000+1000"
                         "notify_send" '(:title "done")))))
              (now "2026-05-22T10:00:00+1000")
              ;; Seed state so the only candidate is already-classified.
              (_ (dl-satan-observer--write-state
                  spath
                  (list :classified
                        (list (list :run_id run-id :applied_index 0
                                    :verdict "positive"
                                    :classified_at "2026-05-22T09:00:00+1000")))))
              (out (dl-satan-observer-pending now root spath)))
         (should (null out)))))))

;; ---------------------------------------------------------------------
;; Phase 5.3 — `dl-satan-observer-mark-classified' (A13 durability)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-observer/mark-classified-persists-entry ()
  (dl-satan-observer-test--with-state-path spath
    (let* ((iv (list :run_id "20260522T080000-tick-x" :applied_index 2))
           (state (dl-satan-observer-mark-classified
                   iv "positive" "2026-05-22T10:30:00+1000" spath))
           (round (dl-satan-observer--read-state spath))
           (entry (car (plist-get round :classified))))
      (should (= 1 (length (plist-get state :classified))))
      (should (equal "20260522T080000-tick-x" (plist-get entry :run_id)))
      (should (= 2 (plist-get entry :applied_index)))
      (should (equal "positive" (plist-get entry :verdict)))
      (should (equal "2026-05-22T10:30:00+1000"
                     (plist-get entry :classified_at))))))

(ert-deftest dl-satan-observer/mark-classified-preserves-prior-entries ()
  (dl-satan-observer-test--with-state-path spath
    (dl-satan-observer-mark-classified
     (list :run_id "rA" :applied_index 0) "positive"
     "2026-05-22T10:00:00+1000" spath)
    (dl-satan-observer-mark-classified
     (list :run_id "rB" :applied_index 5) "none"
     "2026-05-22T10:30:00+1000" spath)
    (let ((entries (plist-get (dl-satan-observer--read-state spath)
                              :classified)))
      (should (= 2 (length entries)))
      (should (equal "rA" (plist-get (nth 0 entries) :run_id)))
      (should (equal "rB" (plist-get (nth 1 entries) :run_id))))))

(ert-deftest dl-satan-observer/mark-classified-idempotent-on-duplicate ()
  "Calling twice for the same key writes once (A13).  The earlier
verdict wins so a same-tick re-classification cannot flip a record."
  (dl-satan-observer-test--with-state-path spath
    (let ((iv (list :run_id "rA" :applied_index 0)))
      (dl-satan-observer-mark-classified
       iv "positive" "2026-05-22T10:00:00+1000" spath)
      (dl-satan-observer-mark-classified
       iv "none" "2026-05-22T10:01:00+1000" spath)
      (let ((entries (plist-get (dl-satan-observer--read-state spath)
                                :classified)))
        (should (= 1 (length entries)))
        (should (equal "positive" (plist-get (car entries) :verdict)))
        (should (equal "2026-05-22T10:00:00+1000"
                       (plist-get (car entries) :classified_at)))))))

(ert-deftest dl-satan-observer/mark-then-pending-skips ()
  "End-to-end A13 — once marked, the same intervention does not
re-appear in `pending' on a fresh scan."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (dl-satan-observer-test--with-state-path spath
       (let* ((dl-satan-observer-scan-window-hours 24)
              (dl-satan-observer-window-mature-seconds 1800)
              (run-id "20260522T080000-tick-loop")
              (_ (dl-satan-observer-test--make-run
                  root run-id
                  (list (dl-satan-observer-test--applied-record
                         "2026-05-22T08:00:01.000000+1000"
                         "notify_send" '(:title "x")))))
              (now "2026-05-22T10:00:00+1000")
              (before (dl-satan-observer-pending now root spath)))
         (should (= 1 (length before)))
         (dl-satan-observer-mark-classified
          (car before) "positive" now spath)
         (let ((after (dl-satan-observer-pending now root spath)))
           (should (null after))))))))

(provide 'dl-satan-observer-test)
;;; dl-satan-observer-test.el ends here
