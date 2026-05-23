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
