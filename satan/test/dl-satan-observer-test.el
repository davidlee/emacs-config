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

;; ---------------------------------------------------------------------
;; Phase 5.4a — baseline + after-state helpers
;; ---------------------------------------------------------------------

(defun dl-satan-observer-test--write-bundle (dir bundle)
  "Write BUNDLE (plist) as `bundle.json' under DIR."
  (make-directory dir t)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file (expand-file-name "bundle.json" dir)
      (insert (json-serialize (dl-satan-jsonl-prepare bundle)
                              :null-object :null
                              :false-object :false)))))

(ert-deftest dl-satan-observer/baseline-read-returns-evidence-window ()
  "5.4a — `--baseline-read' yields the persisted `:evidence_window'
from `bundle.json' → `:percept' → `:evidence_window'."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (expand-file-name "20260522T100000-tick-aaa" root))
            (ev (list :git_state (list :head_short "deadbeef" :dirty :false)
                      :fs_state (list :cwd "/tmp" :recent_files nil)
                      :window_start_at "2026-05-22T10:00:00+1000"
                      :window_end_at "2026-05-22T10:10:00+1000")))
       (dl-satan-observer-test--write-bundle
        dir (list :percept (list :evidence_window ev)))
       (let ((out (dl-satan-observer--baseline-read dir)))
         (should (equal "deadbeef" (plist-get (plist-get out :git_state)
                                              :head_short))))))))

(ert-deftest dl-satan-observer/baseline-read-missing-returns-nil ()
  "5.4a — runs without `bundle.json' (budget-denied / pre_spawn-denied)
yield nil; classifier converts that to `:reason :no_baseline'."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let ((dir (expand-file-name "20260522T100000-tick-bbb" root)))
       (make-directory dir t)
       (should (null (dl-satan-observer--baseline-read dir)))))))

(ert-deftest dl-satan-observer/baseline-read-malformed-returns-nil ()
  "5.4a — corrupt `bundle.json' yields nil rather than signalling.
Classifier treats it the same as missing baseline."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let ((dir (expand-file-name "20260522T100000-tick-ccc" root)))
       (make-directory dir t)
       (with-temp-file (expand-file-name "bundle.json" dir)
         (insert "{not valid json"))
       (should (null (dl-satan-observer--baseline-read dir)))))))

(ert-deftest dl-satan-observer/baseline-read-no-percept-returns-nil ()
  "5.4a — `bundle.json' present but missing `:percept' slot yields nil.
Defensive — older runs from before phase 1 lacked the slot."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let ((dir (expand-file-name "20260522T100000-tick-ddd" root)))
       (dl-satan-observer-test--write-bundle
        dir (list :run_id "x" :time_now "2026-05-22T10:00:00+1000"))
       (should (null (dl-satan-observer--baseline-read dir)))))))

(ert-deftest dl-satan-observer/window-end-iso-adds-mature-seconds ()
  "5.4a — `--window-end-iso' adds `window-mature-seconds' to the
intervention timestamp, returning an ISO string in the same zone."
  (let* ((dl-satan-observer-window-mature-seconds 1800)
         (iv (list :intervention_emitted_at "2026-05-22T10:00:00+1000"))
         (end (dl-satan-observer--window-end-iso iv)))
    (should (equal (substring end 0 19) "2026-05-22T10:30:00"))))

(ert-deftest dl-satan-observer/window-crosses-midnight-p-same-day ()
  "5.4a — a 30-min window starting at 10:00 stays within one day."
  (let ((iv (list :intervention_emitted_at "2026-05-22T10:00:00+1000")))
    (should-not (dl-satan-observer--window-crosses-midnight-p iv))))

