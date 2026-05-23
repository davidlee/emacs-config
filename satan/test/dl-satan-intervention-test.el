;;; dl-satan-intervention-test.el --- intervention rebuild ert -*- lexical-binding: t; -*-

;; T7 PR 2 — rebuild idempotency against the satan_memory_test DB.
;; Tests skip-unless the test DB is reachable.
;;
;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-intervention-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-audit)
(require 'dl-satan-jsonl)
(require 'dl-satan-memory-migrate)
(require 'dl-satan-intervention)

(defconst dl-satan-intervention-test--db "satan_memory_test")

(defun dl-satan-intervention-test--reachable-p ()
  (pcase (let ((dl-satan-memory-migrate-database
                dl-satan-intervention-test--db))
           (dl-satan-memory-migrate--psql
            dl-satan-intervention-test--db
            (list "-A" "-t" "-c" "SELECT 1")))
    (`(ok . ,_) t)
    (_ nil)))

(defun dl-satan-intervention-test--reset-and-migrate ()
  "Drop everything in the test DB and re-run migrations through 0006."
  (let ((dl-satan-memory-migrate-database dl-satan-intervention-test--db))
    (dl-satan-memory-migrate--psql
     dl-satan-intervention-test--db
     (list "-c"
           (concat
            "DROP TABLE IF EXISTS "
            "satan_intervention_outcomes, satan_interventions, "
            "patch_job_events, patch_jobs, "
            "trace_links, trace_handles, traces, "
            "handle_aliases, handle_weights, grammar_versions, "
            "schema_migrations CASCADE; "
            "DROP FUNCTION IF EXISTS "
            "memory_mark_trace(jsonb), memory_show_trace(text), "
            "memory_resonate(text[], smallint, double precision, integer, text[]), "
            "handle_weight_for(text, smallint) CASCADE;")))
    (dl-satan-memory-migrate-apply)))

(defmacro dl-satan-intervention-test--with-db (&rest body)
  (declare (indent 0))
  `(progn
     (skip-unless (dl-satan-intervention-test--reachable-p))
     (dl-satan-intervention-test--reset-and-migrate)
     (let ((dl-satan-memory-migrate-database dl-satan-intervention-test--db))
       ,@body)))

;; ---------- fixture builders ----------

(defun dl-satan-intervention-test--write-transcript (runs-root run-id records)
  "Create runs-root/<bucket>/<run-id>/transcript.jsonl with RECORDS.
The bucket is parsed from run-id's leading YYYYMMDD."
  (let* ((date (and (string-match "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T"
                                  run-id)
                    (format "%s-%s-%s"
                            (match-string 1 run-id)
                            (match-string 2 run-id)
                            (match-string 3 run-id))))
         (bucket-dir (expand-file-name (or date "_legacy") runs-root))
         (run-dir (expand-file-name run-id bucket-dir))
         (path (expand-file-name "transcript.jsonl" run-dir)))
    (make-directory run-dir t)
    (with-temp-file path
      (dolist (rec records)
        (insert (json-serialize (dl-satan-jsonl-prepare rec)
                                :null-object :null :false-object :false))
        (insert "\n")))
    path))

(defun dl-satan-intervention-test--ev-record (ts event payload)
  "Build a transcript record matching `dl-satan-audit-record' shape."
  (list :ts ts :dir "broker" :event event :payload payload))

(defun dl-satan-intervention-test--created (run-id iv-id &rest overrides)
  (let ((p (list :intervention_id        iv-id
                 :run_id                 run-id
                 :ts                     "2026-05-23T12:00:00+1000"
                 :mode                   "morning"
                 :kind                   "notify"
                 :target_surface         "sway-mainbar"
                 :message                "do the thing"
                 :related_motive_id      "morning.kanban-cleanup"
                 :cue_handles            '("bough_node:abc")
                 :expected_outcome       "user opens kanban.org"
                 :outcome_window_minutes 30
                 :severity               "low")))
    (while overrides
      (setq p (plist-put p (pop overrides) (pop overrides))))
    p))

(defun dl-satan-intervention-test--classified (iv-id &rest overrides)
  (let ((p (list :intervention_id  iv-id
                 :classification   "worked"
                 :confidence       "medium"
                 :evidence         '(:source-events ()
                                     :predicates ("editor_edit_in_window"))
                 :maturity         "mature"
                 :next_revisit_at  "2026-05-23T12:30:00+1000"
                 :source           "auto"
                 :classified_at    "2026-05-23T12:30:01+1000")))
    (while overrides
      (setq p (plist-put p (pop overrides) (pop overrides))))
    p))

(defun dl-satan-intervention-test--revised (iv-id revises-id &rest overrides)
  (apply #'dl-satan-intervention-test--classified iv-id
         :revises revises-id overrides))

;; ---------- query helpers ----------

(defun dl-satan-intervention-test--rows (table)
  "Return a sorted list of pipe-joined row strings from TABLE."
  (let* ((sql (concat "SELECT * FROM " table " ORDER BY 1"))
         (result (dl-satan-memory-migrate--psql
                  dl-satan-intervention-test--db
                  (list "-A" "-t" "-F" "|" "-c" sql))))
    (pcase result
      (`(ok . ,out)
       (split-string (string-trim out) "\n" t))
      (`(error . ,msg) (user-error "%s" msg)))))

(defun dl-satan-intervention-test--count (table)
  (let* ((sql (concat "SELECT COUNT(*) FROM " table))
         (result (dl-satan-memory-migrate--psql
                  dl-satan-intervention-test--db
                  (list "-A" "-t" "-c" sql))))
    (pcase result
      (`(ok . ,out) (string-to-number (string-trim out)))
      (`(error . ,msg) (user-error "%s" msg)))))

;; ---------- transcript discovery (no DB) -------------------------------

(ert-deftest dl-satan-intervention/transcript-files-discovers-nested ()
  (let* ((root (make-temp-file "satan-iv-runs-" t)))
    (unwind-protect
        (progn
          (dl-satan-intervention-test--write-transcript
           root "20260523T120000-morning-aaaaaa"
           (list (dl-satan-intervention-test--ev-record
                  "2026-05-23T12:00:00+1000" "intervention.created"
                  (dl-satan-intervention-test--created
                   "20260523T120000-morning-aaaaaa"
                   "20260523T120000-morning-aaaaaa.iv01"))))
          (dl-satan-intervention-test--write-transcript
           root "20260524T130000-morning-bbbbbb"
           (list (dl-satan-intervention-test--ev-record
                  "2026-05-24T13:00:00+1000" "intervention.created"
                  (dl-satan-intervention-test--created
                   "20260524T130000-morning-bbbbbb"
                   "20260524T130000-morning-bbbbbb.iv01"))))
          (let ((paths (dl-satan-intervention--transcript-files root)))
            (should (= 2 (length paths)))
            (should (cl-every (lambda (p)
                                (string-match-p "transcript\\.jsonl\\'" p))
                              paths))))
      (delete-directory root t))))

(ert-deftest dl-satan-intervention/collect-events-skips-non-intervention ()
  (let ((root (make-temp-file "satan-iv-runs-" t)))
    (unwind-protect
        (progn
          (dl-satan-intervention-test--write-transcript
           root "20260523T120000-morning-aaaaaa"
           (list
            (dl-satan-intervention-test--ev-record
             "2026-05-23T12:00:00+1000" "tool-call"
             '(:id "c1" :name "notify_send"))
            (dl-satan-intervention-test--ev-record
             "2026-05-23T12:00:01+1000" "intervention.created"
             (dl-satan-intervention-test--created
              "20260523T120000-morning-aaaaaa"
              "20260523T120000-morning-aaaaaa.iv01"))
            (dl-satan-intervention-test--ev-record
             "2026-05-23T12:00:02+1000" "log"
             '(:kind "usage"))))
          (let ((events (dl-satan-intervention--collect-events root)))
            (should (= 1 (length events)))
            (should (equal "intervention.created"
                           (plist-get (car events) :event)))))
      (delete-directory root t))))

(ert-deftest dl-satan-intervention/sort-events-by-ts-then-runid-then-seq ()
  (let* ((events
          (list (list :ts "2026-05-23T12:00:01+1000"
                      :event "intervention.created" :payload nil
                      :run_id "b" :seq 0)
                (list :ts "2026-05-23T12:00:00+1000"
                      :event "intervention.created" :payload nil
                      :run_id "z" :seq 0)
                (list :ts "2026-05-23T12:00:00+1000"
                      :event "intervention.created" :payload nil
                      :run_id "a" :seq 5)
                (list :ts "2026-05-23T12:00:00+1000"
                      :event "intervention.created" :payload nil
                      :run_id "a" :seq 1)))
         (sorted (dl-satan-intervention--sort-events events)))
    (should (equal '("a" "a" "z" "b")
                   (mapcar (lambda (e) (plist-get e :run_id)) sorted)))
    (should (equal '(1 5 0 0)
                   (mapcar (lambda (e) (plist-get e :seq)) sorted)))))


;; ---------- rebuild against test DB ----------------------------------

(ert-deftest dl-satan-intervention/rebuild-empty-runs-yields-zero-rows ()
  (dl-satan-intervention-test--with-db
   (let ((root (make-temp-file "satan-iv-runs-" t)))
     (unwind-protect
         (let ((res (dl-satan-intervention-rebuild
                     dl-satan-intervention-test--db root)))
           (should-not (plist-get res :validation-error))
           (should (= 0 (plist-get res :total)))
           (should (= 0 (dl-satan-intervention-test--count
                         "satan_interventions")))
           (should (= 0 (dl-satan-intervention-test--count
                         "satan_intervention_outcomes"))))
       (delete-directory root t)))))

(ert-deftest dl-satan-intervention/rebuild-projects-created-and-classified ()
  (dl-satan-intervention-test--with-db
   (let* ((root (make-temp-file "satan-iv-runs-" t))
          (run-id "20260523T120000-morning-aaaaaa")
          (iv-id (concat run-id ".iv01")))
     (unwind-protect
         (progn
           (dl-satan-intervention-test--write-transcript
            root run-id
            (list
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:00:00+1000" "intervention.created"
              (dl-satan-intervention-test--created run-id iv-id))
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:30:00+1000" "intervention.outcome_classified"
              (dl-satan-intervention-test--classified iv-id))))
           (let ((res (dl-satan-intervention-rebuild
                       dl-satan-intervention-test--db root)))
             (should-not (plist-get res :validation-error))
             (should (= 2 (plist-get res :total)))
             (should (= 1 (plist-get res :created)))
             (should (= 1 (plist-get res :outcomes))))
           (should (= 1 (dl-satan-intervention-test--count "satan_interventions")))
           (should (= 1 (dl-satan-intervention-test--count "satan_intervention_outcomes"))))
       (delete-directory root t)))))

(ert-deftest dl-satan-intervention/rebuild-is-idempotent ()
  (dl-satan-intervention-test--with-db
   (let* ((root (make-temp-file "satan-iv-runs-" t))
          (run1 "20260523T120000-morning-aaaaaa")
          (run2 "20260524T130000-morning-bbbbbb")
          (iv1 (concat run1 ".iv01"))
          (iv2 (concat run2 ".iv01")))
     (unwind-protect
         (progn
           (dl-satan-intervention-test--write-transcript
            root run1
            (list
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:00:00+1000" "intervention.created"
              (dl-satan-intervention-test--created run1 iv1))
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:30:00+1000" "intervention.outcome_classified"
              (dl-satan-intervention-test--classified
               iv1 :classification "ignored" :confidence "medium"))
             (dl-satan-intervention-test--ev-record
              "2026-05-23T13:00:00+1000" "intervention.outcome_revised"
              (dl-satan-intervention-test--revised
               iv1 iv1
               :classification "worked" :confidence "high"))))
           (dl-satan-intervention-test--write-transcript
            root run2
            (list
             (dl-satan-intervention-test--ev-record
              "2026-05-24T13:00:00+1000" "intervention.created"
              (dl-satan-intervention-test--created
               run2 iv2 :ts "2026-05-24T13:00:00+1000" :kind "inbox"))
             (dl-satan-intervention-test--ev-record
              "2026-05-24T14:00:00+1000" "intervention.outcome_classified"
              (dl-satan-intervention-test--classified
               iv2 :classification "harmful" :source "manual"
               :next_revisit_at "2026-05-24T13:30:00+1000"
               :classified_at   "2026-05-24T14:00:00+1000"))))
           (dl-satan-intervention-rebuild
            dl-satan-intervention-test--db root)
           (let ((first-iv (dl-satan-intervention-test--rows "satan_interventions"))
                 (first-out (dl-satan-intervention-test--rows
                             "satan_intervention_outcomes")))
             (should (= 2 (length first-iv)))
             (should (= 2 (length first-out)))
             (dl-satan-intervention-rebuild
              dl-satan-intervention-test--db root)
             (let ((second-iv (dl-satan-intervention-test--rows "satan_interventions"))
                   (second-out (dl-satan-intervention-test--rows
                                "satan_intervention_outcomes")))
               (should (equal first-iv second-iv))
               (should (equal first-out second-out)))))
       (delete-directory root t)))))

(ert-deftest dl-satan-intervention/rebuild-head-reflects-latest-revision ()
  (dl-satan-intervention-test--with-db
   (let* ((root (make-temp-file "satan-iv-runs-" t))
          (run-id "20260523T120000-morning-aaaaaa")
          (iv-id (concat run-id ".iv01")))
     (unwind-protect
         (progn
           (dl-satan-intervention-test--write-transcript
            root run-id
            (list
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:00:00+1000" "intervention.created"
              (dl-satan-intervention-test--created run-id iv-id))
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:30:00+1000" "intervention.outcome_classified"
              (dl-satan-intervention-test--classified
               iv-id :classification "ignored"))
             (dl-satan-intervention-test--ev-record
              "2026-05-23T13:00:00+1000" "intervention.outcome_revised"
              (dl-satan-intervention-test--revised
               iv-id iv-id
               :classification "worked" :confidence "high"
               :classified_at "2026-05-23T13:00:00+1000"))))
           (dl-satan-intervention-rebuild
            dl-satan-intervention-test--db root)
           (let* ((result (dl-satan-memory-migrate--psql
                           dl-satan-intervention-test--db
                           (list "-A" "-t" "-F" "|" "-c"
                                 "SELECT classification, confidence FROM satan_intervention_outcomes")))
                  (row (and (eq (car result) 'ok)
                            (string-trim (cdr result)))))
             (should (equal "worked|high" row))))
       (delete-directory root t)))))

(ert-deftest dl-satan-intervention/rebuild-refuses-on-validation-failure ()
  (dl-satan-intervention-test--with-db
   (let* ((root (make-temp-file "satan-iv-runs-" t))
          (run-id "20260523T120000-morning-aaaaaa")
          (iv-id (concat run-id ".iv01")))
     (unwind-protect
         (progn
           ;; outcome before created → replay-safety violation
           (dl-satan-intervention-test--write-transcript
            root run-id
            (list
             (dl-satan-intervention-test--ev-record
              "2026-05-23T12:30:00+1000" "intervention.outcome_classified"
              (dl-satan-intervention-test--classified iv-id))
             (dl-satan-intervention-test--ev-record
              "2026-05-23T13:00:00+1000" "intervention.created"
              (dl-satan-intervention-test--created run-id iv-id))))
           (let ((res (dl-satan-intervention-rebuild
                       dl-satan-intervention-test--db root)))
             (should (plist-get res :validation-error))
             (should (string-match-p "no prior intervention.created"
                                     (plist-get (plist-get res :validation-error)
                                                :reason))))
           ;; projection untouched
           (should (= 0 (dl-satan-intervention-test--count "satan_interventions")))
           (should (= 0 (dl-satan-intervention-test--count "satan_intervention_outcomes"))))
       (delete-directory root t)))))

(provide 'dl-satan-intervention-test)
;;; dl-satan-intervention-test.el ends here
