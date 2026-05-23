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

(provide 'dl-satan-broker-test)
;;; dl-satan-broker-test.el ends here
