;;; dl-satan-db.el --- shared psql subprocess runner -*- lexical-binding: t; -*-

;; Single entry point for psql subprocess calls within the SATAN broker.
;; Two surfaces:
;;
;;   dl-satan-db-query(db host program sql variables) → (ok . stdout) | (error . msg)
;;     For the common pattern: SQL + variable substitution → trimmed result.
;;     Always passes -q (quiet mode) so psql welcome-banner never leaks
;;     into stdout.
;;
;;   dl-satan-db-psql(db host program extra-flags &optional input) → (ok . stdout) | (error . msg)
;;     Thin wrapper for callers that need custom flags (--single-transaction,
;;     -c inline SQL, etc.).  Returns untrimmed stdout to match
;;     dl-satan-memory-migrate--psql semantics.

(require 'cl-lib)
(require 'subr-x)

(defgroup dl-satan-db nil
  "Shared psql subprocess runner for the SATAN broker."
  :group 'dl-satan)

(defcustom dl-satan-db-default-host "/run/postgresql"
  "Default Postgres host or socket directory."
  :type 'string :group 'dl-satan-db)

(defcustom dl-satan-db-default-program
  (or (executable-find "psql") "psql")
  "Default path to the `psql' binary."
  :type 'string :group 'dl-satan-db)

;; ---------------------------------------------------------------------
;; dl-satan-db-query — the common case (SQL + variables → trimmed result)
;; ---------------------------------------------------------------------

(defun dl-satan-db-query (db host program sql variables)
  "Run SQL against DB with VARIABLES (alist of NAME . VALUE) bound via -v.
Returns (ok . STDOUT-TRIMMED) or (error . MSG).

HOST and PROGRAM are explicit params so each module passes its own
defcustoms independently.  SQL is fed to psql on stdin via -f -
because -c does not perform variable substitution.  Field separator is
tab so multi-column SELECTs are unambiguous to parse.  Always passes
-q (quiet mode) so psql welcome-banner never leaks into stdout."
  (let* ((var-args (cl-loop for (k . v) in variables
                            append (list "-v"
                                         (format "%s=%s" k v))))
         (full-args (append (list "-h" host
                                  "-d" db
                                  "--no-psqlrc"
                                  "-X" "-A" "-t" "-q"
                                  "-F" "\t"
                                  "-v" "ON_ERROR_STOP=1")
                            var-args
                            (list "-f" "-"))))
    (with-temp-buffer
      (let* ((out-buf (current-buffer))
             (status
              (with-temp-buffer
                (insert sql)
                (apply #'call-process-region
                       (point-min) (point-max)
                       program
                       nil out-buf nil full-args))))
        (if (and (integerp status) (zerop status))
            (cons 'ok (string-trim (buffer-string)))
          (cons 'error (format "psql exit %s on %s: %s"
                                status db
                                (string-trim (buffer-string)))))))))

;; ---------------------------------------------------------------------
;; dl-satan-db-psql — thin wrapper for callers with custom flags
;; ---------------------------------------------------------------------

(defun dl-satan-db-psql (db host program extra-flags &optional input)
  "Run psql against DB with EXTRA-FLAGS appended after base args.
Optional INPUT string is fed to psql on stdin.  Returns untrimmed
(ok . STDOUT) or (error . MSG).

Base args are -h HOST -d DB --no-psqlrc -v ON_ERROR_STOP=1.
EXTRA-FLAGS is a list of strings (e.g. --single-transaction, -f -,
-c \"SELECT ...\").  When INPUT is non-nil, EXTRA-FLAGS should
include -f - so psql reads from stdin; otherwise include -c SQL."
  (with-temp-buffer
    (let* ((full-args (append (list "-h" host
                                     "-d" db
                                     "--no-psqlrc"
                                     "-v" "ON_ERROR_STOP=1")
                              extra-flags))
           (status (if input
                       (let ((out-buf (current-buffer)))
                         (with-temp-buffer
                           (insert input)
                           (apply #'call-process-region
                                  (point-min) (point-max)
                                  program
                                  nil out-buf nil full-args)))
                     (apply #'call-process
                            program
                            nil t nil full-args))))
      (if (and (integerp status) (zerop status))
          (cons 'ok (buffer-string))
        (cons 'error
              (format "psql exit %s on %s: %s"
                      status db (string-trim (buffer-string))))))))

(provide 'dl-satan-db)
;;; dl-satan-db.el ends here
