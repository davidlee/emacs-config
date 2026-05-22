;;; dl-satan-sensor-alerts.el --- SATAN sensor freshness + loud failure -*- lexical-binding: t; -*-

;; Phase 4 of the perceptual-layer v0 (see docs/satan/perceptual-design.md
;; §S6, §7, §A15–A17).  Reads the `:sensor_status' plist returned by
;; `dl-satan-memory-evidence-assemble', renders the capsule sensor line,
;; and (Phase 4.3+) decides whether to dispatch a `notify_send' tool
;; call.  Dispatch and notified-state are wired in Phase 4.3; Phase 4.2
;; only owns the substrate + render.

(require 'cl-lib)
(require 'subr-x)

(defcustom dl-satan-sensor-state-file
  (expand-file-name "satan/notified.json"
                    (or (getenv "XDG_STATE_HOME")
                        (expand-file-name ".local/state" "~")))
  "Per-cause cooldown + dispatch state for sensor alerts.
Shared across runs; reads/writes go through tmp + rename for
atomicity.  Phase 4.3 introduces the producer/consumer of this
file; Phase 4.2 only reserves the path."
  :type 'file :group 'dl-satan)

;; ---------------------------------------------------------------------
;; Capsule render (§S6)
;; ---------------------------------------------------------------------

(defconst dl-satan-sensor--framing-key "sensor_block_header"
  "Framing.txt key supplying the sensor block's section header.
Owned by mind (`~/notes/satan/system/framing.txt'); when the key
is absent the block self-suppresses so a missing seed doesn't
block a run.")

(defconst dl-satan-sensor--source-order
  '(:current_window :focus :browser :bough)
  "Canonical render order for the four sensors.
Stable order keeps capsule diffs readable across runs even when
one source flips status.")

(defun dl-satan-sensor--source-label (key)
  "Return the short capsule label for source KEY."
  (pcase key
    (:current_window "current")
    (:focus          "focus")
    (:browser        "browser")
    (:bough          "bough")
    (_ (substring (symbol-name key) 1))))

(defun dl-satan-sensor--render-status (status)
  "Return the capsule-friendly rendering of a status string STATUS.
`ok' stays lowercase; degradations render uppercase so a glance
distinguishes them: `stale-28m' → `STALE(28m)', `missing' →
`MISSING', etc."
  (cond
   ((or (null status) (equal status "ok")) "ok")
   ((and (stringp status) (string-prefix-p "stale-" status))
    (format "STALE(%s)" (substring status 6)))
   ((stringp status) (upcase status))
   (t (format "%S" status))))

(defun dl-satan-sensor-render-block (framing sensor-status)
  "Return the rendered `# Sensors' block as a list of lines, or nil.
FRAMING is the parsed framing alist (from
`dl-satan-context--parse-framing'); SENSOR-STATUS is the plist
attached to the evidence window by Phase 4.1.

Self-suppresses (returns nil) when either the framing key or the
sensor-status plist is absent — same pattern as the other capsule
blocks (A6 / A8).  When rendered, emits a single line of the form
`sensors: current=ok focus=ok browser=ok bough=ok' regardless of
how many sources are degraded; constant shape keeps capsule diffs
diff-friendly."
  (let ((header (cdr (assoc dl-satan-sensor--framing-key framing))))
    (when (and header sensor-status)
      (let ((segments
             (mapcar
              (lambda (k)
                (format "%s=%s"
                        (dl-satan-sensor--source-label k)
                        (dl-satan-sensor--render-status
                         (plist-get sensor-status k))))
              dl-satan-sensor--source-order)))
        (list header
              (concat "sensors: "
                      (mapconcat #'identity segments " ")))))))

(provide 'dl-satan-sensor-alerts)
;;; dl-satan-sensor-alerts.el ends here
