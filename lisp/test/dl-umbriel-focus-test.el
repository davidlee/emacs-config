;;; dl-umbriel-focus-test.el --- ert tests for umbriel frame focus -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-umbriel-focus/ RET.
;;
;; `dl-umbriel-send' is faked with scripted replies: no test reaches a compositor.

(require 'ert)
(require 'cl-lib)
(require 'dl-umbriel-focus)

(defconst dl-umbriel-focus-test--windows
  '(((id . "theirs") (pid . 7) (title . "notes.org"))
    ((id . "other") (pid . 42) (title . "inbox"))
    ((id . "ours") (pid . 42) (title . "notes.org")))
  "Windows as umbriel's `windows' query lists them, trimmed to the keys used.")

;;;; `dl-umbriel-window-id'

(ert-deftest dl-umbriel-focus/window-id-matches-pid-and-title ()
  "Another process's window with the same title is not ours."
  (should (equal (dl-umbriel-window-id dl-umbriel-focus-test--windows 42 "notes.org")
                 "ours")))

(ert-deftest dl-umbriel-focus/window-id-nil-without-match ()
  (should-not (dl-umbriel-window-id dl-umbriel-focus-test--windows 42 "absent")))

;;;; `dl-umbriel-focus-frame'

(defun dl-umbriel-focus-test--run (window-system title replies)
  "Focus a WINDOW-SYSTEM frame bearing TITLE; this process is pid 42.
`dl-umbriel-send' answers REPLIES in order.  Return (REQUESTS MESSAGES)."
  (let (requests messages)
    (cl-letf (((symbol-function 'framep) (lambda (_) window-system))
              ((symbol-function 'frame-parameter)
               (lambda (_ param) (and (eq param 'name) title)))
              ((symbol-function 'emacs-pid) (lambda () 42))
              ((symbol-function 'dl-umbriel-send)
               (lambda (request callback)
                 (push request requests)
                 (funcall callback (pop replies))))
              ((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      (dl-umbriel-focus-frame 'a-frame))
    (list (reverse requests) (reverse messages))))

(ert-deftest dl-umbriel-focus/focuses-its-window ()
  (should (equal (dl-umbriel-focus-test--run
                  'pgtk "notes.org" `((:ok ,dl-umbriel-focus-test--windows) (:ok nil)))
                 (list (list (dl-umbriel-query "windows")
                             (dl-umbriel-action "window-focus" '((window . "ours"))))
                       nil))))

(ert-deftest dl-umbriel-focus/no-match-sends-nothing-more ()
  (should (equal (dl-umbriel-focus-test--run
                  'pgtk "absent" `((:ok ,dl-umbriel-focus-test--windows)))
                 (list (list (dl-umbriel-query "windows")) nil))))

(ert-deftest dl-umbriel-focus/skips-non-pgtk-frames ()
  (should (equal (dl-umbriel-focus-test--run 'x "notes.org" nil) '(nil nil))))

(ert-deftest dl-umbriel-focus/echoes-a-failure ()
  (let ((failure '(:failure absent "/run/u/umbriel-wayland-1.sock")))
    (should (equal (cadr (dl-umbriel-focus-test--run 'pgtk "notes.org" (list failure)))
                   (list (dl-umbriel-failure-message failure))))))

(provide 'dl-umbriel-focus-test)
;;; dl-umbriel-focus-test.el ends here
