;;; dl-satan-percept-test.el --- percept skeleton ert -*- lexical-binding: t; -*-

;; Phase 1 of perceptual-design.md.  Covers:
;;
;;   A1   percept.json written next to bundle.json each run
;;   A2   bundle.json + percept.json share run_id + time_now
;;   A3   byte-identical re-runs on frozen sensor + frozen time_now
;;   A4   capsule contains a percept block (resonance / motive deferred)
;;   A6   no rendering of absent handles
;;
;; Sensor surface is quarantined the same way `dl-satan-memory-evidence-test'
;; does it: `:behaviour_dir' points at a tmp tree, `dl-satan-bough-program'
;; points at a non-existent path so bough calls return nil without
;; touching the user's real bough store.

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'dl-satan-percept)
(require 'dl-satan-memory-grammar)
(require 'dl-satan-audit)

(defmacro dl-satan-percept-test--with-fixture (vars &rest body)
  "Bind VARS plist `(:tmp :behaviour :run-dir)' to a fresh tmp tree.
BODY runs with `dl-satan-bough-program' shunted to /nonexistent/ so
bough probes return nil.  TMP cleaned up on exit."
  (declare (indent 1))
  (let ((tmp (plist-get vars :tmp))
        (behaviour (plist-get vars :behaviour))
        (run-dir (plist-get vars :run-dir)))
    `(let* ((,tmp (make-temp-file "satan-percept-test-" t))
            (,behaviour (file-name-as-directory
                         (expand-file-name "behaviour" ,tmp)))
            (,run-dir (file-name-as-directory
                       (expand-file-name "run" ,tmp))))
       (unwind-protect
           (let ((dl-satan-bough-program "/nonexistent/bough"))
             (make-directory ,behaviour t)
             (make-directory ,run-dir t)
             ,@body)
         (delete-directory ,tmp t)))))

(defun dl-satan-percept-test--write-sway (behaviour app)
  "Write a `current/sway.json' under BEHAVIOUR with APP as `app_id'."
  (let ((dir (expand-file-name "current" behaviour)))
    (make-directory dir t)
    (with-temp-file (expand-file-name "sway.json" dir)
      (insert (format "{\"app_id\":\"%s\",\"workspace\":\"main\"}" app)))))

(defun dl-satan-percept-test--prepare (run-id time-now)
  "Return a minimal prepare run_ctx plist for RUN-ID + TIME-NOW.
Mirrors `dl-satan-broker--prepare' shape so callers don't have to
import the broker just to fake a run."
  (list :run_id run-id
        :time_now time-now
        :start_time (current-time)
        :evidence nil :percept nil
        :sensor_status nil :pre_spawn nil :motive nil))

;; ---------------------------------------------------------------------
;; Build
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-percept/build-returns-shape ()
  "Build returns the documented plist shape with run_id + time_now
mirrored from PREPARE and the canon's emitted handles."
  (dl-satan-percept-test--with-fixture (:tmp tmp :behaviour beh :run-dir rd)
    (dl-satan-percept-test--write-sway beh "firefox")
    (let* ((prepare (dl-satan-percept-test--prepare
                     "20260519T100000-motd-aaaaaa"
                     "2026-05-19T10:00:00+10:00"))
           (mode '(:name "motd"))
           (percept (dl-satan-percept-build
                     prepare mode
                     (list :behaviour_dir beh :cwd tmp))))
      (should (equal (plist-get percept :run_id) (plist-get prepare :run_id)))
      (should (equal (plist-get percept :time_now)
                     (plist-get prepare :time_now)))
      (should (equal (plist-get percept :mode) "motd"))
      (should (= (plist-get percept :grammar_version)
                 dl-satan-memory-grammar-current-version))
      (should (member "app:firefox" (plist-get percept :handles)))
      (should (member "surface:browser" (plist-get percept :handles)))
      (should (member "mode:motd" (plist-get percept :handles)))
      ;; handle_sources mirrors handles ordering, one plist per handle.
      (let* ((handles (plist-get percept :handles))
             (sources (plist-get percept :handle_sources)))
        (should (= (length handles) (length sources)))
        (cl-loop for h in handles
                 for s in sources
                 do (should (equal (plist-get s :handle) h))
                 do (should (stringp (plist-get s :rule_id))))))))

(ert-deftest dl-satan-percept/build-handles-are-sorted ()
  "Canon already sorts; build must preserve it so json-encode output
is deterministic across runs (A3)."
  (dl-satan-percept-test--with-fixture (:tmp tmp :behaviour beh :run-dir rd)
    (dl-satan-percept-test--write-sway beh "emacs")
    (let* ((prepare (dl-satan-percept-test--prepare
                     "rid" "2026-05-19T10:00:00+10:00"))
           (percept (dl-satan-percept-build
                     prepare '(:name "motd")
                     (list :behaviour_dir beh :cwd tmp)))
           (handles (plist-get percept :handles)))
      (should (equal handles (sort (copy-sequence handles) #'string<))))))

(ert-deftest dl-satan-percept/build-empty-sources-yields-only-ctx-handles ()
  "With no panopticon / git / fs / hints, canon still emits ctx-derived
handles (mode, day, week).  A6 — these are present-because-emitted,
not absent-because-padded."
  (dl-satan-percept-test--with-fixture (:tmp tmp :behaviour beh :run-dir rd)
    (let* ((prepare (dl-satan-percept-test--prepare
                     "rid" "2026-05-19T10:00:00+10:00"))
           (percept (dl-satan-percept-build
                     prepare '(:name "motd")
                     (list :behaviour_dir beh :cwd "/nonexistent/dir/")))
           (handles (plist-get percept :handles)))
      (should (member "mode:motd" handles))
      (should (member "day:2026-05-19" handles))
      (should (member "week:2026-W21" handles))
      ;; A6: no absence rendering.  Canon never emits `surface:unknown'
      ;; or `app:none' — this just guards against accidental rule changes.
      (should-not (cl-some (lambda (h)
                             (string-match-p ":\\(none\\|unknown\\)\\'" h))
                           handles)))))

;; ---------------------------------------------------------------------
;; Persist (A1)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-percept/persist-writes-percept-json ()
  "A1 — `percept.json' lands under the run dir; JSON parseable; carries
the same run_id + time_now as the source plist."
  (dl-satan-percept-test--with-fixture (:tmp tmp :behaviour beh :run-dir rd)
    (dl-satan-percept-test--write-sway beh "firefox")
    (let* ((prepare (dl-satan-percept-test--prepare
                     "20260519T100000-motd-ffeeaa"
                     "2026-05-19T10:00:00+10:00"))
           (percept (dl-satan-percept-build
                     prepare '(:name "motd")
                     (list :behaviour_dir beh :cwd rd)))
           (path (dl-satan-percept-persist rd percept))
           (got (with-temp-buffer
                  (insert-file-contents path)
                  (goto-char (point-min))
                  (json-parse-buffer :object-type 'plist
                                     :array-type 'list
                                     :null-object :null
                                     :false-object :false))))
      (should (equal (file-name-nondirectory path) "percept.json"))
      (should (equal (plist-get got :run_id) (plist-get prepare :run_id)))
      (should (equal (plist-get got :time_now)
                     (plist-get prepare :time_now)))
      (should (member "app:firefox" (plist-get got :handles))))))

;; ---------------------------------------------------------------------
;; Determinism (A3)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-percept/byte-identical-rerun-on-frozen-inputs ()
  "A3 — two builds over the same frozen sensor fixture + frozen
time_now produce byte-identical `percept.json' encodings.

The percept persist path uses `dl-satan-audit--write-json' which
canonicalizes via `dl-satan-jsonl-prepare' before serializing, so
re-emitted JSON is comparable byte-for-byte."
  (dl-satan-percept-test--with-fixture (:tmp tmp :behaviour beh :run-dir rd)
    (dl-satan-percept-test--write-sway beh "firefox")
    (let* ((prepare (dl-satan-percept-test--prepare
                     "20260519T100000-motd-ffeeaa"
                     "2026-05-19T10:00:00+10:00"))
           (opts (list :behaviour_dir beh :cwd rd))
           (one (dl-satan-percept-build prepare '(:name "motd") opts))
           (two (dl-satan-percept-build prepare '(:name "motd") opts))
           (path-one (expand-file-name "one.json" rd))
           (path-two (expand-file-name "two.json" rd)))
      (dl-satan-audit--write-json path-one one)
      (dl-satan-audit--write-json path-two two)
      (let ((bytes-one (with-temp-buffer
                         (set-buffer-multibyte nil)
                         (insert-file-contents-literally path-one)
                         (buffer-string)))
            (bytes-two (with-temp-buffer
                         (set-buffer-multibyte nil)
                         (insert-file-contents-literally path-two)
                         (buffer-string))))
        (should (equal bytes-one bytes-two))))))

;; ---------------------------------------------------------------------
;; Render block (A4 / A6)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-percept/render-block-uses-framing-header ()
  "A4 — capsule shows a percept block; A6 — block lines mirror the
canon's emitted handles (no absence padding)."
  (let* ((framing '(("percept_block_header" . "# Percept")))
         (percept '(:handles ("app:firefox" "surface:browser")))
         (lines (dl-satan-percept-render-block framing percept)))
    (should (equal (car lines) "# Percept"))
    (should (equal (cdr lines) '("- app:firefox" "- surface:browser")))))

(ert-deftest dl-satan-percept/render-block-empty-handles-yields-nil ()
  "A6 — empty handle list returns nil so the capsule omits the block
entirely (rather than emitting an empty `# Percept' header)."
  (let* ((framing '(("percept_block_header" . "# Percept")))
         (percept '(:handles ())))
    (should (null (dl-satan-percept-render-block framing percept)))))

(ert-deftest dl-satan-percept/render-block-without-framing-key-yields-nil ()
  "Mind owns the header text; absent key in framing.txt means the
section is suppressed.  This guards against silent fallback to a
hardcoded header in elisp."
  (let* ((framing '(("now" . "# Now")))
         (percept '(:handles ("app:firefox"))))
    (should (null (dl-satan-percept-render-block framing percept)))))

(provide 'dl-satan-percept-test)
;;; dl-satan-percept-test.el ends here
