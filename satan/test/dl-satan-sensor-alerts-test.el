;;; dl-satan-sensor-alerts-test.el --- sensor-alerts ert -*- lexical-binding: t; -*-

;; Phase 4 of perceptual-layer v0.  4.2 covers the capsule render; 4.3
;; will extend this file with cooldown + dispatch tests (A15–A17).

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-sensor-alerts)
(require 'dl-satan-context)

;; ---------------------------------------------------------------------
;; --render-status (pure)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-sensor/render-status-ok ()
  (should (equal "ok" (dl-satan-sensor--render-status "ok"))))

(ert-deftest dl-satan-sensor/render-status-stale ()
  (should (equal "STALE(28m)"
                 (dl-satan-sensor--render-status "stale-28m"))))

(ert-deftest dl-satan-sensor/render-status-missing-uppercased ()
  (should (equal "MISSING" (dl-satan-sensor--render-status "missing"))))

(ert-deftest dl-satan-sensor/render-status-unreachable-uppercased ()
  (should (equal "UNREACHABLE"
                 (dl-satan-sensor--render-status "unreachable"))))

(ert-deftest dl-satan-sensor/render-status-nil ()
  (should (equal "ok" (dl-satan-sensor--render-status nil))))

;; ---------------------------------------------------------------------
;; --render-block
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-sensor/render-block-all-ok ()
  (let* ((framing '(("sensor_block_header" . "# Sensors")))
         (ss (list :current_window "ok" :focus "ok"
                   :browser "ok" :bough "ok"))
         (lines (dl-satan-sensor-render-block framing ss)))
    (should (equal (car lines) "# Sensors"))
    (should (equal (cadr lines)
                   "sensors: current=ok focus=ok browser=ok bough=ok"))))

(ert-deftest dl-satan-sensor/render-block-mixed-degradation ()
  (let* ((framing '(("sensor_block_header" . "# Sensors")))
         (ss (list :current_window "stale-28m" :focus "ok"
                   :browser "missing" :bough "unreachable"))
         (lines (dl-satan-sensor-render-block framing ss)))
    (should (equal (cadr lines)
                   "sensors: current=STALE(28m) focus=ok browser=MISSING bough=UNREACHABLE"))))

(ert-deftest dl-satan-sensor/render-block-nil-when-no-header ()
  "Self-suppress when framing.txt is missing the seed key."
  (let ((framing '(("now" . "# Now"))))
    (should-not (dl-satan-sensor-render-block
                 framing
                 (list :current_window "ok" :focus "ok"
                       :browser "ok" :bough "ok")))))

(ert-deftest dl-satan-sensor/render-block-nil-when-no-status ()
  (let ((framing '(("sensor_block_header" . "# Sensors"))))
    (should-not (dl-satan-sensor-render-block framing nil))))

;; ---------------------------------------------------------------------
;; --with-prepare mirrors :sensor_status (Phase 4.2)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-sensor/with-prepare-mirrors-sensor-status ()
  (let* ((prepare (list :run_id "r" :time_now "t"
                        :sensor_status (list :current_window "stale-28m"
                                             :focus "ok"
                                             :browser "ok"
                                             :bough "unreachable")))
         (bundle (dl-satan-context--with-prepare (list :mode "tick-pulse") prepare)))
    (should (equal "stale-28m"
                   (plist-get (plist-get bundle :sensor_status)
                              :current_window)))
    (should (equal "unreachable"
                   (plist-get (plist-get bundle :sensor_status)
                              :bough)))))

(provide 'dl-satan-sensor-alerts-test)
;;; dl-satan-sensor-alerts-test.el ends here
