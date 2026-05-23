;;; dl-satan-attribute-listener-test.el --- LISTEN satan_audit_inbox -*- lexical-binding: t; -*-

;; T-attr-1c slice 2 — broker LISTENer on the daemon → broker audit
;; queue.  All tests are pure: the psql subprocess is mocked, the run
;; directory is a temp dir, and validator behaviour is exercised by
;; feeding the listener payloads with deliberate shape problems.
;;
;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-attribute-listener-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'dl-satan-attribute-listener)
(require 'dl-satan-audit)

(declare-function dl-satan-broker-locate-run-dir "dl-satan-broker"
                  (run-id &optional runs-dir))

;; ---------------------------------------------------------------------
;; helpers
;; ---------------------------------------------------------------------

(defconst dl-satan-attribute-listener-test--run-id
  "20260524T120000Z-test-deadbe")

(defconst dl-satan-attribute-listener-test--event-id
  "20260524T120000Z-test-deadbe.attr007")

(defun dl-satan-attribute-listener-test--baseline-payload (&rest overrides)
  "Return a baseline accept-shaped payload, OVERRIDES applied via plist."
  (let ((base
         (list :schema_version "1.0"
               :id     dl-satan-attribute-listener-test--event-id
               :ts     "2026-05-24T12:00:00Z"
               :scope  "global"
               :name   "shame"
               :old    0.10
               :new    0.25
               :delta  0.15
               :source "outcome"
               :reason "contradicted"
               :evidence (list :intervention_id
                               (concat
                                dl-satan-attribute-listener-test--run-id
                                ".iv001")
                               :classification "contradicted"
                               :confidence     "medium")
               :caps_applied '()
               :disabled :false)))
    (cl-loop for (k v) on overrides by #'cddr
             do (setq base (plist-put base k v)))
    base))

(defun dl-satan-attribute-listener-test--notif-line (channel payload)
  (format "{\"channel\":\"%s\",\"payload\":\"%s\"}\n" channel payload))

(defmacro dl-satan-attribute-listener-test--with-mocks
    (claimed-payload calls-var &rest body)
  "Run BODY with the listener's psql calls mocked.

CLAIMED-PAYLOAD is the payload plist `--claim-row' returns (or `nil' to
simulate a race / unknown id).  CALLS-VAR is the symbol bound to a list
collecting the sql calls made (each entry: (kind args)) — `kind' is one
of `claim', `delete', `reject'.

Run-dir lookup is also mocked: every request resolves to a fresh temp
dir holding an empty transcript.jsonl, bound as `tmp' inside BODY."
  (declare (indent 2))
  `(let* ((,calls-var '())
          (tmp (make-temp-file "dl-satan-attribute-listener-test-" t))
          (transcript (expand-file-name "transcript.jsonl" tmp)))
     (write-region "" nil transcript)
     (unwind-protect
         (cl-letf (((symbol-function 'dl-satan-attribute-listener--claim-row)
                    (lambda (id)
                      (push (list 'claim id) ,calls-var)
                      ,claimed-payload))
                   ((symbol-function 'dl-satan-attribute-listener--delete-row)
                    (lambda (id)
                      (push (list 'delete id) ,calls-var)
                      nil))
                   ((symbol-function 'dl-satan-attribute-listener--reject)
                    (lambda (id msg)
                      (push (list 'reject id msg) ,calls-var)
                      nil))
                   ((symbol-function 'dl-satan-broker-locate-run-dir)
                    (lambda (_run-id) tmp)))
           ,@body)
       (delete-directory tmp t))))

(defun dl-satan-attribute-listener-test--transcript-lines (dir)
  "Return the list of JSON-decoded transcript records in DIR."
  (let ((path (expand-file-name "transcript.jsonl" dir)))
    (when (file-exists-p path)
      (with-temp-buffer
        (insert-file-contents path)
        (let (out)
          (goto-char (point-min))
          (while (not (eobp))
            (let* ((line (buffer-substring-no-properties
                          (line-beginning-position) (line-end-position))))
              (unless (string-empty-p line)
                (push (json-parse-string line
                                         :object-type 'plist
                                         :array-type 'list
                                         :null-object nil
                                         :false-object :false)
                      out)))
            (forward-line 1))
          (nreverse out))))))

;; ---------------------------------------------------------------------
;; happy path: accept → transcript line + delete
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-attribute-listener/accept-writes-transcript-line-and-deletes ()
  (let ((payload (dl-satan-attribute-listener-test--baseline-payload)))
    (dl-satan-attribute-listener-test--with-mocks
        payload calls
     (dl-satan-attribute-listener--handle 42)
     (let ((kinds (mapcar #'car calls)))
       (should (member 'claim kinds))
       (should (member 'delete kinds))
       (should-not (member 'reject kinds)))
     (let* ((records (dl-satan-attribute-listener-test--transcript-lines tmp)))
       (should (= 1 (length records)))
       (let ((rec (car records)))
         (should (equal "broker" (plist-get rec :dir)))
         (should (equal "attribute.delta_applied" (plist-get rec :event)))
         (should (equal "shame" (plist-get (plist-get rec :payload) :name))))))))

;; ---------------------------------------------------------------------
;; reject paths
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-attribute-listener/reject-on-schema-major-mismatch ()
  (let ((payload (dl-satan-attribute-listener-test--baseline-payload
                  :schema_version "2.0")))
    (dl-satan-attribute-listener-test--with-mocks
        payload calls
     (dl-satan-attribute-listener--handle 13)
     (let ((reject (assoc 'reject calls)))
       (should reject)
       (should (string-match-p "schema_version major 2" (nth 2 reject))))
     ;; No transcript written.
     (should (null (dl-satan-attribute-listener-test--transcript-lines tmp))))))

(ert-deftest dl-satan-attribute-listener/reject-on-validator-failure-out-of-range ()
  (let ((payload (dl-satan-attribute-listener-test--baseline-payload
                  :old 1.50 :new 1.65)))
    (dl-satan-attribute-listener-test--with-mocks
        payload calls
     (dl-satan-attribute-listener--handle 7)
     (should (assoc 'reject calls))
     (should-not (assoc 'delete calls))
     (should (null (dl-satan-attribute-listener-test--transcript-lines tmp))))))

(ert-deftest dl-satan-attribute-listener/race-when-row-already-claimed-is-noop ()
  ;; claim-row returning nil simulates an already-claimed / unknown id.
  (dl-satan-attribute-listener-test--with-mocks
      nil calls
    (dl-satan-attribute-listener--handle 99)
    (should (equal '(claim) (mapcar #'car calls)))))

;; ---------------------------------------------------------------------
;; filter — psql notification → handle dispatch
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-attribute-listener/filter-dispatches-on-known-channel ()
  (let (received)
    (cl-letf (((symbol-function 'dl-satan-attribute-listener--handle)
               (lambda (id) (push id received))))
      (let ((filter (dl-satan-attribute-listener--make-filter)))
        (funcall filter nil
                 (dl-satan-attribute-listener-test--notif-line
                  "satan_audit_inbox" "42"))
        (should (equal '(42) received))))))

(ert-deftest dl-satan-attribute-listener/filter-ignores-unknown-channel ()
  (let (received)
    (cl-letf (((symbol-function 'dl-satan-attribute-listener--handle)
               (lambda (id) (push id received))))
      (let ((filter (dl-satan-attribute-listener--make-filter)))
        (funcall filter nil
                 (dl-satan-attribute-listener-test--notif-line
                  "some_other_channel" "42"))
        (should (null received))))))

(ert-deftest dl-satan-attribute-listener/filter-buffers-partial-lines ()
  (let (received)
    (cl-letf (((symbol-function 'dl-satan-attribute-listener--handle)
               (lambda (id) (push id received))))
      (let* ((filter (dl-satan-attribute-listener--make-filter))
             (full (dl-satan-attribute-listener-test--notif-line
                    "satan_audit_inbox" "55"))
             (mid (/ (length full) 2)))
        (funcall filter nil (substring full 0 mid))
        (should (null received))
        (funcall filter nil (substring full mid))
        (should (equal '(55) received))))))

;; ---------------------------------------------------------------------
;; --check-schema unit
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-attribute-listener/check-schema-accepts-matching-major ()
  (should (null (dl-satan-attribute-listener--check-schema
                 '(:schema_version "1.0"))))
  (should (null (dl-satan-attribute-listener--check-schema
                 '(:schema_version "1.7")))))

(ert-deftest dl-satan-attribute-listener/check-schema-rejects-missing ()
  (should (string-match-p "missing"
                          (dl-satan-attribute-listener--check-schema '()))))

(ert-deftest dl-satan-attribute-listener/check-schema-rejects-major-mismatch ()
  (should (string-match-p "major 2"
                          (dl-satan-attribute-listener--check-schema
                           '(:schema_version "2.0")))))

;; ---------------------------------------------------------------------
;; run-id extraction from event id
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-attribute-listener/run-id-extracted-from-payload ()
  (should (equal "20260524T120000Z-test-deadbe"
                 (dl-satan-attribute-listener--run-id-from-payload
                  '(:id "20260524T120000Z-test-deadbe.attr007"))))
  (should (null (dl-satan-attribute-listener--run-id-from-payload
                 '(:id "malformed-id"))))
  (should (null (dl-satan-attribute-listener--run-id-from-payload
                 '()))))

(provide 'dl-satan-attribute-listener-test)
;;; dl-satan-attribute-listener-test.el ends here
