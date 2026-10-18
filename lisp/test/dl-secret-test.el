;;; dl-secret-test.el --- ert tests for dl-secret's 1Password backend -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-secret RET.
;;
;; No test calls the real `op'.  `my/op-cli' is replaced by a stub shell
;; script that appends its argv to a log and exits with a scripted code;
;; `my/op--cache' is a fresh table per test.

(require 'ert)
(require 'cl-lib)
(require 'dl-secret)

(defmacro dl-secret-test--with-stub-op (spec &rest body)
  "Run BODY with `my/op-cli' stubbed and a fresh `my/op--cache'.
SPEC is (LOG-VAR EXIT-CODE &optional STDOUT).  The stub appends its
argv (space-separated, one line per call) to a file; LOG-VAR is bound
to a function returning those lines."
  (declare (indent 1))
  (let ((log-var (nth 0 spec)) (code (nth 1 spec)) (out (nth 2 spec)))
    `(let* ((dir (make-temp-file "dl-secret-test-" t))
             (log (expand-file-name "argv" dir))
             (stub (expand-file-name "op" dir))
             (my/op-cli stub)
             (my/op--cache (make-hash-table :test 'equal))
             (,log-var (lambda ()
                         (when (file-exists-p log)
                           (split-string
                             (with-temp-buffer (insert-file-contents log)
                               (buffer-string))
                             "\n" t)))))
       (unwind-protect
         (progn
           (with-temp-file stub
             (insert "#!/bin/sh\n"
               (format "echo \"$*\" >> %s\n" (shell-quote-argument log))
               (format "printf %%s %s\n" (shell-quote-argument (or ,out "")))
               (format "exit %d\n" ,code)))
           (set-file-modes stub #o755)
           ;; `my/op--announce' notifies over D-Bus; keep tests silent.
           (cl-letf (((symbol-function 'my/op--announce) #'ignore))
             ,@body))
         (delete-directory dir t)))))

;;; VT-25 — `my/op-session-p' is a non-prompting `op whoami' probe.

(ert-deftest dl-secret-session-p-live-when-whoami-succeeds ()
  (dl-secret-test--with-stub-op (argv 0)
    (should (my/op-session-p))
    (should (equal (funcall argv) '("whoami")))))

(ert-deftest dl-secret-session-p-nil-when-whoami-fails ()
  (dl-secret-test--with-stub-op (argv 1)
    (should-not (my/op-session-p))
    (should (equal (funcall argv) '("whoami")))))

;;; `my/op-read' resolves op:// refs for org-gcal; cached per session.

(ert-deftest dl-secret-op-read-resolves-and-caches ()
  (dl-secret-test--with-stub-op (argv 0 "k3y\n")
    (should (equal (my/op-read "op://v/i/f") "k3y"))
    (should (equal (gethash "op://v/i/f" my/op--cache) "k3y"))
    (should (equal (my/op-read "op://v/i/f") "k3y"))
    (should (equal (funcall argv) '("read --no-newline op://v/i/f")))))

(ert-deftest dl-secret-op-read-refresh-bypasses-cache ()
  (dl-secret-test--with-stub-op (argv 0 "fresh")
    (puthash "op://v/i/f" "stale" my/op--cache)
    (should (equal (my/op-read "op://v/i/f") "stale"))
    (should-not (funcall argv))
    (should (equal (my/op-read "op://v/i/f" t) "fresh"))
    (should (equal (funcall argv) '("read --no-newline op://v/i/f")))))

(ert-deftest dl-secret-op-read-signals-on-failure ()
  (dl-secret-test--with-stub-op (argv 1)
    (should-error (my/op-read "op://v/i/f"))
    (should-not (gethash "op://v/i/f" my/op--cache))))

(provide 'dl-secret-test)
;;; dl-secret-test.el ends here
