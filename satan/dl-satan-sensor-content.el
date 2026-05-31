;;; dl-satan-sensor-content.el --- Content backlog probe — panopticon capture backlog -*- lexical-binding: t; -*-

;; Emits a `panopticon_content_backlog' sensor attribute signal when
;; uninspected panopticon page captures exist (DE-005 O2 / DR-005 §4.2).
;;
;; "Uninspected" means: captures whose `captured_at' is lexically newer
;; than the last time this probe advanced its watermark.
;;
;; THE DEC-5 DIVERGENCE FROM CURIOSITY: The watermark is the max
;; `captured_at' string seen verbatim (UTC-millis-Z), NOT a formatted
;; `now()'.  The broker passes its own timestamp in a different format
;; (local offset), so lexical comparison between the two formats is
;; meaningless.  Storing the high-water `captured_at' keeps every
;; comparison within one format.
;;
;; See DR-005 DEC-5, mem.pattern.satan.jsonl-arity-trap.

(require 'cl-lib)
(require 'json)
(require 'dl-satan-tools-content)          ; --read-articles-jsonl (lenient)

(declare-function dl-satan-attribute-build-sensor-payload "dl-satan-attribute")
(declare-function dl-satan-attribute-enqueue "dl-satan-attribute")

;; --- Defcustoms ------------------------------------------------

(defcustom dl-satan-sensor-content-state-file
  (expand-file-name "satan/sensor-content.json"
                    (or (getenv "XDG_STATE_HOME")
                        (expand-file-name ".local/state" "~")))
  "Path to the content-backlog probe state file.
Stores the last-inspected `captured_at' watermark string."
  :type 'string :group 'dl-satan-attribute)

(defcustom dl-satan-sensor-content-enabled t
  "When nil, the content-backlog probe does nothing."
  :type 'boolean :group 'dl-satan-attribute)

;; --- State file ------------------------------------------------

(defun dl-satan-sensor-content--read-state ()
  "Read state file, return plist (defaulting to empty watermark if absent)."
  (if (file-readable-p dl-satan-sensor-content-state-file)
      (condition-case nil
          (let ((raw (with-temp-buffer
                       (insert-file-contents dl-satan-sensor-content-state-file)
                       (json-parse-buffer :object-type 'plist))))
            raw)
        (error '(:last_inspected "")))
    '(:last_inspected "")))

(defun dl-satan-sensor-content--write-state (plist)
  "Write PLIST as JSON to state file."
  (let ((dir (file-name-directory dl-satan-sensor-content-state-file)))
    (unless (file-directory-p dir) (make-directory dir t))
    (with-temp-file dl-satan-sensor-content-state-file
      (insert (json-serialize plist)))))

(defun dl-satan-sensor-content--last-inspected ()
  "Return the last-inspected `captured_at' watermark string."
  (plist-get (dl-satan-sensor-content--read-state) :last_inspected))

(defun dl-satan-sensor-content-mark-inspected (high-water)
  "Advance the watermark to HIGH-WATER (a `captured_at' string verbatim).
HIGH-WATER must be the max `captured_at' seen, NOT a formatted now().
This is the DEC-5 divergence from curiosity's `mark-inspected'."
  (let ((state (dl-satan-sensor-content--read-state)))
    (dl-satan-sensor-content--write-state
     (plist-put state :last_inspected high-water))))

;; --- Capture counting ------------------------------------------

(defun dl-satan-sensor-content--count-uninspected (since-ts)
  "Count articles.jsonl rows with captured_at after SINCE-TS.
SINCE-TS is a `captured_at' watermark string (UTC-millis-Z).
Returns (COUNT . HIGH-WATER) where HIGH-WATER is the max captured_at seen.
Returns (0 . SINCE-TS) when no new captures or store is empty.
Uses the lenient JSONL reader (skips malformed lines per O-1)."
  (let ((articles (dl-satan-tools-content--read-articles-jsonl :skip-malformed t))
        (count 0)
        (high-water since-ts))
    (dolist (a articles)
      (let ((captured-at (plist-get a :captured_at)))
        (when (and captured-at (stringp captured-at))
          ;; Track the max captured_at for the watermark (DEC-5)
          (when (string< high-water captured-at)
            (setq high-water captured-at))
          ;; Count uninspected
          (when (string< since-ts captured-at)
            (cl-incf count)))))
    (cons count high-water)))

;; --- Probe -----------------------------------------------------

(cl-defun dl-satan-sensor-content-probe (&key run-id ts)
  "Check for uninspected panopticon content captures and emit signal if any.
Returns non-nil if a signal was emitted.
TS is the broker's `time_now' — used ONLY in the attribute payload, NOT
for the watermark (DEC-5: broker ts format ≠ captured_at format)."
  (condition-case err
      (when (and run-id
                 dl-satan-sensor-content-enabled
                 (bound-and-true-p dl-satan-attribute-updates-enabled))
        (let* ((last (dl-satan-sensor-content--last-inspected))
               (since (or last ""))       ; "" sorts before all timestamps
               (count-high (dl-satan-sensor-content--count-uninspected since))
               (count (car count-high))
               (high-water (cdr count-high)))
          (when (> count 0)
            (require 'dl-satan-attribute)
            (let ((payload (dl-satan-attribute-build-sensor-payload
                            :run-id run-id
                            :ts (or ts (format-time-string "%Y-%m-%dT%T%:z"))
                            :reason "content_backlog"
                            :sensor-type "panopticon_content_backlog"
                            :metric-value count
                            :metric-unit "uninspected_captures")))
              (dl-satan-attribute-enqueue payload)
              ;; DEC-5: advance watermark to max captured_at, NOT ts
              (dl-satan-sensor-content-mark-inspected high-water)
              t))))
    (error
     (message "[satan-sensor-content] probe soft-failed: %S" err)
     nil)))

(provide 'dl-satan-sensor-content)
;;; dl-satan-sensor-content.el ends here