(ert-deftest dl-satan-observer/window-crosses-midnight-p-rolls-over ()
  "5.4a — a 30-min window starting at 23:50 crosses to the next day;
classifier yields `:reason :crosses_midnight' rather than reading
tomorrow's panopticon segment file."
  (let ((iv (list :intervention_emitted_at "2026-05-22T23:50:00+1000")))
    (should (dl-satan-observer--window-crosses-midnight-p iv))))

;; ---------------------------------------------------------------------
;; Phase 5.4b — positive predicate primitives (§S5 P1–P4)
;; ---------------------------------------------------------------------

(defconst dl-satan-observer-test--cwd "/tmp/satan-obs-proj")
(defconst dl-satan-observer-test--emitted "2026-05-22T10:00:00+1000")

(defun dl-satan-observer-test--motive (&rest overrides)
  "Build a motive plist with sensible defaults; OVERRIDES merge on top."
  (let ((base (list :project_cwd dl-satan-observer-test--cwd
                    :cue (list "project:satan-obs-proj"))))
    (while overrides
      (setq base (plist-put base (pop overrides) (pop overrides))))
    base))

(defun dl-satan-observer-test--intervention ()
  (list :run_id "20260522T100000-tick-aaa"
        :applied_index 0
        :intervention_emitted_at dl-satan-observer-test--emitted))

;; --- P1 editor edit in window -----------------------------------------

(ert-deftest dl-satan-observer/p1-editor-edit-fires ()
  "P1 fires on an emacs segment starting after intervention with a
last_title that resolves under `:project_cwd'."
  (let* ((motive (dl-satan-observer-test--motive))
         (iv (dl-satan-observer-test--intervention))
         (after (list :focus_segments
                      (list (list :app_id "emacs"
                                  :start_ts "2026-05-22T10:05:00+1000"
                                  :end_ts "2026-05-22T10:08:00+1000"
                                  :last_title
                                  (concat dl-satan-observer-test--cwd
                                          "/foo.el - GNU Emacs at Sleipnir"))))))
    (should (dl-satan-observer--predicate-editor-edit-in-window
             nil after motive iv))))

(ert-deftest dl-satan-observer/p1-coincidence-outside-cwd-does-not-fire ()
  "A12 — emacs segment whose title resolves to a path NOT under
`:project_cwd' must not fire P1.  Load-bearing for the no-coincidence
invariant."
  (let* ((motive (dl-satan-observer-test--motive))
         (iv (dl-satan-observer-test--intervention))
         (after (list :focus_segments
                      (list (list :app_id "emacs"
                                  :start_ts "2026-05-22T10:05:00+1000"
                                  :last_title
                                  "/other/repo/bar.el - GNU Emacs at Sleipnir")))))
    (should-not (dl-satan-observer--predicate-editor-edit-in-window
                 nil after motive iv))))

(ert-deftest dl-satan-observer/p1-segment-starting-at-or-before-emitted-does-not-fire ()
  "P1 requires `start_ts' strictly after `:intervention_emitted_at'.
A segment opened at the same moment was already in progress; it
isn't evidence of a post-intervention edit."
  (let* ((motive (dl-satan-observer-test--motive))
         (iv (dl-satan-observer-test--intervention))
         (after (list :focus_segments
                      (list (list :app_id "emacs"
                                  :start_ts dl-satan-observer-test--emitted
                                  :last_title
                                  (concat dl-satan-observer-test--cwd
                                          "/foo.el - GNU Emacs at Sleipnir"))))))
    (should-not (dl-satan-observer--predicate-editor-edit-in-window
                 nil after motive iv))))

(ert-deftest dl-satan-observer/p1-non-editor-app-does-not-fire ()
  "A firefox segment with a URL-shaped title under `:project_cwd' (as
if the user navigated to a local file://) doesn't fire P1 — surface
must be editor."
  (let* ((motive (dl-satan-observer-test--motive))
         (iv (dl-satan-observer-test--intervention))
         (after (list :focus_segments
                      (list (list :app_id "firefox"
                                  :start_ts "2026-05-22T10:05:00+1000"
                                  :last_title
                                  (concat dl-satan-observer-test--cwd
                                          "/foo.el - GNU Emacs at Sleipnir"))))))
    (should-not (dl-satan-observer--predicate-editor-edit-in-window
                 nil after motive iv))))

(ert-deftest dl-satan-observer/p1-missing-last-title-skips ()
  "Segments from panopticon before phase 5.4-pan lack `:last_title';
P1 must skip them silently."
  (let* ((motive (dl-satan-observer-test--motive))
         (iv (dl-satan-observer-test--intervention))
         (after (list :focus_segments
                      (list (list :app_id "emacs"
                                  :start_ts "2026-05-22T10:05:00+1000")))))
    (should-not (dl-satan-observer--predicate-editor-edit-in-window
                 nil after motive iv))))

