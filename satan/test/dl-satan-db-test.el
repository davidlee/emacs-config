;;; dl-satan-db-test.el --- shared psql runner ert -*- lexical-binding: t; -*-

(require 'ert)
(require 'dl-satan-db)

(defconst dl-satan-db-test--db "satan_memory_test"
  "Test database (same as memory-store tests use).")

(defconst dl-satan-db-test--host "/run/postgresql"
  "Production host default.  Overridden at call time by `dl-satan-db-resolve-host'
via the `dl-satan-db-host-override' carrier — the actual connection target is
the resolved host, not this literal.  Kept as a sentinel for test bodies.")

(defun dl-satan-db-test--reachable-p ()
  "Return t if the test DB is reachable (delegates to shared predicate)."
  (dl-satan-db-test-db-available-p dl-satan-db-test--db))


;; ---------------------------------------------------------------------
;; dl-satan-db-query — success paths
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-db/query-success ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            dl-satan-db-test--host
                            dl-satan-db-default-program
                            "SELECT 42 AS n"
                            nil)
    (`(ok . ,out) (should (equal out "42")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/query-empty-result ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            dl-satan-db-test--host
                            dl-satan-db-default-program
                            "SELECT 1 WHERE FALSE"
                            nil)
    (`(ok . ,out) (should (equal out "")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/query-variable-substitution ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            dl-satan-db-test--host
                            dl-satan-db-default-program
                            "SELECT :'val' AS v"
                            '(("val" . "hello")))
    (`(ok . ,out) (should (equal out "hello")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/query-multi-variable ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            dl-satan-db-test--host
                            dl-satan-db-default-program
                            "SELECT :'a' || :'b' AS v"
                            '(("a" . "foo") ("b" . "bar")))
    (`(ok . ,out) (should (equal out "foobar")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/query-multi-column-with-tab-separator ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            dl-satan-db-test--host
                            dl-satan-db-default-program
                            "SELECT 'a' AS col1, 'b' AS col2"
                            nil)
    (`(ok . ,out) (should (equal out "a\tb")))
    (other (ert-fail (format "unexpected result: %S" other)))))


;; ---------------------------------------------------------------------
;; dl-satan-db-query — error paths
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-db/query-syntax-error ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            dl-satan-db-test--host
                            dl-satan-db-default-program
                            "BOGUS SYNTAX"
                            nil)
    (`(error . ,msg)
     (should (string-match-p "psql exit" msg)))
    (other (ert-fail (format "expected error, got: %S" other)))))

(ert-deftest dl-satan-db/query-connection-failure ()
  (let ((dl-satan-db-host-override nil))
    (pcase (dl-satan-db-query dl-satan-db-test--db
                            "/nonexistent/path"
                            dl-satan-db-default-program
                            "SELECT 1"
                            nil)
    (`(error . ,msg)
     (should (string-match-p "psql exit" msg)))
    (other (ert-fail (format "expected error, got: %S" other))))))


;; ---------------------------------------------------------------------
;; dl-satan-db-psql — the thin wrapper
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-db/psql-success ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-psql dl-satan-db-test--db
                           dl-satan-db-test--host
                           dl-satan-db-default-program
                           (list "-A" "-t" "-c" "SELECT 99 AS n"))
    (`(ok . ,out) (should (equal (string-trim out) "99")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/psql-single-transaction-passthrough ()
  (skip-unless (dl-satan-db-test--reachable-p))
  "Verify --single-transaction is accepted (implied by psql not rejecting it)."
  (pcase (dl-satan-db-psql dl-satan-db-test--db
                           dl-satan-db-test--host
                           dl-satan-db-default-program
                           (list "-A" "-t" "--single-transaction" "-c" "SELECT 1"))
    (`(ok . ,out) (should (equal (string-trim out) "1")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/psql-with-input ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-psql dl-satan-db-test--db
                           dl-satan-db-test--host
                           dl-satan-db-default-program
                           (list "-A" "-t" "-f" "-")
                           "SELECT 77 AS n")
    (`(ok . ,out) (should (equal (string-trim out) "77")))
    (other (ert-fail (format "unexpected result: %S" other)))))

(ert-deftest dl-satan-db/psql-error ()
  (skip-unless (dl-satan-db-test--reachable-p))
  (pcase (dl-satan-db-psql dl-satan-db-test--db
                           dl-satan-db-test--host
                           dl-satan-db-default-program
                           (list "-c" "INVALID SQL!!!!"))
    (`(error . ,msg)
     (should (string-match-p "psql exit" msg)))
    (other (ert-fail (format "expected error, got: %S" other)))))


