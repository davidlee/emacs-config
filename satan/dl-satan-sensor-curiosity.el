;;; dl-satan-sensor-curiosity.el --- Curiosity probe — panopticon segment backlog -*- lexical-binding: t; -*-

;; Emits a `segment_backlog' sensor attribute signal when uninspected
;; panopticon focus segments exist (design-contract §6S).
;;
;; "Uninspected" means: segments whose `end_ts' is newer than the last
;; time this probe ran.  Curiosity represents the gap between observable
;; and observed — the organism has unprocessed external signal.

(require 'cl-lib)
(require 'json)

(declare-function dl-satan-attribute-build-sensor-payload "dl-satan-attribute")
(declare-function dl-satan-attribute-enqueue "dl-satan-attribute")

(defcustom dl-satan-sensor-curiosity-state-file
  (expand-file-name "satan/sensor-curiosity.json"
                    (or (getenv "XDG_STATE_HOME")
                        (expand-file-name ".local/state" "~")))
  "Path to the curiosity probe state file.
Stores the last-inspected timestamp."
  :type 'string :group 'dl-satan-attribute)

(defcustom dl-satan-sensor-curiosity-segments-dir
  (expand-file-name "behaviour/segments"
                    (or (getenv "XDG_STATE_HOME")
                        (expand-file-name ".local/state" "~")))
  "Directory containing panopticon focus segment JSONL files."
  :type 'string :group 'dl-satan-attribute)

;; -----------------------------------------------------------------
;; state file
;; -----------------------------------------------------------------

(defun dl-satan-sensor-curiosity--read-state ()
  "Read state file, return plist or nil."
  (when (file-readable-p dl-satan-sensor-curiosity-state-file)
    (condition-case nil
        (let ((raw (with-temp-buffer
                     (insert-file-contents dl-satan-sensor-curiosity-state-file)
                     (json-parse-buffer :object-type 'plist))))
          raw)
      (error nil))))

(defun dl-satan-sensor-curiosity--write-state (plist)
  "Write PLIST as JSON to state file."
  (let ((dir (file-name-directory dl-satan-sensor-curiosity-state-file)))
    (unless (file-directory-p dir) (make-directory dir t))
    (with-temp-file dl-satan-sensor-curiosity-state-file
      (insert (json-serialize plist)))))

(defun dl-satan-sensor-curiosity--last-inspected ()
  "Return the last-inspected ISO timestamp string, or nil."
  (plist-get (dl-satan-sensor-curiosity--read-state) :last_inspected))

(defun dl-satan-sensor-curiosity-mark-inspected (&optional ts)
  "Update the last-inspected timestamp to TS (default: now)."
  (let ((state (or (dl-satan-sensor-curiosity--read-state) '()))
        (timestamp (or ts (format-time-string "%Y-%m-%dT%T%:z"))))
    (dl-satan-sensor-curiosity--write-state
     (plist-put state :last_inspected timestamp))))

;; -----------------------------------------------------------------
;; segment counting
;; -----------------------------------------------------------------

(defun dl-satan-sensor-curiosity--today-file ()
  "Return today's focus segment JSONL path."
  (expand-file-name
   (format "focus-%s.jsonl" (format-time-string "%Y-%m-%d"))
   dl-satan-sensor-curiosity-segments-dir))

(defun dl-satan-sensor-curiosity--count-uninspected (since-ts)
  "Count focus segments in today's file with end_ts after SINCE-TS.
SINCE-TS is an ISO timestamp string.  Returns count (integer)."
  (let ((file (dl-satan-sensor-curiosity--today-file))
        (count 0))
    (when (file-readable-p file)
      (with-temp-buffer
        (insert-file-contents file)
        (goto-char (point-min))
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (line-beginning-position) (line-end-position))))
            (unless (string-empty-p line)
              (condition-case nil
                  (let* ((obj (json-parse-string line :object-type 'plist))
                         (end-ts (plist-get obj :end_ts)))
                    (when (and end-ts (string< since-ts end-ts))
                      (cl-incf count)))
                (error nil))))
          (forward-line 1))))
    count))

;; -----------------------------------------------------------------
;; probe
;; -----------------------------------------------------------------

(cl-defun dl-satan-sensor-curiosity-probe (&key run-id ts)
  "Check for uninspected panopticon segments and emit signal if any.
Returns non-nil if a signal was emitted."
  (condition-case err
      (when (and run-id (bound-and-true-p dl-satan-attribute-updates-enabled))
        (let* ((last (dl-satan-sensor-curiosity--last-inspected))
               (since (or last "1970-01-01T00:00:00+00:00"))
               (count (dl-satan-sensor-curiosity--count-uninspected since)))
          (when (> count 0)
            (require 'dl-satan-attribute)
            (let ((payload (dl-satan-attribute-build-sensor-payload
                            :run-id run-id
                            :ts (or ts (format-time-string "%Y-%m-%dT%T%:z"))
                            :reason "segment_backlog"
                            :sensor-type "panopticon_backlog"
                            :metric-value count
                            :metric-unit "unprocessed_segments")))
              (dl-satan-attribute-enqueue payload)
              (dl-satan-sensor-curiosity-mark-inspected ts)
              t))))
    (error
     (message "[satan-sensor-curiosity] probe soft-failed: %S" err)
     nil)))

(provide 'dl-satan-sensor-curiosity)
;;; dl-satan-sensor-curiosity.el ends here
