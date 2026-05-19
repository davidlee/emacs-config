;;; dl-satan-tools-hippocampus-test.el --- cross-ref tests -*- lexical-binding: t; -*-

;; Step 12: hippocampus_write emits an `auto_rule' observation trace
;; cross-referencing the org file path (§10.7).  These tests focus on
;; the cross-ref side-effect; the file-side hippocampus tests live in
;; `dl-satan-test.el'.
;;
;; DB-touching tests skip-unless the `satan_memory_test' DB is
;; reachable; they reset and re-apply migrations 0001-0004.

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools-hippocampus)
(require 'dl-satan-memory-migrate)
(require 'dl-satan-memory-store)

(defconst dl-satan-tools-hippocampus-test--db "satan_memory_test")

(defun dl-satan-tools-hippocampus-test--reachable-p ()
  (pcase (let ((dl-satan-memory-migrate-database
                dl-satan-tools-hippocampus-test--db))
           (dl-satan-memory-migrate--psql
            dl-satan-tools-hippocampus-test--db
            (list "-A" "-t" "-c" "SELECT 1")))
    (`(ok . ,_) t)
    (_ nil)))

(defun dl-satan-tools-hippocampus-test--reset-and-migrate ()
  (let ((dl-satan-memory-migrate-database
         dl-satan-tools-hippocampus-test--db))
    (dl-satan-memory-migrate--psql
     dl-satan-tools-hippocampus-test--db
     (list "-c"
           (concat
            "DROP TABLE IF EXISTS "
            "trace_links, trace_handles, traces, "
            "handle_aliases, handle_weights, grammar_versions, "
            "schema_migrations CASCADE; "
            "DROP FUNCTION IF EXISTS "
            "memory_mark_trace(jsonb), memory_show_trace(text), "
            "memory_resonate(text[], smallint, double precision, integer, text[]), "
            "handle_weight_for(text, smallint) CASCADE;")))
    (dl-satan-memory-migrate-apply)))

(defmacro dl-satan-tools-hippocampus-test--with-db (&rest body)
  (declare (indent 0))
  `(progn
     (skip-unless (dl-satan-tools-hippocampus-test--reachable-p))
     (dl-satan-tools-hippocampus-test--reset-and-migrate)
     (let ((dl-satan-memory-store-database
            dl-satan-tools-hippocampus-test--db)
           (dl-satan-memory-migrate-database
            dl-satan-tools-hippocampus-test--db))
       ,@body)))

(defun dl-satan-tools-hippocampus-test--trace-count ()
  (let ((result (dl-satan-memory-migrate--psql
                 dl-satan-tools-hippocampus-test--db
                 (list "-A" "-t" "-c" "SELECT COUNT(*) FROM traces"))))
    (pcase result
      (`(ok . ,out) (string-to-number (string-trim out)))
      (_ -1))))

(defun dl-satan-tools-hippocampus-test--all-trace-ids ()
  (let ((result (dl-satan-memory-migrate--psql
                 dl-satan-tools-hippocampus-test--db
                 (list "-A" "-t" "-c"
                       "SELECT id FROM traces ORDER BY id"))))
    (pcase result
      (`(ok . ,out) (split-string (string-trim out) "\n" t))
      (_ nil))))

;; ---------------------------------------------------------------------
;; Cross-ref tests
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-tools-hippocampus/no-cross-ref-without-memory-write ()
  "Absent `memory-write' capability: org file is written but no trace
is emitted."
  (dl-satan-tools-hippocampus-test--with-db
   (let* ((tmp (make-temp-file "satan-hippo-" t))
          (dl-satan-hippocampus-dir tmp))
     (unwind-protect
         (let ((res (dl-satan-tool/hippocampus-write
                     '(:title "no-cross-ref" :body "body")
                     '(:id "r-no-mw" :mode-name "morning"
                       :capabilities (hippocampus-write)))))
           (should (eq (car res) 'ok))
           (should (= 0 (dl-satan-tools-hippocampus-test--trace-count))))
       (delete-directory tmp t)))))

(ert-deftest dl-satan-tools-hippocampus/cross-ref-with-memory-write ()
  "`memory-write' present: org file is written and an `auto_rule'
trace is emitted carrying `:hippocampus_path' in metadata_json."
  (dl-satan-tools-hippocampus-test--with-db
   (let* ((tmp (make-temp-file "satan-hippo-" t))
          (dl-satan-hippocampus-dir tmp))
     (unwind-protect
         (let* ((res (dl-satan-tool/hippocampus-write
                      '(:title "Avoid mocking the DB"
                        :body "User burned by mock/prod divergence.")
                      '(:id "r-mw" :mode-name "morning"
                        :capabilities (hippocampus-write memory-write))))
                (path (plist-get (cdr res) :path)))
           (should (eq (car res) 'ok))
           (should (= 1 (dl-satan-tools-hippocampus-test--trace-count)))
           (let* ((tid (car (dl-satan-tools-hippocampus-test--all-trace-ids)))
                  (show (dl-satan-memory-store-show tid))
                  (trace (plist-get (cdr show) :trace))
                  (md (plist-get trace :metadata_json)))
             (should (eq (car show) 'ok))
             (should (equal (plist-get trace :trace_origin) "auto_rule"))
             (should (equal (plist-get trace :kind) "observation"))
             (should (string-prefix-p "hippocampus_write@"
                                      (plist-get trace :source)))
             (should (stringp (plist-get md :hippocampus_path)))
             (should (string-match-p "satan_hippocampus\\.org$"
                                     (plist-get md :hippocampus_path)))))
       (delete-directory tmp t)))))

(ert-deftest dl-satan-tools-hippocampus/cross-ref-soft-fail-on-bad-db ()
  "When the substrate cannot reach a DB, the org write still
succeeds and the handler returns ok."
  (let* ((tmp (make-temp-file "satan-hippo-" t))
         (dl-satan-hippocampus-dir tmp)
         (dl-satan-memory-store-database "satan_memory_unreachable_dbz"))
    (unwind-protect
        (let ((res (dl-satan-tool/hippocampus-write
                    '(:title "soft-fail" :body "still ok")
                    '(:id "r-fail" :mode-name "morning"
                      :capabilities (hippocampus-write memory-write)))))
          (should (eq (car res) 'ok))
          (should (file-exists-p (plist-get (cdr res) :path))))
      (delete-directory tmp t))))

(provide 'dl-satan-tools-hippocampus-test)
;;; dl-satan-tools-hippocampus-test.el ends here
