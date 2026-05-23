;;; dl-satan-tools-notify-test.el --- ert tests for dl-satan-tools-notify -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-tools-notify-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools)
(require 'dl-satan-tools-notify)

(ert-deftest dl-satan-notify/dispatch-ok ()
  "notify.send dispatches via the registry, stubbing the D-Bus call."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) 42)))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n1" :name "notify_send"
                  :args (:title "hi" :body "there"))
                '("notify_send")
                '(:capabilities (notify)))))
      (should (eq (plist-get res :ok) t))
      (should (equal (plist-get (plist-get res :result) :id) 42)))))

(ert-deftest dl-satan-notify/schema-missing-title ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n2" :name "notify_send"
                :args (:body "x"))
              '("notify_send")
              '(:capabilities (notify)))))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "title" (plist-get res :error)))))

(ert-deftest dl-satan-notify/schema-urgency-enum ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n3" :name "notify_send"
                :args (:title "t" :body "b" :urgency "screaming"))
              '("notify_send")
              '(:capabilities (notify)))))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "urgency" (plist-get res :error)))))

(ert-deftest dl-satan-notify/handler-error-propagates ()
  "If `notifications-notify' signals, the result is `error' with message."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) (error "no D-Bus today"))))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n4" :name "notify_send"
                  :args (:title "t" :body "b"))
                '("notify_send")
                '(:capabilities (notify)))))
      (should (equal (plist-get res :ok) :false))
      (should (string-match-p "no D-Bus" (plist-get res :error))))))

(provide 'dl-satan-tools-notify-test)
;;; dl-satan-tools-notify-test.el ends here
