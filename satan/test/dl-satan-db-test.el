;;; dl-satan-db-test.el --- shared psql runner ert -*- lexical-binding: t; -*-

(require 'ert)
(require 'dl-satan-db)

(defconst dl-satan-db-test--db "satan_memory_test"
  "Test database (same as memory-store tests use).")

(defconst dl-satan-db-test--host "/run/postgresql")

(defun dl-satan-db-test--reachable-p ()
  "Return t if the test DB is reachable."
  (let ((dl-satan-db-default-host dl-satan-db-test--host))
    (pcase (dl-satan-db-query dl-satan-db-test--db
                              dl-satan-db-test--host
                              dl-satan-db-default-program
                              "SELECT 1"
                              nil)
      (`(ok . ,_) t)
      (_ nil))))


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
  (pcase (dl-satan-db-query dl-satan-db-test--db
                            "/nonexistent/path"
                            dl-satan-db-default-program
                            "SELECT 1"
                            nil)
    (`(error . ,msg)
     (should (string-match-p "psql exit" msg)))
    (other (ert-fail (format "expected error, got: %S" other)))))


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
                           (list "--single-transaction" "-c" "SELECT 1"))
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

(provide 'dl-satan-db-test)
;;; dl-satan-db-test.el ends here