(ert-deftest dl-satan-observer/p1-no-project-cwd-skips ()
  "Motive without `:project_cwd' — P1 silently no-ops."
  (let* ((motive (dl-satan-observer-test--motive :project_cwd nil))
         (iv (dl-satan-observer-test--intervention))
         (after (list :focus_segments
                      (list (list :app_id "emacs"
                                  :start_ts "2026-05-22T10:05:00+1000"
                                  :last_title
                                  "/anywhere/foo.el - GNU Emacs at Sleipnir")))))
    (should-not (dl-satan-observer--predicate-editor-edit-in-window
                 nil after motive iv))))

;; --- P2 git HEAD changed ----------------------------------------------

(ert-deftest dl-satan-observer/p2-git-head-changed-fires ()
  (let ((baseline (list :git_state (list :head_short "aaaaaaa"
                                         :remote "github.com/u/r")))
        (after (list :git_state (list :head_short "bbbbbbb"
                                      :remote "github.com/u/r"))))
    (should (dl-satan-observer--predicate-git-head-changed
             baseline after nil nil))))

(ert-deftest dl-satan-observer/p2-git-head-stable-does-not-fire ()
  (let ((baseline (list :git_state (list :head_short "aaaaaaa"
                                         :remote "github.com/u/r")))
        (after (list :git_state (list :head_short "aaaaaaa"
                                      :remote "github.com/u/r"))))
    (should-not (dl-satan-observer--predicate-git-head-changed
                 baseline after nil nil))))

(ert-deftest dl-satan-observer/p2-different-remotes-do-not-fire ()
  "A12 corollary — baseline and after probed different repos.
Their head_shorts being different is not evidence of a commit."
  (let ((baseline (list :git_state (list :head_short "aaaaaaa"
                                         :remote "github.com/u/r1")))
        (after (list :git_state (list :head_short "bbbbbbb"
                                      :remote "github.com/u/r2"))))
    (should-not (dl-satan-observer--predicate-git-head-changed
                 baseline after nil nil))))

(ert-deftest dl-satan-observer/p2-missing-head-on-either-side-skips ()
  "Non-repo probes return nil head; P2 must skip rather than fire."
  (let ((baseline (list :git_state (list :head_short nil :remote nil)))
        (after (list :git_state (list :head_short "bbbbbbb" :remote nil))))
    (should-not (dl-satan-observer--predicate-git-head-changed
                 baseline after nil nil))))

;; --- P3 recent_files delta --------------------------------------------

(ert-deftest dl-satan-observer/p3-recent-files-delta-fires ()
  "A file under `:project_cwd' present in AFTER's recent_files and
absent from BASELINE's recent_files satisfies P3."
  (let* ((motive (dl-satan-observer-test--motive))
         (baseline (list :fs_state
                         (list :cwd dl-satan-observer-test--cwd
                               :recent_files (list "old.el"))))
         (after (list :fs_state
                      (list :cwd dl-satan-observer-test--cwd
                            :recent_files (list "old.el" "new.el")))))
    (should (dl-satan-observer--predicate-fs-recent-delta
             baseline after motive nil))))

(ert-deftest dl-satan-observer/p3-coincidence-outside-cwd-does-not-fire ()
  "A12 — a new recent_files entry on a path NOT under `:project_cwd'
must not fire P3.  Set diff is path-prefix-filtered."
  (let* ((motive (dl-satan-observer-test--motive))
         ;; BASELINE assembled with a different cwd (e.g. an unrelated
         ;; repo); AFTER assembled with motive's :project_cwd.  The
         ;; delta exists but on /other/repo, not /tmp/satan-obs-proj.
         (baseline (list :fs_state
                         (list :cwd "/other/repo" :recent_files nil)))
         (after (list :fs_state
                      (list :cwd "/other/repo"
                            :recent_files (list "noise.el")))))
    (should-not (dl-satan-observer--predicate-fs-recent-delta
                 baseline after motive nil))))

(ert-deftest dl-satan-observer/p3-no-project-cwd-skips ()
  (let* ((motive (dl-satan-observer-test--motive :project_cwd nil))
         (baseline (list :fs_state (list :cwd "/x" :recent_files nil)))
         (after (list :fs_state (list :cwd "/x" :recent_files (list "a.el")))))
    (should-not (dl-satan-observer--predicate-fs-recent-delta
                 baseline after motive nil))))

