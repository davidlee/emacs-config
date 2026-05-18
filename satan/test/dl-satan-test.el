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
(require 'dl-satan-jsonl)
(require 'dl-satan-block)
(require 'dl-satan-tools)
(require 'dl-satan-tools-notify)
(require 'dl-satan-audit)

;; ---------- dl-satan-jsonl ----------

(ert-deftest dl-satan-jsonl/parses-complete-line ()
  (let* ((seen nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (obj) (push obj seen))
                  (lambda (_err) (error "should not error")))))
    (funcall filter nil "{\"type\":\"ready\",\"run_id\":\"r1\"}\n")
    (should (equal (length seen) 1))
    (should (equal (plist-get (car seen) :type) "ready"))
    (should (equal (plist-get (car seen) :run_id) "r1"))))

(ert-deftest dl-satan-jsonl/joins-chunked-line ()
  (let* ((seen nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (obj) (push obj seen))
                  (lambda (_err) (error "should not error")))))
    (funcall filter nil "{\"type\":\"log\",")
    (funcall filter nil "\"message\":\"x\"}\n")
    (should (equal (length seen) 1))
    (should (equal (plist-get (car seen) :type) "log"))))

(ert-deftest dl-satan-jsonl/holds-partial-trailing-line ()
  (let* ((seen nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (obj) (push obj seen))
                  (lambda (_err) (error "should not error")))))
    (funcall filter nil "{\"type\":\"log\",\"message\":\"a\"}\n{\"type\":")
    (should (equal (length seen) 1))
    (funcall filter nil "\"log\",\"message\":\"b\"}\n")
    (should (equal (length seen) 2))))

(ert-deftest dl-satan-jsonl/reports-parse-error ()
  (let* ((errs nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (_obj) (error "should not call on-object"))
                  (lambda (e) (push e errs)))))
    (funcall filter nil "not-json\n")
    (should (equal (length errs) 1))
    (should (equal (car (car errs)) "not-json"))))

;; ---------- dl-satan-block ----------

(ert-deftest dl-satan-block/replace-ok ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "* h\n"
                    "#+begin_satan :block satan :owner SATAN :updated [old]\n"
                    "old body\n"
                    "#+end_satan\n"
                    "* tail\n"))
          (should (eq (dl-satan-block-replace file "satan" "new body") 'ok))
          (let ((s (with-temp-buffer (insert-file-contents file) (buffer-string))))
            (should (string-match-p "new body\n" s))
            (should-not (string-match-p "old body" s))
            (should (string-match-p ":updated \\[20" s))
            (should (string-match-p "\\* tail" s))))
      (delete-file file))))

(ert-deftest dl-satan-block/multi-match-refuses ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "#+begin_satan :block satan :owner SATAN :updated [a]\nA\n#+end_satan\n\n"
                    "#+begin_satan :block satan :owner SATAN :updated [b]\nB\n#+end_satan\n"))
          (should (eq (dl-satan-block-replace file "satan" "new") 'multi-match)))
      (delete-file file))))

(ert-deftest dl-satan-block/none-match-noop ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "no block here\n"))
          (should (eq (dl-satan-block-replace file "satan" "new") 'none-match)))
      (delete-file file))))

(ert-deftest dl-satan-block/create-at-end ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "* header\nbody\n"))
          (should (eq (dl-satan-block-create-at-end file "satan" "fresh") 'ok))
          (let ((s (with-temp-buffer (insert-file-contents file) (buffer-string))))
            (should (string-match-p "#\\+begin_satan :block satan :owner SATAN :updated \\[20" s))
            (should (string-match-p "fresh\n#\\+end_satan" s))))
      (delete-file file))))

;; ---------- dl-satan-tools schema validator ----------

(ert-deftest dl-satan-tools/schema-required-missing ()
  (let ((spec (list :args-schema '(scope (:type string :required t
                                          :enum ("today" "week"))))))
    (should (stringp (dl-satan-tool-validate-args spec '())))))

(ert-deftest dl-satan-tools/schema-enum-violation ()
  (let ((spec (list :args-schema '(scope (:type string :required t
                                          :enum ("today" "week"))))))
    (should (stringp (dl-satan-tool-validate-args spec '(:scope "year"))))))

(ert-deftest dl-satan-tools/schema-ok ()
  (let ((spec (list :args-schema '(scope (:type string :required t
                                          :enum ("today" "week"))))))
    (should (null (dl-satan-tool-validate-args spec '(:scope "today"))))))

(ert-deftest dl-satan-tools/dispatch-unknown ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "x" :name "no.such" :args nil)
              '("no.such")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "unknown tool" (plist-get res :error)))))

(ert-deftest dl-satan-tools/dispatch-not-allowed ()
  (dl-satan-tool-register
   (list :name "test.allowed-check"
         :args-schema nil
         :handler (lambda (_a _c) (cons 'ok '(:done t)))))
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "x" :name "test.allowed-check" :args nil)
              '()
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "not allowed" (plist-get res :error)))))

;; ---------- dl-satan-tools-notify ----------

(ert-deftest dl-satan-notify/dispatch-ok ()
  "notify.send dispatches via the registry, stubbing the D-Bus call."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) 42)))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n1" :name "notify.send"
                  :args (:title "hi" :body "there"))
                '("notify.send")
                nil)))
      (should (eq (plist-get res :ok) t))
      (should (equal (plist-get (plist-get res :result) :id) 42)))))

(ert-deftest dl-satan-notify/schema-missing-title ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n2" :name "notify.send"
                :args (:body "x"))
              '("notify.send")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "title" (plist-get res :error)))))

(ert-deftest dl-satan-notify/schema-urgency-enum ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n3" :name "notify.send"
                :args (:title "t" :body "b" :urgency "screaming"))
              '("notify.send")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "urgency" (plist-get res :error)))))

(ert-deftest dl-satan-notify/handler-error-propagates ()
  "If `notifications-notify' signals, the result is `error' with message."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) (error "no D-Bus today"))))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n4" :name "notify.send"
                  :args (:title "t" :body "b"))
                '("notify.send")
                nil)))
      (should (equal (plist-get res :ok) :false))
      (should (string-match-p "no D-Bus" (plist-get res :error))))))

;; ---------- dl-satan-audit verifier ----------

(defun dl-satan-test--write-run (dir final actions status &optional transcript)
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
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))
             (broker tool-result (:id "a" :ok t))))
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-detects-orphan-call ()
  (let ((dir (make-temp-file "satan-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))))
          (let ((res (dl-satan-audit-verify-run dir)))
            (should (consp res))
            (should (assq 'calls-match-results res))))
      (delete-directory dir t))))

(provide 'dl-satan-test)
;;; dl-satan-test.el ends here