;; ---------------------------------------------------------------------
;; VT-db-chokepoint-guard — resolver, guard, predicate, database-url
;; ---------------------------------------------------------------------

;; --- dl-satan-db-resolve-host ---

(ert-deftest dl-satan-db/resolve-host-passthrough-when-no-override ()
  "Without override, the host arg passes through unchanged."
  (skip-unless noninteractive)
  (let ((dl-satan-db-host-override nil)
        (process-environment
         (cons "SATAN_FAILOVER_TO_SYSTEM_DB=1" process-environment)))
    (should (equal (dl-satan-db-resolve-host "/run/postgresql")
                   "/run/postgresql"))
    (should (equal (dl-satan-db-resolve-host "/custom/host")
                   "/custom/host"))))

(ert-deftest dl-satan-db/resolve-host-override-wins ()
  "When the override carrier is set, it wins over the host arg."
  (let ((dl-satan-db-host-override "192.168.1.1"))
    (should (equal (dl-satan-db-resolve-host "/run/postgresql")
                   "192.168.1.1"))
    (should (equal (dl-satan-db-resolve-host "/other/host")
                   "192.168.1.1"))))

(ert-deftest dl-satan-db/resolve-host-guard-fires-in-batch ()
  "In noninteractive batch, resolving /run/postgresql errors loudly."
  (skip-unless noninteractive)
  (let ((dl-satan-db-host-override nil))
    (should-error
     (dl-satan-db-resolve-host "/run/postgresql")
     :type 'error)))

(ert-deftest dl-satan-db/resolve-host-guard-passes-with-override ()
  "In batch with override set, the guard does not fire."
  (skip-unless noninteractive)
  (let ((dl-satan-db-host-override "127.0.0.1"))
    (should (equal (dl-satan-db-resolve-host "/run/postgresql")
                   "127.0.0.1"))))

(ert-deftest dl-satan-db/resolve-host-guard-escape-hatch ()
  "SATAN_FAILOVER_TO_SYSTEM_DB suppresses the batch guard."
  (skip-unless noninteractive)
  (let ((dl-satan-db-host-override nil)
        (process-environment
         (cons "SATAN_FAILOVER_TO_SYSTEM_DB=1" process-environment)))
    (should (equal (dl-satan-db-resolve-host "/run/postgresql")
                   "/run/postgresql"))))

;; --- dl-satan-db-test-db-available-p ---

(ert-deftest dl-satan-db/test-db-available-p-returns-nil-for-prod ()
  "Predicate returns nil when host is the production socket."
  (skip-unless noninteractive)
  (let ((dl-satan-db-host-override nil)
        (process-environment
         (cons "SATAN_FAILOVER_TO_SYSTEM_DB=1" process-environment)))
    (should-not (dl-satan-db-test-db-available-p "satan_memory_test"))))

(ert-deftest dl-satan-db/test-db-available-p-probes-test-host ()
  "Predicate probes the test host and returns t when reachable."
  (let ((dl-satan-db-host-override "127.0.0.1"))
    (should (dl-satan-db-test-db-available-p "satan_memory_test"))))

(ert-deftest dl-satan-db/test-db-available-p-returns-nil-for-bad-host ()
  "Predicate returns nil for an unreachable host."
  (let ((dl-satan-db-host-override "255.255.255.255"))
    (should-not (dl-satan-db-test-db-available-p "satan_memory_test"))))

;; --- dl-satan-db-database-url ---

(ert-deftest dl-satan-db/database-url-format ()
  (skip-unless noninteractive)
  (let ((dl-satan-db-host-override nil)
        (process-environment
         (cons "SATAN_FAILOVER_TO_SYSTEM_DB=1" process-environment)))
    (should (equal (dl-satan-db-database-url "mydb" "/run/postgresql")
                   "postgres:///mydb?host=/run/postgresql"))))

(ert-deftest dl-satan-db/database-url-uses-resolver ()
  "database-url routes its host through the resolver (override wins)."
  (let ((dl-satan-db-host-override "10.0.0.1"))
    (should (equal (dl-satan-db-database-url "mydb" "/run/postgresql")
                   "postgres:///mydb?host=10.0.0.1"))))

(provide 'dl-satan-db-test)
;;; dl-satan-db-test.el ends here
