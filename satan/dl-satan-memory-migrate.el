;;; dl-satan-memory-migrate.el --- SATAN memory migration runner -*- lexical-binding: t; -*-

;; Forward-only numbered SQL migrations for the `satan_memory' PG database.
;; Files live under `dl-satan-memory-migrate-directory' and match
;; `NNNN_<slug>.sql' (four-digit zero-padded version).  Applied state is
;; tracked in the target DB's `schema_migrations' table (created by
;; 0001_init.sql).  The runner refuses to apply a file unless its version
;; equals max(applied) + 1, and refuses to apply if a previously-applied
;; version's on-disk checksum no longer matches what was recorded.
;;
;; Implementation: subprocess to `psql' (R3 decided in memory.design.md
;; §6.1).  Each apply runs as a single transaction containing both the
;; migration body and the `schema_migrations' INSERT, so the bookkeeping
;; row cannot drift from the schema state.

(require 'cl-lib)

(defgroup dl-satan-memory nil
  "SATAN memory substrate."
  :group 'dl-satan)

(defcustom dl-satan-memory-migrate-directory
  (expand-file-name "satan/memory/migrations/" user-emacs-directory)
  "Directory containing migration files (`NNNN_<slug>.sql')."
  :type 'directory :group 'dl-satan-memory)

(defcustom dl-satan-memory-migrate-psql-program
  (or (executable-find "psql") "psql")
  "Path to the `psql' binary."
  :type 'string :group 'dl-satan-memory)

(defcustom dl-satan-memory-migrate-host "/run/postgresql"
  "Postgres host or socket directory."
  :type 'string :group 'dl-satan-memory)

(defcustom dl-satan-memory-migrate-database "satan_memory"
  "Default database for migration operations."
  :type 'string :group 'dl-satan-memory)

(defconst dl-satan-memory-migrate--filename-re
  "\\`\\([0-9]\\{4\\}\\)_[a-z0-9][a-z0-9_]*\\.sql\\'"
  "Strict matcher for migration filenames.")

;; ---------- helpers ----------

(defun dl-satan-memory-migrate--parse-filename (basename)
  "Return integer version for BASENAME, or signal `user-error'."
  (let ((case-fold-search nil))
    (if (string-match dl-satan-memory-migrate--filename-re basename)
        (string-to-number (match-string 1 basename))
      (user-error "Bad migration filename: %s" basename))))

(defun dl-satan-memory-migrate--checksum (path)
  "Return SHA-256 hex of PATH's contents."
  (with-temp-buffer
    (set-buffer-multibyte nil)
    (insert-file-contents-literally path)
    (secure-hash 'sha256 (current-buffer))))

(defun dl-satan-memory-migrate--list-files (&optional dir)
  "Return list of (:version V :filename F :path P) for migrations in DIR.
Sorted ascending by version.  Signals on version collision."
  (let* ((dir (or dir dl-satan-memory-migrate-directory))
         (files (and (file-directory-p dir)
                     (directory-files dir nil "\\`[^.].*\\.sql\\'")))
         (rows (mapcar
                (lambda (f)
                  (list :version (dl-satan-memory-migrate--parse-filename f)
                        :filename f
                        :path (expand-file-name f dir)))
                files))
         (sorted (sort rows (lambda (a b) (< (plist-get a :version)
                                             (plist-get b :version))))))
    ;; collision check
    (cl-loop for (a b) on sorted
             when (and b (= (plist-get a :version) (plist-get b :version)))
             do (user-error "Duplicate migration version %d (%s, %s)"
                            (plist-get a :version)
                            (plist-get a :filename)
                            (plist-get b :filename)))
    sorted))

(defun dl-satan-memory-migrate--psql (db args &optional input)
  "Run psql against DB with ARGS; optional INPUT string to stdin.
Return cons (ok . OUTPUT) or (error . MESSAGE)."
  (with-temp-buffer
    (let* ((full-args (append (list "-h" dl-satan-memory-migrate-host
                                    "-d" db
                                    "--no-psqlrc"
                                    "-v" "ON_ERROR_STOP=1")
                              args))
           (status (if input
                       (let ((in-buf (current-buffer)))
                         (with-temp-buffer
                           (insert input)
                           (apply #'call-process-region
                                  (point-min) (point-max)
                                  dl-satan-memory-migrate-psql-program
                                  nil in-buf nil full-args)))
                     (apply #'call-process
                            dl-satan-memory-migrate-psql-program
                            nil t nil full-args))))
      (if (and (integerp status) (zerop status))
          (cons 'ok (buffer-string))
        (cons 'error
              (format "psql exit %s on %s: %s"
                      status db (string-trim (buffer-string))))))))

(defun dl-satan-memory-migrate--applied (db)
  "Return applied rows from DB.schema_migrations as plists, sorted asc.
If the table does not exist, return nil."
  (let* ((result (dl-satan-memory-migrate--psql
                  db
                  (list "-A" "-t" "-F" "|" "-c"
                        (concat "SELECT version, filename, checksum "
                                "FROM schema_migrations ORDER BY version")))))
    (pcase result
      (`(ok . ,out)
       (cl-loop for line in (split-string (string-trim out) "\n" t)
                for parts = (split-string line "|")
                when (= (length parts) 3)
                collect (list :version (string-to-number (nth 0 parts))
                              :filename (nth 1 parts)
                              :checksum (nth 2 parts))))
      (`(error . ,msg)
       (if (string-match-p "relation \"schema_migrations\" does not exist" msg)
           nil
         (user-error "%s" msg))))))

(defun dl-satan-memory-migrate--sql-literal (s)
  "Quote S as a single-quoted SQL literal."
  (concat "'" (replace-regexp-in-string "'" "''" s) "'"))

(defun dl-satan-memory-migrate--apply-one (db row)
  "Apply ROW (plist :version :filename :path) to DB in one transaction.
Includes the body via \\i and inserts the schema_migrations bookkeeping
row in the same transaction."
  (let* ((version  (plist-get row :version))
         (filename (plist-get row :filename))
         (path     (plist-get row :path))
         (checksum (dl-satan-memory-migrate--checksum path))
         (script   (concat
                    (format "\\i %s\n" path)
                    (format "INSERT INTO schema_migrations (version, filename, checksum) VALUES (%d, %s, %s);\n"
                            version
                            (dl-satan-memory-migrate--sql-literal filename)
                            (dl-satan-memory-migrate--sql-literal checksum))))
         (result   (dl-satan-memory-migrate--psql
                    db (list "--single-transaction" "-f" "-") script)))
    (pcase result
      (`(ok . ,_) checksum)
      (`(error . ,msg) (user-error "Migration %d (%s) failed: %s"
                                   version filename msg)))))

;; ---------- public ----------

(defun dl-satan-memory-migrate-status (&optional db)
  "Return migration status against DB.
DB defaults to `dl-satan-memory-migrate-database'.
Result is a list of plists:
  (:version V :filename F :status STATUS :checksum C [:expected E])
STATUS is one of `applied', `pending', `tampered', `missing'.
- applied:  on-disk file matches the recorded checksum.
- pending:  on disk, not yet applied.
- tampered: applied checksum differs from on-disk checksum.
- missing:  recorded as applied but no on-disk file."
  (let* ((db        (or db dl-satan-memory-migrate-database))
         (files     (dl-satan-memory-migrate--list-files))
         (applied   (dl-satan-memory-migrate--applied db))
         (by-version (make-hash-table :test 'eql))
         (out '()))
    (dolist (a applied)
      (puthash (plist-get a :version) a by-version))
    (dolist (f files)
      (let* ((v (plist-get f :version))
             (cs (dl-satan-memory-migrate--checksum (plist-get f :path)))
             (rec (gethash v by-version))
             (status (cond
                      ((null rec) 'pending)
                      ((string= (plist-get rec :checksum) cs) 'applied)
                      (t 'tampered))))
        (push (list :version v
                    :filename (plist-get f :filename)
                    :status status
                    :checksum cs
                    :expected (and rec (plist-get rec :checksum)))
              out)
        (remhash v by-version)))
    ;; anything left in by-version is recorded but missing on disk
    (maphash
     (lambda (v rec)
       (push (list :version v
                   :filename (plist-get rec :filename)
                   :status 'missing
                   :checksum nil
                   :expected (plist-get rec :checksum))
             out))
     by-version)
    (sort out (lambda (a b) (< (plist-get a :version) (plist-get b :version))))))

(defun dl-satan-memory-migrate-apply (&optional db)
  "Apply pending migrations to DB.  Return list of applied versions.
Refuses if any migration is tampered or missing, or if pending versions
would skip (must be max(applied)+1, max+2, ...)."
  (let* ((db (or db dl-satan-memory-migrate-database))
         (status (dl-satan-memory-migrate-status db))
         (bad (cl-remove-if-not
               (lambda (e) (memq (plist-get e :status) '(tampered missing)))
               status)))
    (when bad
      (user-error "Cannot apply: %d migration(s) tampered/missing: %s"
                  (length bad)
                  (mapconcat (lambda (e) (format "%04d/%s"
                                                 (plist-get e :version)
                                                 (plist-get e :status)))
                             bad ", ")))
    (let* ((pending (cl-remove-if-not
                     (lambda (e) (eq (plist-get e :status) 'pending))
                     status))
           (applied-max (cl-loop for e in status
                                 when (eq (plist-get e :status) 'applied)
                                 maximize (plist-get e :version))))
      (cl-loop for entry in pending
               for expected = (1+ (or applied-max 0))
               for v = (plist-get entry :version)
               unless (= v expected)
               do (user-error
                   "Migration version gap: next applicable is %d but found %d (%s)"
                   expected v (plist-get entry :filename))
               do (setq applied-max v)
               collect (let* ((file (cl-find v (dl-satan-memory-migrate--list-files)
                                             :key (lambda (r) (plist-get r :version)))))
                        (dl-satan-memory-migrate--apply-one db file)
                        v)))))

;;;###autoload
(defun my/satan-memory-migrate (&optional db)
  "Apply pending SATAN memory migrations.  With prefix arg prompt for DB."
  (interactive
   (list (if current-prefix-arg
             (read-string "Database: " dl-satan-memory-migrate-database)
           dl-satan-memory-migrate-database)))
  (let ((applied (dl-satan-memory-migrate-apply db)))
    (message "satan_memory: applied %d migration(s) %s"
             (length applied) applied)))

;;;###autoload
(defun my/satan-memory-migrate-status (&optional db)
  "Print migration status for DB."
  (interactive
   (list (if current-prefix-arg
             (read-string "Database: " dl-satan-memory-migrate-database)
           dl-satan-memory-migrate-database)))
  (let ((status (dl-satan-memory-migrate-status db)))
    (with-output-to-temp-buffer "*satan-memory-migrate*"
      (princ (format "Database: %s\n\n" db))
      (princ (format "%-7s %-30s %-9s\n" "version" "filename" "status"))
      (princ (make-string 50 ?-)) (princ "\n")
      (dolist (e status)
        (princ (format "%-7d %-30s %-9s\n"
                       (plist-get e :version)
                       (plist-get e :filename)
                       (plist-get e :status)))))))

(provide 'dl-satan-memory-migrate)
;;; dl-satan-memory-migrate.el ends here