(ert-deftest dl-satan-observer/p3-handles-different-cwds-by-absolute-path ()
  "BASELINE may have been assembled with a different cwd than the
motive's; P3 compares absolute paths, not relative ones."
  (let* ((motive (dl-satan-observer-test--motive))
         (baseline (list :fs_state
                         (list :cwd "/other/repo"
                               ;; Same absolute path as AFTER's new entry —
                               ;; should suppress the fire.
                               :recent_files
                               (list "../../tmp/satan-obs-proj/foo.el"))))
         (after (list :fs_state
                      (list :cwd dl-satan-observer-test--cwd
                            :recent_files (list "foo.el")))))
    (should-not (dl-satan-observer--predicate-fs-recent-delta
                 baseline after motive nil))))

;; --- P4 bough event match ---------------------------------------------

(ert-deftest dl-satan-observer/p4-bough-node-match-fires ()
  (let* ((motive (dl-satan-observer-test--motive
                  :cue (list "bough_node:nano123" "project:foo")))
         (after (list :bough_recent
                      (list (list :event "status_changed"
                                  :nanoid "nano123" :from "todo" :to "done")))))
    (should (dl-satan-observer--predicate-bough-event-match
             nil after motive nil))))

(ert-deftest dl-satan-observer/p4-bough-project-match-fires ()
  (let* ((motive (dl-satan-observer-test--motive
                  :cue (list "bough_project:proj456")))
         (after (list :bough_recent
                      (list (list :event "status_changed"
                                  :nanoid "proj456")))))
    (should (dl-satan-observer--predicate-bough-event-match
             nil after motive nil))))

(ert-deftest dl-satan-observer/p4-noise-event-does-not-fire ()
  "An unrelated bough event must not fire when none of the nanoids
match a `bough_node:'/`bough_project:' handle in the cue."
  (let* ((motive (dl-satan-observer-test--motive
                  :cue (list "bough_node:nano123")))
         (after (list :bough_recent
                      (list (list :event "status_changed"
                                  :nanoid "different")))))
    (should-not (dl-satan-observer--predicate-bough-event-match
                 nil after motive nil))))

(ert-deftest dl-satan-observer/p4-no-bough-handles-skips ()
  "Motive whose cue carries no bough_node:/bough_project: handle is
not eligible for P4 — even with bough events in the window."
  (let* ((motive (dl-satan-observer-test--motive
                  :cue (list "project:foo")))
         (after (list :bough_recent
                      (list (list :event "status_changed"
                                  :nanoid "anything")))))
    (should-not (dl-satan-observer--predicate-bough-event-match
                 nil after motive nil))))

;; ---------------------------------------------------------------------
;; Phase 5.4c — single-motive classifier glue
;; ---------------------------------------------------------------------

(defun dl-satan-observer-test--stub-after-state (after-plist)
  "Return a function that mimics `--after-state' by returning AFTER-PLIST."
  (lambda (&rest _) after-plist))

(defmacro dl-satan-observer-test--with-stubbed-after-state (after &rest body)
  "Run BODY with `--after-state' stubbed to return AFTER (plist)."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'dl-satan-observer--after-state)
              (dl-satan-observer-test--stub-after-state ,after)))
     ,@body))

(ert-deftest dl-satan-observer/classify-dormant-motive-skips ()
  "A14 — dormant motive yields `:reason :motive_dormant' immediately,
without reading baseline or assembling after-state."
  (let* ((motive (dl-satan-observer-test--motive :dormant t))
         (iv (dl-satan-observer-test--intervention))
         (out (dl-satan-observer-classify iv motive)))
    (should (equal "none" (plist-get out :verdict)))
    (should (eq :motive_dormant (plist-get out :reason)))))

