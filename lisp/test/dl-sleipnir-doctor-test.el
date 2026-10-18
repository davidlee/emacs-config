;;; dl-sleipnir-doctor-test.el --- ert tests for the sleipnir-doctor provider -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-sleipnir-doctor RET.

(require 'ert)
(require 'dl-sleipnir-doctor)

(ert-deftest dl-sleipnir-doctor/no-browser-segments-is-not-a-problem ()
  "Firefox closed all day leaves no browser segments; panopticon's
freshness check owns whether the browser feed is alive."
  (should (equal (sleipnir-doctor--probe->doctor "browser" "missing") "OK"))
  (should (equal (sleipnir-doctor--probe->doctor "focus" "missing") "WARN"))
  (should (equal (sleipnir-doctor--probe->doctor "browser" "malformed") "CRIT")))

(ert-deftest dl-sleipnir-doctor/roam-db-is-judged-against-the-notes ()
  "An old db is fine when no note changed since; a note newer than the
db by more than an hour means the db is out of sync."
  (should (equal (sleipnir-doctor--roam-db-status 1000.0 900.0) "OK"))
  (should (equal (sleipnir-doctor--roam-db-status 1000.0 4000.0) "OK"))
  (should (equal (sleipnir-doctor--roam-db-status 1000.0 4601.0) "WARN"))
  (should (equal (sleipnir-doctor--roam-db-status 1000.0 nil) "OK")))

;;; dl-sleipnir-doctor-test.el ends here
