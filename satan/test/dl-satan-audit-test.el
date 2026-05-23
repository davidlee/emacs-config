;;; dl-satan-audit-test.el --- ert tests for dl-satan-audit -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-audit-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'dl-satan-audit)

(defun dl-satan-audit-test--write-run (dir final actions status &optional transcript)
  "Open a run under DIR, optionally record TRANSCRIPT entries, close with
FINAL/ACTIONS/STATUS.  TRANSCRIPT is a list of (DIRECTION EVENT PAYLOAD)
triples passed verbatim to `dl-satan-audit-record'."
  (make-directory dir t)
  (let ((audit (dl-satan-audit-open dir
                                    '(:run_id "r" :mode (:name "test"))
                                    '(:bundle t))))
    (dolist (rec (or transcript '()))
      (dl-satan-audit-record audit (nth 0 rec) (nth 1 rec) (nth 2 rec)))
    (dl-satan-audit-close audit final actions status)))

(ert-deftest dl-satan-audit/verifier-ok ()
  (let ((dir (make-temp-file "satan-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-audit-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))
             (broker tool-result (:id "a" :ok t))))
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

(provide 'dl-satan-audit-test)
;;; dl-satan-audit-test.el ends here
