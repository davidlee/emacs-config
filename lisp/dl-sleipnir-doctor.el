;; -*- lexical-binding: t -*-

(require 'cl-lib)
(require 'json)
(require 'subr-x)

(declare-function satan-mode-check-tool-references "satan-mode" ())
(declare-function satan-budget-today-total "satan-budget" (runs-dir &optional time))
(declare-function satan-budget-exceeded-p "satan-budget" (runs-dir &optional time))
(declare-function satan-memory-store-recent "satan-memory-store" (&rest args))
(declare-function satan-broker-run-dirs-for-date "satan-broker" (runs-dir date-prefix))
(declare-function satan-broker--failure-streak-count "satan-broker" (runs-dir))
(declare-function satan-broker--run-id-from-leaf "satan-broker" (name))
(declare-function satan-patch-runner-active-p "satan-patch-runner" ())
(declare-function satan-patch-store-list "satan-patch-store" (&rest args))
(declare-function satan-memory-evidence--current-window-status "satan-memory-evidence" (path now))
(declare-function satan-memory-evidence--segments-status "satan-memory-evidence" (path start end limit now))
(declare-function eglot--managed-servers "eglot" ())
(declare-function jsonrpc-running-p "jsonrpc" (conn))

(defvar satan-runs-dir)
(defvar satan-budget-daily-tokens)
(defvar satan-patch-runner-enabled)
(defvar satan-patch-worktree-root)
(defvar satan-tools-activity-dir)
(defvar dl-notes-root)
(defvar dl-notes-inbox-file)
(defvar org-roam-db-location)
(defvar org-agenda-files)
(defvar my/org-agenda-combined-files)

;; ---------------------------------------------------------------------------
;; Infrastructure
;; ---------------------------------------------------------------------------

(defvar sleipnir-doctor--check-fns nil
  "Ordered alist of (NAME . FN) check pairs.")

(defcustom sleipnir-doctor-last-tick-warn-hours 2
  "Hours since last SATAN run before reporting WARN."
  :type 'number
  :group 'sleipnir-doctor)

(defcustom sleipnir-doctor-sensor-stale-crit-minutes 120
  "Minutes a panopticon sensor may be stale before CRIT (else WARN).
Below this a `stale-Nm' sensor reads WARN (transient capture lag); at
or beyond it the feed is treated as silent/broken — the failure mode
behind the 1011m focus-sensor incident, where nightly segmentizing
left the observer unable to confirm any intraday intervention."
  :type 'number
  :group 'sleipnir-doctor)

(defun sleipnir-doctor--check (category name status detail)
  "Build a check result alist."
  `((category . ,category) (name . ,name) (status . ,status) (detail . ,detail)))

(defun sleipnir-doctor--register (name fn)
  "Add FN under NAME to the check registry."
  (setq sleipnir-doctor--check-fns
        (append (cl-remove name sleipnir-doctor--check-fns :key #'car)
                (list (cons name fn)))))

(defun sleipnir-doctor--run-check (name fn)
  "Call FN, wrapping errors into a CRIT result.  Always returns a list."
  (condition-case err
      (let ((result (funcall fn)))
        (if (and (consp result) (assq 'category result))
            (list result)
          result))
    (error
     (list (sleipnir-doctor--check
            "Internal" (symbol-name name) "CRIT"
            (format "check error: %s" (error-message-string err)))))))

(defun sleipnir-doctor--human-duration (seconds)
  "Format SECONDS as compact human-readable duration."
  (cond
   ((< seconds 60)    (format "%ds ago" (round seconds)))
   ((< seconds 3600)  (format "%dm ago" (round (/ seconds 60.0))))
   ((< seconds 86400) (format "%.1fh ago" (/ seconds 3600.0)))
   (t                 (format "%.1fd ago" (/ seconds 86400.0)))))

(defun sleipnir-doctor--satan-available-p ()
  (and (featurep 'satan-broker) (boundp 'satan-runs-dir)))

(defun sleipnir-doctor--satan-patch-available-p ()
  (and (featurep 'satan-patch-store) (featurep 'satan-patch-runner)))

(defun sleipnir-doctor--sensors-available-p ()
  (and (featurep 'satan-memory-evidence)
       (boundp 'satan-tools-activity-dir)))

;; ---------------------------------------------------------------------------
;; Emacs core
;; ---------------------------------------------------------------------------

(defun sleipnir-doctor--emacs-server ()
  (sleipnir-doctor--check "Emacs" "server" "OK"
                          (format "pid %d, uptime %s"
                                  (emacs-pid) (emacs-uptime))))

(defun sleipnir-doctor--lsp-status ()
  "Check eglot workspace health if available."
  (if (not (fboundp 'eglot--managed-servers))
      (sleipnir-doctor--check "Emacs" "LSP" "OK" "eglot not loaded")
    (let* ((servers (eglot--managed-servers))
           (n (length servers))
           (dead (cl-count-if-not #'jsonrpc-running-p servers)))
      (cond
       ((= n 0)
        (sleipnir-doctor--check "Emacs" "LSP" "OK" "no active servers"))
       ((> dead 0)
        (sleipnir-doctor--check "Emacs" "LSP" "WARN"
                                (format "%d/%d servers dead" dead n)))
       (t
        (sleipnir-doctor--check "Emacs" "LSP" "OK"
                                (format "%d servers" n)))))))

;; ---------------------------------------------------------------------------
;; SATAN runtime
;; ---------------------------------------------------------------------------

(defun sleipnir-doctor--satan-mode-registry ()
  (if (not (fboundp 'satan-mode-check-tool-references))
      (sleipnir-doctor--check "SATAN" "mode-registry" "OK" "not loaded")
    (condition-case err
        (progn
          (satan-mode-check-tool-references)
          (sleipnir-doctor--check "SATAN" "mode-registry" "OK" "consistent"))
      (error
       (sleipnir-doctor--check "SATAN" "mode-registry" "CRIT"
                               (error-message-string err))))))

(defun sleipnir-doctor--satan-budget ()
  (if (not (and (fboundp 'satan-budget-today-total)
                (fboundp 'satan-budget-exceeded-p)))
      (sleipnir-doctor--check "SATAN" "budget" "OK" "not loaded")
    (let* ((total (satan-budget-today-total satan-runs-dir))
           (exceeded (satan-budget-exceeded-p satan-runs-dir))
           (ceiling (and (boundp 'satan-budget-daily-tokens)
                         satan-budget-daily-tokens)))
      (sleipnir-doctor--check
       "SATAN" "budget"
       (if exceeded "WARN" "OK")
       (if ceiling
           (format "%dk/%dk tokens (%d%%)"
                   (/ total 1000) (/ ceiling 1000)
                   (round (* 100.0 (/ (float total) (max ceiling 1)))))
         (format "%dk tokens (no ceiling)" (/ total 1000)))))))

(defun sleipnir-doctor--satan-memory-db ()
  (if (not (fboundp 'satan-memory-store-recent))
      (sleipnir-doctor--check "SATAN" "memory-db" "OK" "not loaded")
    (let ((result (satan-memory-store-recent :limit 1)))
      (pcase (car result)
        ('ok    (sleipnir-doctor--check "SATAN" "memory-db" "OK" "connected"))
        ('error (sleipnir-doctor--check "SATAN" "memory-db" "CRIT"
                                        (format "query failed: %s" (cdr result))))
        (_      (sleipnir-doctor--check "SATAN" "memory-db" "WARN"
                                        (format "unexpected: %S" (car result))))))))

(defun sleipnir-doctor--satan-today-runs ()
  (if (not (sleipnir-doctor--satan-available-p))
      (sleipnir-doctor--check "SATAN" "today-runs" "OK" "not loaded")
    (let* ((prefix (format-time-string "%Y%m%dT"))
           (dirs (satan-broker-run-dirs-for-date satan-runs-dir prefix))
           (total (length dirs))
           (failed (cl-count-if
                    (lambda (d)
                      (string-suffix-p ".FAILED" (file-name-nondirectory d)))
                    dirs))
           (succeeded (- total failed))
           (pct (if (> total 0)
                    (round (* 100.0 (/ (float succeeded) total)))
                  100)))
      (sleipnir-doctor--check
       "SATAN" "today-runs"
       (cond ((= total 0) "OK")
             ((> (/ (float failed) total) 0.5) "CRIT")
             ((> failed 0) "WARN")
             (t "OK"))
       (format "%d runs, %d ok, %d failed (%d%%)" total succeeded failed pct)))))

(defun sleipnir-doctor--satan-failure-streak ()
  (if (not (fboundp 'satan-broker--failure-streak-count))
      (sleipnir-doctor--check "SATAN" "failure-streak" "OK" "not loaded")
    (let ((streak (satan-broker--failure-streak-count satan-runs-dir)))
      (sleipnir-doctor--check
       "SATAN" "failure-streak"
       (cond ((>= streak 5) "CRIT")
             ((>= streak 3) "WARN")
             (t "OK"))
       (format "%d consecutive" streak)))))

(defun sleipnir-doctor--satan-last-tick ()
  (if (not (sleipnir-doctor--satan-available-p))
      (sleipnir-doctor--check "SATAN" "last-tick" "OK" "not loaded")
    (let* ((link (expand-file-name "most-recent" satan-runs-dir))
           (target (and (file-symlink-p link)
                        (file-name-nondirectory
                         (directory-file-name (file-truename link)))))
           (run-id (and target
                        (if (fboundp 'satan-broker--run-id-from-leaf)
                            (satan-broker--run-id-from-leaf target)
                          target)))
           (ts (and run-id
                    (string-match
                     "\\`\\([0-9]\\{4\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)T\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)\\([0-9]\\{2\\}\\)"
                     run-id)
                    (encode-time
                     (string-to-number (match-string 6 run-id))
                     (string-to-number (match-string 5 run-id))
                     (string-to-number (match-string 4 run-id))
                     (string-to-number (match-string 3 run-id))
                     (string-to-number (match-string 2 run-id))
                     (string-to-number (match-string 1 run-id)))))
           (age-secs (and ts (float-time (time-subtract nil ts))))
           (threshold (* sleipnir-doctor-last-tick-warn-hours 3600)))
      (cond
       ((null ts)
        (sleipnir-doctor--check "SATAN" "last-tick" "WARN" "no runs found"))
       (t
        (sleipnir-doctor--check
         "SATAN" "last-tick"
         (if (> age-secs threshold) "WARN" "OK")
         (sleipnir-doctor--human-duration age-secs)))))))

(defun sleipnir-doctor--sensor-status->doctor (status)
  "Map an evidence sensor STATUS string to a doctor status string.
STATUS is the §S6 vocabulary: `\"ok\"' / `\"stale-Nm\"' / `\"missing\"'
/ `\"malformed\"'.  Staleness past
`sleipnir-doctor-sensor-stale-crit-minutes' escalates WARN→CRIT so a
silently-frozen feed (not mere capture lag) trips the louder signal."
  (cond
   ((equal status "ok") "OK")
   ((equal status "malformed") "CRIT")
   ((equal status "missing") "WARN")
   ((and (stringp status)
         (string-match "\\`stale-\\([0-9]+\\)m\\'" status))
    (if (>= (string-to-number (match-string 1 status))
            sleipnir-doctor-sensor-stale-crit-minutes)
        "CRIT" "WARN"))
   (t "WARN")))

(defun sleipnir-doctor--satan-sensors ()
  "Probe panopticon sensor freshness via the evidence status functions.
Catches both staleness (`stale-Nm') and silence (`missing'/`malformed')
of the current-window file and today's focus/browser segment feeds —
the inputs the observer gates classification on (§S6).  Reuses the same
status code the assembler runs, so the doctor sees exactly what the
classifier would.  Worst sensor sets the overall status."
  (if (not (sleipnir-doctor--sensors-available-p))
      (sleipnir-doctor--check "SATAN" "sensors" "OK" "not loaded")
    (let* ((now (current-time))
           (root satan-tools-activity-dir)
           (today (format-time-string "%Y-%m-%d" now))
           ;; Wide window: segment freshness is decided on the newest
           ;; entry's age, independent of these bounds; they only shape
           ;; the (discarded) filtered tail on an `ok' probe.
           (start "1970-01-01T00:00:00Z")
           (end (format-time-string "%Y-%m-%dT%H:%M:%S%z" now))
           (probes
            (list
             (cons "current"
                   (car (satan-memory-evidence--current-window-status
                         (expand-file-name "current/sway.json" root) now)))
             (cons "focus"
                   (car (satan-memory-evidence--segments-status
                         (expand-file-name
                          (format "segments/focus-%s.jsonl" today) root)
                         start end 1 now)))
             (cons "browser"
                   (car (satan-memory-evidence--segments-status
                         (expand-file-name
                          (format "segments/browser-%s.jsonl" today) root)
                         start end 1 now)))))
           (statuses (mapcar (lambda (p)
                               (sleipnir-doctor--sensor-status->doctor (cdr p)))
                             probes))
           (overall (cond ((member "CRIT" statuses) "CRIT")
                          ((member "WARN" statuses) "WARN")
                          (t "OK"))))
      (sleipnir-doctor--check
       "SATAN" "sensors" overall
       (mapconcat (lambda (p) (format "%s=%s" (car p) (cdr p)))
                  probes ", ")))))

;; ---------------------------------------------------------------------------
;; SATAN patch pipeline
;; ---------------------------------------------------------------------------

(defun sleipnir-doctor--patch-runner ()
  (if (not (sleipnir-doctor--satan-patch-available-p))
      (sleipnir-doctor--check "Patch" "runner" "OK" "not loaded")
    (let* ((enabled (and (boundp 'satan-patch-runner-enabled)
                         satan-patch-runner-enabled))
           (active (and (fboundp 'satan-patch-runner-active-p)
                        (satan-patch-runner-active-p))))
      (sleipnir-doctor--check
       "Patch" "runner" "OK"
       (format "%s%s"
               (if enabled "enabled" "disabled")
               (if active (format ", active: %s" active) ""))))))

(defun sleipnir-doctor--patch-queue ()
  (if (not (fboundp 'satan-patch-store-list))
      (sleipnir-doctor--check "Patch" "queue" "OK" "not loaded")
    (let ((result (satan-patch-store-list :state "queued")))
      (pcase (car result)
        ('ok
         (let ((n (length (cdr result))))
           (sleipnir-doctor--check "Patch" "queue"
                                   (if (> n 5) "WARN" "OK")
                                   (format "%d queued" n))))
        ('error
         (sleipnir-doctor--check "Patch" "queue" "CRIT"
                                 (format "query failed: %s" (cdr result))))))))

(defun sleipnir-doctor--patch-pending-review ()
  (if (not (fboundp 'satan-patch-store-list))
      (sleipnir-doctor--check "Patch" "pending-review" "OK" "not loaded")
    (let ((result (satan-patch-store-list :state "needs_review")))
      (pcase (car result)
        ('ok
         (let ((n (length (cdr result))))
           (sleipnir-doctor--check "Patch" "pending-review"
                                   (if (> n 0) "WARN" "OK")
                                   (format "%d awaiting review" n))))
        ('error
         (sleipnir-doctor--check "Patch" "pending-review" "CRIT"
                                 (format "query failed: %s" (cdr result))))))))

(defun sleipnir-doctor--patch-worktrees ()
  (if (not (and (boundp 'satan-patch-worktree-root)
                (file-directory-p satan-patch-worktree-root)))
      (sleipnir-doctor--check "Patch" "worktrees" "OK" "not configured")
    (let* ((entries (directory-files satan-patch-worktree-root nil "\\`[^.]"))
           (dirs (cl-remove-if-not
                  (lambda (e)
                    (file-directory-p
                     (expand-file-name e satan-patch-worktree-root)))
                  entries))
           (n (length dirs)))
      (sleipnir-doctor--check "Patch" "worktrees"
                              (if (> n 3) "WARN" "OK")
                              (format "%d active" n)))))

;; ---------------------------------------------------------------------------
;; Org / Notes
;; ---------------------------------------------------------------------------

(defun sleipnir-doctor--org-notes-root ()
  (if (not (boundp 'dl-notes-root))
      (sleipnir-doctor--check "Org" "notes-root" "WARN" "dl-notes-root not defined")
    (sleipnir-doctor--check
     "Org" "notes-root"
     (if (file-directory-p dl-notes-root) "OK" "CRIT")
     (if (file-directory-p dl-notes-root)
         dl-notes-root
       (format "missing: %s" dl-notes-root)))))

(defun sleipnir-doctor--org-roam-db ()
  (let ((db (cond
             ((and (boundp 'org-roam-db-location)
                   (stringp org-roam-db-location))
              org-roam-db-location)
             ((boundp 'dl-notes-root)
              (expand-file-name ".org-roam.db" dl-notes-root)))))
    (cond
     ((null db)
      (sleipnir-doctor--check "Org" "roam-db" "OK" "not configured"))
     ((not (file-exists-p db))
      (sleipnir-doctor--check "Org" "roam-db" "CRIT" "db file missing"))
     (t
      (let ((age-secs (float-time
                       (time-subtract
                        nil (file-attribute-modification-time
                             (file-attributes db))))))
        (sleipnir-doctor--check
         "Org" "roam-db"
         (if (> age-secs 86400) "WARN" "OK")
         (sleipnir-doctor--human-duration age-secs)))))))

(defun sleipnir-doctor--org-agenda-files ()
  (let* ((files (cond
                 ((and (boundp 'my/org-agenda-combined-files)
                       my/org-agenda-combined-files)
                  my/org-agenda-combined-files)
                 ((and (boundp 'org-agenda-files) (listp org-agenda-files))
                  org-agenda-files)))
         (n (length files)))
    (sleipnir-doctor--check "Org" "agenda-files"
                            (if (= n 0) "WARN" "OK")
                            (format "%d files" n))))

(defun sleipnir-doctor--org-inbox ()
  (if (not (boundp 'dl-notes-inbox-file))
      (sleipnir-doctor--check "Org" "inbox" "WARN" "dl-notes-inbox-file not defined")
    (sleipnir-doctor--check
     "Org" "inbox"
     (if (file-exists-p dl-notes-inbox-file) "OK" "CRIT")
     (if (file-exists-p dl-notes-inbox-file)
         (file-name-nondirectory dl-notes-inbox-file)
       (format "missing: %s" dl-notes-inbox-file)))))

;; ---------------------------------------------------------------------------
;; Registry + entry points
;; ---------------------------------------------------------------------------

(sleipnir-doctor--register 'emacs-server    #'sleipnir-doctor--emacs-server)
(sleipnir-doctor--register 'lsp             #'sleipnir-doctor--lsp-status)
(sleipnir-doctor--register 'satan-modes     #'sleipnir-doctor--satan-mode-registry)
(sleipnir-doctor--register 'satan-budget    #'sleipnir-doctor--satan-budget)
(sleipnir-doctor--register 'satan-memory    #'sleipnir-doctor--satan-memory-db)
(sleipnir-doctor--register 'satan-runs      #'sleipnir-doctor--satan-today-runs)
(sleipnir-doctor--register 'satan-streak    #'sleipnir-doctor--satan-failure-streak)
(sleipnir-doctor--register 'satan-tick      #'sleipnir-doctor--satan-last-tick)
(sleipnir-doctor--register 'satan-sensors   #'sleipnir-doctor--satan-sensors)
(sleipnir-doctor--register 'patch-runner    #'sleipnir-doctor--patch-runner)
(sleipnir-doctor--register 'patch-queue     #'sleipnir-doctor--patch-queue)
(sleipnir-doctor--register 'patch-review    #'sleipnir-doctor--patch-pending-review)
(sleipnir-doctor--register 'patch-worktrees #'sleipnir-doctor--patch-worktrees)
(sleipnir-doctor--register 'org-notes-root  #'sleipnir-doctor--org-notes-root)
(sleipnir-doctor--register 'org-roam-db     #'sleipnir-doctor--org-roam-db)
(sleipnir-doctor--register 'org-agenda      #'sleipnir-doctor--org-agenda-files)
(sleipnir-doctor--register 'org-inbox       #'sleipnir-doctor--org-inbox)

(defun sleipnir-doctor-checks ()
  "Return JSON array of health checks for sleipnir-doctor."
  (let (all-checks)
    (dolist (entry sleipnir-doctor--check-fns)
      (let ((results (sleipnir-doctor--run-check (car entry) (cdr entry))))
        (setq all-checks (nconc all-checks results))))
    (json-encode all-checks)))

(defun sleipnir-doctor-check-one (name)
  "Run a single registered check by NAME and display the result."
  (interactive
   (list (intern (completing-read
                  "Check: "
                  (mapcar (lambda (e) (symbol-name (car e)))
                          sleipnir-doctor--check-fns)
                  nil t))))
  (let* ((entry (assq name sleipnir-doctor--check-fns))
         (results (if entry
                      (sleipnir-doctor--run-check name (cdr entry))
                    (list (sleipnir-doctor--check
                           "Internal" (symbol-name name) "CRIT"
                           "unknown check")))))
    (message "%s" (json-encode results))))

(provide 'dl-sleipnir-doctor)