(ert-deftest dl-satan-observer/classify-midnight-crossing-skips ()
  "5.4 §S5 watch-out — a window crossing midnight yields
`:reason :crosses_midnight' instead of probing after-state."
  (let* ((motive (dl-satan-observer-test--motive))
         (iv (plist-put (dl-satan-observer-test--intervention)
                        :intervention_emitted_at
                        "2026-05-22T23:50:00+1000"))
         (out (dl-satan-observer-classify iv motive)))
    (should (equal "none" (plist-get out :verdict)))
    (should (eq :crosses_midnight (plist-get out :reason)))))

(ert-deftest dl-satan-observer/classify-no-baseline-yields-reason ()
  "Budget-denied / pre_spawn-denied runs lack `bundle.json'; classifier
yields `:reason :no_baseline' rather than crashing on a nil
baseline."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (expand-file-name "20260522T100000-tick-aaa" root))
            (_ (make-directory dir t))
            (motive (dl-satan-observer-test--motive))
            (iv (plist-put (dl-satan-observer-test--intervention)
                           :run_dir dir))
            (out (dl-satan-observer-classify iv motive)))
       (should (equal "none" (plist-get out :verdict)))
       (should (eq :no_baseline (plist-get out :reason)))))))

(ert-deftest dl-satan-observer/classify-positive-via-git-head ()
  "P2 fires end-to-end — baseline `bundle.json' carries head_short
`aaaaaaa', stubbed after-state reports `bbbbbbb' with matching
remote; classifier returns `:predicate :git_head_changed'."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (expand-file-name "20260522T100000-tick-aaa" root))
            (baseline-ev
             (list :git_state (list :head_short "aaaaaaa"
                                    :remote "github.com/u/r")
                   :fs_state (list :cwd dl-satan-observer-test--cwd
                                   :recent_files nil)
                   :focus_segments nil :bough_recent nil))
            (after-ev
             (list :git_state (list :head_short "bbbbbbb"
                                    :remote "github.com/u/r")
                   :fs_state (list :cwd dl-satan-observer-test--cwd
                                   :recent_files nil)
                   :focus_segments nil :bough_recent nil))
            (motive (dl-satan-observer-test--motive))
            (iv (plist-put (dl-satan-observer-test--intervention)
                           :run_dir dir)))
       (dl-satan-observer-test--write-bundle
        dir (list :percept (list :evidence_window baseline-ev)))
       (dl-satan-observer-test--with-stubbed-after-state after-ev
         (let ((out (dl-satan-observer-classify iv motive)))
           (should (equal "positive" (plist-get out :verdict)))
           (should (eq :git_head_changed (plist-get out :predicate)))))))))

(ert-deftest dl-satan-observer/classify-no-fire-returns-none-no-reason ()
  "All four predicates inert — verdict `none' with no `:reason' slot.
`:reason' is reserved for guard-triggered short-circuits, not for
predicates simply not finding signal."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (expand-file-name "20260522T100000-tick-aaa" root))
            (stable (list :git_state (list :head_short "aaaaaaa"
                                           :remote "github.com/u/r")
                          :fs_state (list :cwd dl-satan-observer-test--cwd
                                          :recent_files nil)
                          :focus_segments nil :bough_recent nil))
            (motive (dl-satan-observer-test--motive))
            (iv (plist-put (dl-satan-observer-test--intervention)
                           :run_dir dir)))
       (dl-satan-observer-test--write-bundle
        dir (list :percept (list :evidence_window stable)))
       (dl-satan-observer-test--with-stubbed-after-state stable
         (let ((out (dl-satan-observer-classify iv motive)))
           (should (equal "none" (plist-get out :verdict)))
           (should (null (plist-get out :predicate)))
           (should (null (plist-get out :reason)))))))))

(ert-deftest dl-satan-observer/classify-a12-fs-coincidence-does-not-fire ()
  "A12 end-to-end — an emacs recentf entry outside `:project_cwd'
appears in AFTER but not BASELINE.  P3 must filter it out by
cwd-prefix; classifier returns `none', not `positive'."
  (dl-satan-observer-test--in-tmp
   (lambda (root)
     (let* ((dir (expand-file-name "20260522T100000-tick-aaa" root))
            (baseline-ev
             (list :git_state (list :head_short "aaaaaaa" :remote "r")
                   :fs_state (list :cwd "/other/repo" :recent_files nil)
                   :focus_segments nil :bough_recent nil))
            (after-ev
             (list :git_state (list :head_short "aaaaaaa" :remote "r")
                   :fs_state (list :cwd "/other/repo"
                                   ;; New entry — but NOT under motive's
                                   ;; :project_cwd, so P3 must skip it.
                                   :recent_files (list "noise.el"))
                   :focus_segments nil :bough_recent nil))
            (motive (dl-satan-observer-test--motive))
            (iv (plist-put (dl-satan-observer-test--intervention)
                           :run_dir dir)))
       (dl-satan-observer-test--write-bundle
        dir (list :percept (list :evidence_window baseline-ev)))
       (dl-satan-observer-test--with-stubbed-after-state after-ev
         (let ((out (dl-satan-observer-classify iv motive)))
           (should (equal "none" (plist-get out :verdict)))))))))

(provide 'dl-satan-observer-test)
;;; dl-satan-observer-test.el ends here
