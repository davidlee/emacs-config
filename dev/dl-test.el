;;; dl-test.el --- Run the ERT suite over emacsclient -*- lexical-binding: t; -*-

;; Drives the project's ERT suites from the *live* Emacs server so
;; `just check' can verify a change without spawning a throwaway batch
;; Emacs (which would have to rebuild the whole load-path).  The runner
;; returns a one-line summary string — `emacsclient --eval' prints the
;; return value, and the justfile recipe greps it for the exit code.
;; Per-test detail lands in *Messages* (the server's stderr).
;;
;; Side-effect policy lives in the suites, not here: DB-touching tests
;; isolate to a dedicated test database (satan_memory_test / trace_test /
;; patch_live_test) and `skip-unless' it is reachable; pure suites mock
;; the psql subprocess.  So this runner just loads everything — do NOT
;; re-add a subsystem exclusion list (see memory
;; mem.fact.satan.test-db-isolation).
;;
;; CLI shape (see ../Justfile):
;;   emacsclient --eval '(dl-test-run-suite)'

;;; Code:

(require 'ert)

(defvar dl-test-suite-dirs '("satan/test" "lisp/test")
  "Directories (relative to `user-emacs-directory') scanned for ERT files.
A file is a test file when its name ends in \"-test.el\" or begins
with \"test-\".")

(defun dl-test--file-p (name)
  "Non-nil when NAME (a basename) is an ERT test file."
  (and (string-suffix-p ".el" name)
       (or (string-suffix-p "-test.el" name)
           (string-prefix-p "test-" name))))

(defun dl-test--suite-files ()
  "Absolute paths of every ERT test file under `dl-test-suite-dirs'."
  (let (files)
    (dolist (dir dl-test-suite-dirs)
      (let ((abs (expand-file-name dir user-emacs-directory)))
        (when (file-directory-p abs)
          (dolist (f (directory-files abs t "\\.el\\'"))
            (when (dl-test--file-p (file-name-nondirectory f))
              (push f files))))))
    (nreverse files)))

(defun dl-test-run-suite ()
  "Load and run the ERT suites, returning a one-line summary string.
Clears previously-defined tests first so only freshly-loaded files
run.  DB-backed tests `skip-unless' their test database is reachable."
  (ert-delete-all-tests)
  (let ((load-errors '()))
    (dolist (f (dl-test--suite-files))
      (condition-case err
          (load f nil t)
        (error (push (format "%s: %s" (file-name-base f)
                             (error-message-string err))
                     load-errors))))
    (let* ((stats (ert-run-tests-batch t))
           (total (ert-stats-total stats))
           (unexpected (ert-stats-completed-unexpected stats))
           (expected (ert-stats-completed-expected stats))
           (skipped (if (fboundp 'ert-stats-skipped)
                        (ert-stats-skipped stats) 0))
           (loaderr (when load-errors
                      (format " | LOADERR %d: %s"
                              (length load-errors)
                              (string-join (nreverse load-errors) "; ")))))
      (if (and (zerop unexpected) (null load-errors))
          (format "PASS %d/%d passed (%d skipped)" expected total skipped)
        (format "FAIL %d unexpected / %d total (%d skipped)%s"
                unexpected total skipped (or loaderr ""))))))

(provide 'dl-test)
;;; dl-test.el ends here
