;;; dl-zmx-org-test.el --- ert tests for zmx Org links -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-zmx-org RET.

(require 'ert)
(require 'cl-lib)
(require 'ol)
(require 'dl-zmx-org)

(defmacro dl-zmx-org-test--with-sessions (sessions &rest body)
  "Run BODY with zmx reporting SESSIONS; `reattached' holds what was reattached."
  (declare (indent 1))
  `(let ((reattached nil))
     (cl-letf (((symbol-function 'dl-zmx-sessions) (lambda () ,sessions))
               ((symbol-function 'dl-zmx--reattach)
                (lambda (session) (push session reattached))))
       ,@body)))

(ert-deftest dl-zmx-org/link-type-registered ()
  (should (eq (org-link-get-parameter "zmx" :follow) #'dl-zmx-org-follow)))

(ert-deftest dl-zmx-org/follow-reattaches-a-running-session ()
  (let ((session '((name . "hris.2") (dir . "/tmp"))))
    (dl-zmx-org-test--with-sessions (list '((name . "hris.1")) session)
      (dl-zmx-org-follow "hris.2" nil)
      (should (equal reattached (list session))))))

(ert-deftest dl-zmx-org/follow-refuses-a-session-not-running ()
  "Attaching would create an empty session in its place."
  (dl-zmx-org-test--with-sessions (list '((name . "hris.1")))
    (should-error (dl-zmx-org-follow "hris.2" nil) :type 'user-error)
    (should-not reattached)))

(ert-deftest dl-zmx-org/store-names-the-terminal-session ()
  (with-temp-buffer
    (rename-buffer (dl-zmx-buffer-name "hris.2") t)
    (let ((org-store-link-plist nil))
      (should (dl-zmx-org-store-link))
      (should (equal (plist-get org-store-link-plist :link) "zmx:hris.2"))
      (should (equal (plist-get org-store-link-plist :description) "hris.2")))))

(ert-deftest dl-zmx-org/store-ignores-other-buffers ()
  (with-temp-buffer
    (should-not (dl-zmx-org-store-link))))

(ert-deftest dl-zmx-org/complete-offers-running-sessions ()
  (cl-letf (((symbol-function 'dl-zmx--read-session)
             (lambda (_prompt) '((name . "hris.2")))))
    (should (equal (dl-zmx-org-complete) "zmx:hris.2"))))

(provide 'dl-zmx-org-test)
;;; dl-zmx-org-test.el ends here
