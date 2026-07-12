;;; dl-sleipnir-doctor-test.el --- sleipnir-doctor ert -*- lexical-binding: t; -*-

;; Covers the sensor-freshness check added after the 1011m focus-sensor
;; incident (nightly segmentizing left the observer unable to confirm
;; intraday interventions; CHANGELOG 2026-05-29).  The check reuses the
;; evidence module's own status functions, so the tests drive it against
;; tmp fixtures with controlled mtimes / end_ts ages.
;;
;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/dev/satan/satan -L ~/.emacs.d/lisp \
;;     -L ~/.emacs.d/lisp/test \
;;     -l dl-sleipnir-doctor-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'satan-memory-evidence)
(require 'dl-sleipnir-doctor)

;; ---------------------------------------------------------------------
;; sensor-status->doctor — pure mapping
;; ---------------------------------------------------------------------

(ert-deftest dl-sleipnir-doctor/sensor-map-ok ()
  (should (equal "OK" (sleipnir-doctor--sensor-status->doctor "ok"))))

(ert-deftest dl-sleipnir-doctor/sensor-map-missing-is-warn ()
  (should (equal "WARN" (sleipnir-doctor--sensor-status->doctor "missing"))))

(ert-deftest dl-sleipnir-doctor/sensor-map-malformed-is-crit ()
  (should (equal "CRIT" (sleipnir-doctor--sensor-status->doctor "malformed"))))

(ert-deftest dl-sleipnir-doctor/sensor-map-stale-below-crit-is-warn ()
  (let ((sleipnir-doctor-sensor-stale-crit-minutes 120))
    (should (equal "WARN" (sleipnir-doctor--sensor-status->doctor "stale-30m")))))

(ert-deftest dl-sleipnir-doctor/sensor-map-stale-at-or-past-crit-is-crit ()
  ;; The reliably-red one: the 1011m incident must read CRIT, not WARN.
  (let ((sleipnir-doctor-sensor-stale-crit-minutes 120))
    (should (equal "CRIT" (sleipnir-doctor--sensor-status->doctor "stale-120m")))
    (should (equal "CRIT" (sleipnir-doctor--sensor-status->doctor "stale-1011m")))))

(ert-deftest dl-sleipnir-doctor/sensor-map-unknown-is-warn ()
  (should (equal "WARN" (sleipnir-doctor--sensor-status->doctor "weird"))))

;; ---------------------------------------------------------------------
;; satan-sensors — fixture-backed end-to-end
;; ---------------------------------------------------------------------

(defmacro dl-sleipnir-doctor-test--with-behaviour-dir (&rest body)
  "Eval BODY with `satan-tools-activity-dir' bound to a fresh tmp tree.
`segments/' and `current/' subdirs are created; the tree is deleted on
exit."
  (declare (indent 0))
  `(let* ((satan-tools-activity-dir
           (file-name-as-directory (make-temp-file "sleipnir-sensors-" t))))
     (unwind-protect
         (progn
           (make-directory (expand-file-name "segments" satan-tools-activity-dir) t)
           (make-directory (expand-file-name "current" satan-tools-activity-dir) t)
           ,@body)
       (delete-directory satan-tools-activity-dir t))))

(defun dl-sleipnir-doctor-test--iso (secs-ago)
  "ISO-8601 (local-offset) timestamp SECS-AGO seconds before now."
  (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                      (time-subtract (current-time) secs-ago)))

(defun dl-sleipnir-doctor-test--write-segment (kind end-secs-ago)
  "Write a single-line KIND segment for today ending END-SECS-AGO ago."
  (let ((path (expand-file-name
               (format "segments/%s-%s.jsonl" kind
                       (format-time-string "%Y-%m-%d"))
               satan-tools-activity-dir))
        (start (dl-sleipnir-doctor-test--iso (+ end-secs-ago 60)))
        (end (dl-sleipnir-doctor-test--iso end-secs-ago)))
    (with-temp-file path
      (insert (json-encode (list :start_ts start :end_ts end :app "x")) "\n"))
    path))

(defun dl-sleipnir-doctor-test--write-current (mtime-secs-ago)
  "Write current/sway.json with mtime MTIME-SECS-AGO seconds before now."
  (let ((path (expand-file-name "current/sway.json"
                                satan-tools-activity-dir)))
    (with-temp-file path
      (insert (json-encode (list :app "x" :title "y"))))
    (set-file-times path (time-subtract (current-time) mtime-secs-ago))
    path))

(defun dl-sleipnir-doctor-test--status ()
  "Run the sensors check and return its `status' field."
  (alist-get 'status (sleipnir-doctor--satan-sensors)))

(ert-deftest dl-sleipnir-doctor/sensors-all-fresh-is-ok ()
  (dl-sleipnir-doctor-test--with-behaviour-dir
    (dl-sleipnir-doctor-test--write-current 10)
    (dl-sleipnir-doctor-test--write-segment "focus" 10)
    (dl-sleipnir-doctor-test--write-segment "browser" 10)
    (should (equal "OK" (dl-sleipnir-doctor-test--status)))))

(ert-deftest dl-sleipnir-doctor/sensors-missing-feeds-warn ()
  ;; No files at all → focus/browser missing, current missing → WARN.
  (dl-sleipnir-doctor-test--with-behaviour-dir
    (should (equal "WARN" (dl-sleipnir-doctor-test--status)))))

(ert-deftest dl-sleipnir-doctor/sensors-deep-stale-focus-is-crit ()
  ;; The incident shape: current + browser fine, focus frozen for hours.
  (let ((sleipnir-doctor-sensor-stale-crit-minutes 120))
    (dl-sleipnir-doctor-test--with-behaviour-dir
      (dl-sleipnir-doctor-test--write-current 10)
      (dl-sleipnir-doctor-test--write-segment "browser" 10)
      (dl-sleipnir-doctor-test--write-segment "focus" (* 200 60))
      (should (equal "CRIT" (dl-sleipnir-doctor-test--status))))))

(ert-deftest dl-sleipnir-doctor/sensors-mild-stale-is-warn ()
  (let ((sleipnir-doctor-sensor-stale-crit-minutes 120)
        ;; segment-stale ceiling is 30m; 40m old → stale but well under crit.
        (satan-memory-evidence-segment-stale-seconds 1800))
    (dl-sleipnir-doctor-test--with-behaviour-dir
      (dl-sleipnir-doctor-test--write-current 10)
      (dl-sleipnir-doctor-test--write-segment "browser" 10)
      (dl-sleipnir-doctor-test--write-segment "focus" (* 40 60))
      (should (equal "WARN" (dl-sleipnir-doctor-test--status))))))

(provide 'dl-sleipnir-doctor-test)
;;; dl-sleipnir-doctor-test.el ends here
