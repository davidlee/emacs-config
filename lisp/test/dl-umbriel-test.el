;;; dl-umbriel-test.el --- ert tests for umbriel frame focus -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-umbriel RET.

(require 'ert)
(require 'cl-lib)
(require 'dl-umbriel)

(ert-deftest dl-umbriel/host-environment-removes-library-path ()
  (let ((process-environment '("LD_LIBRARY_PATH=/devshell/lib" "PATH=/bin")))
    (should (equal (dl-umbriel--host-environment) '("PATH=/bin")))
    (should (equal (getenv "LD_LIBRARY_PATH") "/devshell/lib"))))

(defconst dl-umbriel-test--windows
  '(((id . "theirs") (pid . 7) (title . "notes.org"))
    ((id . "other") (pid . 42) (title . "inbox"))
    ((id . "ours") (pid . 42) (title . "notes.org")))
  "Windows as `umbriel windows --json' lists them, trimmed to the keys used.")

;; `dl-umbriel-window-id'

(ert-deftest dl-umbriel/window-id-matches-pid-and-title ()
  "Another process's window with the same title is not ours."
  (should (equal (dl-umbriel-window-id dl-umbriel-test--windows 42 "notes.org")
                 "ours")))

(ert-deftest dl-umbriel/window-id-nil-without-match ()
  (should-not (dl-umbriel-window-id dl-umbriel-test--windows 42 "absent")))

;; `dl-umbriel-focus-frame'

(defun dl-umbriel-test--focus-calls (window-system title)
  "Arguments of each umbriel call `dl-umbriel-focus-frame' makes.
The frame is WINDOW-SYSTEM's and bears TITLE; this process is pid 42."
  (let (calls)
    (cl-letf (((symbol-function 'framep) (lambda (_) window-system))
              ((symbol-function 'frame-parameter)
               (lambda (_ param) (and (eq param 'name) title)))
              ((symbol-function 'emacs-pid) (lambda () 42))
              ((symbol-function 'dl-umbriel--windows)
               (lambda () dl-umbriel-test--windows))
              ((symbol-function 'make-process)
               (lambda (&rest args)
                 (push (cdr (plist-get args :command)) calls)
                 (kill-buffer (plist-get args :buffer)))))
      (dl-umbriel-focus-frame)
      (nreverse calls))))

(ert-deftest dl-umbriel/focus-frame-focuses-its-window ()
  (should (equal (dl-umbriel-test--focus-calls 'pgtk "notes.org")
                 '(("msg" "window-focus:ours")))))

(ert-deftest dl-umbriel/focus-frame-skips-unknown-window ()
  (should-not (dl-umbriel-test--focus-calls 'pgtk "absent")))

(ert-deftest dl-umbriel/focus-frame-skips-tty-frames ()
  "A tty frame has no compositor window."
  (should-not (dl-umbriel-test--focus-calls t "notes.org")))

;;; dl-umbriel-test.el ends here
