;;; dl-modeline-test.el --- ert tests for lambda-line segments -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-modeline RET.

(require 'ert)
(require 'dl-modeline)
(require 'dl-org-iw)
(require 'org-iw)

(defvar lambda-line--selected-window)
(defvar lambda-line-user-mode)

(defmacro dl-modeline-test--in-window (active &rest body)
  "Run BODY with the selected window ACTIVE (non-nil) or not in lambda-line."
  (declare (indent 1))
  `(let ((lambda-line--selected-window (if ,active (selected-window) 'other)))
     ,@body))

(ert-deftest dl-modeline/segments-prepend-in-order ()
  "The user-mode indicator, then each segment, precede the composed line.
Segments returning nil add nothing."
  (let ((lambda-line-user-mode (lambda () "M "))
        (dl-modeline-segments (list (lambda () nil) (lambda () "S "))))
    (should (equal (dl-modeline--prepend-segments "line") "M S line"))))

(ert-deftest dl-modeline/window-active-p ()
  "A window is active only when it is the one lambda-line marks selected."
  (dl-modeline-test--in-window t
    (should (dl-modeline-window-active-p)))
  (dl-modeline-test--in-window nil
    (should-not (dl-modeline-window-active-p))))

(ert-deftest dl-org-iw/session-shows-in-active-modeline-only ()
  "The session text shows in the active window's modeline, nowhere else."
  (should (memq #'dl-org-iw--modeline-segment dl-modeline-segments))
  (let ((org-iw-queues '(("ESSAYS" :name "Essays")))
        (org-iw--session (org-iw--session-create
                          :queue "ESSAYS" :id "x" :title "Draft")))
    (dl-modeline-test--in-window t
      (should (string-match-p "IW\\[Essays: Draft\\]"
                              (dl-org-iw--modeline-segment))))
    (dl-modeline-test--in-window nil
      (should-not (dl-org-iw--modeline-segment)))))

(ert-deftest dl-org-iw/no-session-no-segment ()
  "Without a session the modeline gains nothing."
  (let ((org-iw--session nil))
    (dl-modeline-test--in-window t
      (should-not (dl-org-iw--modeline-segment)))))

(ert-deftest dl-org-iw/archive-excluded ()
  "Notes archive files are excluded; org-iw matches their true names."
  (should (string-match-p org-iw-exclude-regexp
                          (file-truename "~/notes/archive/old.org")))
  (should-not (string-match-p org-iw-exclude-regexp
                              (file-truename "~/notes/essay.org"))))

(provide 'dl-modeline-test)
;;; dl-modeline-test.el ends here
