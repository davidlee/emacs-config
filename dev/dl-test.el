;;; dl-test.el --- Run the ERT suite over emacsclient -*- lexical-binding: t; -*-

;; Drives the project's ERT suites from the *live* Emacs server so
;; `just check' can verify a change without spawning a throwaway batch
;; Emacs (which would have to rebuild the whole load-path).  The runner
;; returns a one-line summary string — `emacsclient --eval' prints the
;; return value, and the justfile recipe greps it for the exit code.
;; Per-test detail lands in *Messages* (the server's stderr).
;;
;; CLI shape (see ../justfile):
;;   emacsclient --eval '(dl-test-run-suite)'      ; fast suites only
;;   emacsclient --eval '(dl-test-run-suite t)'    ; include DB/IO suites

;;; Code:

(require 'ert)

(defvar dl-test-suite-dirs '("satan/test" "lisp/test")
  "Directories (relative to `user-emacs-directory') scanned for ERT files.
A file is a test file when its name ends in \"-test.el\" or begins
with \"test-\".")

(defvar dl-test-db-excludes
  '("dl-satan-memory-store"
    "dl-satan-memory-canon"
    "dl-satan-memory-grammar"
    "dl-satan-memory-migrate"
    "dl-satan-memory-renormalize"
    "dl-satan-resonance"
    "dl-satan-observer"
    "dl-satan-intervention"
    "dl-satan-intervention-mark"
    "dl-satan-attribute"
    "dl-satan-attribute-listener"
    "dl-satan-audit-attribute"
    "dl-satan-audit-intervention"
    "dl-satan-patch-store"
    "dl-satan-patch-listener"
    "dl-satan-patch-runner"
    "dl-satan-tools-memory"
    "dl-satan-tools-patch"
    "dl-satan-tools-hippocampus")
  "Test-file stems (sans \"-test.el\") excluded from the default run.
These exercise SATAN's Postgres/daemon-backed subsystems and would
touch real state when run inside the live server.  Pass non-nil
INCLUDE-DB to `dl-test-run-suite' to run them anyway.")

(defun dl-test--file-p (name)
  "Non-nil when NAME (a basename) is an ERT test file."
  (and (string-suffix-p ".el" name)
       (or (string-suffix-p "-test.el" name)
           (string-prefix-p "test-" name))))

(defun dl-test--suite-files (include-db)
  "Absolute paths of test files to load.
Unless INCLUDE-DB, drop stems in `dl-test-db-excludes'."
  (let (files)
    (dolist (dir dl-test-suite-dirs)
      (let ((abs (expand-file-name dir user-emacs-directory)))
        (when (file-directory-p abs)
          (dolist (f (directory-files abs t "\\.el\\'"))
            (let* ((base (file-name-nondirectory f))
                   (stem (string-remove-suffix "-test" (file-name-base f))))
              (when (and (dl-test--file-p base)
                         (or include-db
                             (not (member stem dl-test-db-excludes))))
                (push f files)))))))
    (nreverse files)))

(defun dl-test-run-suite (&optional include-db)
  "Load and run the ERT suites, returning a one-line summary string.
Clears previously-defined tests first so only freshly-loaded files
run.  With INCLUDE-DB non-nil, also run the Postgres/daemon-backed
suites in `dl-test-db-excludes'."
  (ert-delete-all-tests)
  (let ((load-errors '()))
    (dolist (f (dl-test--suite-files include-db))
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
