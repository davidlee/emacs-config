;;; dl-satan-motive-test.el --- Phase 3 motive ert -*- lexical-binding: t; -*-

;; Phase 3 of perceptual-design.md.  Covers:
;;
;;   A7  motive_replace rejects payloads breaching ≤3 motives or
;;       ≤10 rumination lines with a structured error naming the bound.
;;   A8  footer parser accepts :cue: :cooldown_s: :worked_count:
;;       :last_intervention_at:; required :cue: missing → dormant;
;;       :ceiling: rejected (not a v0 field).
;;   A9  :worked_count: is informational — two motives differing only
;;       in :worked_count: produce the same capsule ordering.

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-motive)

;; ---------------------------------------------------------------------
;; Fixtures
;; ---------------------------------------------------------------------

(defconst dl-satan-motive-test--well-formed
  "* test: docs-after-error
  Docs after terminal error often substitute orientation for contact.
  :cue: project:emacs.d surface_transition:terminal->browser domain_kind:docs
  :cooldown_s: 1800
  :worked_count: 0
  :last_intervention_at: 2026-05-21T14:02Z

* test: bough-status-drift
  When bough status changes accumulate without user attention.
  :cue: bough_event:status_changed app:firefox
  :cooldown_s: 3600
  :worked_count: 4

* ruminations
  - 2026-05-22  docs-after-error often artifactless when project is emacs.d
  - 2026-05-19  patch jobs accepted more when directive cites file path
"
  "Minimal valid motives.org fixture: 2 active motives + 2 ruminations.")

(defconst dl-satan-motive-test--ceiling
  "* test: pestered
  This motive uses the forbidden v0 ceiling field.
  :cue: app:firefox
  :cooldown_s: 1800
  :ceiling: 5
"
  "Fixture exercising the §S3 deferred :ceiling: rejection (A8).")

(defconst dl-satan-motive-test--malformed-cue
  "* test: bad
  Cue token is not a canonical handle.
  :cue: not-a-valid-handle
  :cooldown_s: 1800
"
  "Fixture: `:cue:' contains an entry that fails the canon regex.")

(defconst dl-satan-motive-test--ctx-only-cue
  "* test: too-generic
  Cue contains only ctx-derived handles — the §S2 noise floor applies.
  :cue: project:emacs.d mode:motd day:2026-05-22
  :cooldown_s: 1800
"
  "Fixture: well-formed handles but none in the admit set.")

(defconst dl-satan-motive-test--four-actives
  "* test: a
  :cue: app:firefox
  :cooldown_s: 1800
* test: b
  :cue: app:firefox
  :cooldown_s: 1800
* test: c
  :cue: app:firefox
  :cooldown_s: 1800
* test: d
  :cue: app:firefox
  :cooldown_s: 1800
"
  "Fixture exercising the 3-active cap (§S3 / A7).")

(defun dl-satan-motive-test--n-ruminations (n)
  "Return a fixture string carrying N rumination lines."
  (concat "* test: ok\n  :cue: app:firefox\n  :cooldown_s: 1800\n"
          "* ruminations\n"
          (mapconcat (lambda (i)
                       (format "  - 2026-05-%02d  line %d" (1+ i) i))
                     (number-sequence 0 (1- n))
                     "\n")
          "\n"))

;; ---------------------------------------------------------------------
;; A8 — parser shape
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-motive/parse-accepts-all-footer-fields ()
  (let* ((parsed (dl-satan-motive-parse dl-satan-motive-test--well-formed))
         (motives (plist-get parsed :motives))
         (first (car motives)))
    (should (= 2 (length motives)))
    (should (equal "docs-after-error" (plist-get first :id)))
    (should (equal '("project:emacs.d"
                     "surface_transition:terminal->browser"
                     "domain_kind:docs")
                   (plist-get first :cue)))
    (should (= 1800 (plist-get first :cooldown_s)))
    (should (= 0    (plist-get first :worked_count)))
    (should (equal "2026-05-21T14:02Z"
                   (plist-get first :last_intervention_at)))
    (should (not (plist-get first :dormant)))))

(ert-deftest dl-satan-motive/parse-extracts-ruminations ()
  (let* ((parsed (dl-satan-motive-parse dl-satan-motive-test--well-formed))
         (rum (plist-get parsed :ruminations)))
    (should (= 2 (length rum)))
    (should (equal (car rum)
                   "2026-05-22  docs-after-error often artifactless when project is emacs.d"))))

(ert-deftest dl-satan-motive/parse-rejects-ceiling-field ()
  "A8 — :ceiling: is not a v0 field; parse flags it as a forbidden
error so the write-side guard can refuse the replacement.  The motive
itself is still returned (file-tolerated) for diagnostic rendering."
  (let* ((parsed (dl-satan-motive-parse dl-satan-motive-test--ceiling))
         (errors (plist-get parsed :errors)))
    (should (= 1 (length (plist-get parsed :motives))))
    (should (= 1 (length errors)))
    (should (eq :forbidden-field (plist-get (car errors) :kind)))
    (should (equal "pestered" (plist-get (car errors) :motive)))))

(ert-deftest dl-satan-motive/parse-marks-missing-cue-dormant ()
  "A8 — a motive without a `:cue:' is dormant (file-tolerated,
capsule-invisible, observer-skipped)."
  (let* ((text "* test: no-cue\n  Prose only.\n  :cooldown_s: 1800\n")
         (parsed (dl-satan-motive-parse text))
         (m (car (plist-get parsed :motives))))
    (should (plist-get m :dormant))
    (should (eq :missing-cue (plist-get m :dormant_reason)))))

(ert-deftest dl-satan-motive/parse-marks-malformed-cue-dormant ()
  (let* ((parsed (dl-satan-motive-parse dl-satan-motive-test--malformed-cue))
         (m (car (plist-get parsed :motives))))
    (should (plist-get m :dormant))
    (should (eq :malformed-cue (plist-get m :dormant_reason)))))

(ert-deftest dl-satan-motive/parse-marks-ctx-only-cue-dormant ()
  "§S3 — a cue with only ctx-derived handles fails admission (same
rationale as the §S2 resonance gate).  Without a sensor-observed
handle the motive triggers on every tick — defeats cooldown."
  (let* ((parsed (dl-satan-motive-parse dl-satan-motive-test--ctx-only-cue))
         (m (car (plist-get parsed :motives))))
    (should (plist-get m :dormant))
    (should (eq :no-sensor-handle (plist-get m :dormant_reason)))))

(ert-deftest dl-satan-motive/parse-missing-text-returns-empty ()
  "Silent self-suppression — missing/empty file is a valid state."
  (let ((parsed (dl-satan-motive-parse "")))
    (should (null (plist-get parsed :motives)))
    (should (null (plist-get parsed :ruminations)))
    (should (null (plist-get parsed :errors)))))

(ert-deftest dl-satan-motive/read-missing-file-returns-empty ()
  (let* ((tmp (make-temp-file "satan-motive-missing-"))
         (_ (delete-file tmp))
         (parsed (dl-satan-motive-read tmp)))
    (should (null (plist-get parsed :motives)))))

;; ---------------------------------------------------------------------
;; A9 — worked_count is informational
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-motive/worked-count-does-not-reorder ()
  "A9 — two motives that differ only in `:worked_count:' must yield
the same capsule ordering (file order is the only ordering)."
  (let* ((framing '(("motive_block_header" . "# Motive")))
         (low "* test: alpha
  :cue: app:firefox
  :cooldown_s: 1800
  :worked_count: 0

* test: beta
  :cue: app:firefox
  :cooldown_s: 1800
  :worked_count: 99
")
         (high "* test: alpha
  :cue: app:firefox
  :cooldown_s: 1800
  :worked_count: 99

* test: beta
  :cue: app:firefox
  :cooldown_s: 1800
  :worked_count: 0
")
         (block-low (dl-satan-motive-render-block
                     framing (dl-satan-motive-parse low)))
         (block-high (dl-satan-motive-render-block
                      framing (dl-satan-motive-parse high)))
         (heads-low  (cl-remove-if-not
                      (lambda (l) (string-prefix-p "## " l))
                      block-low))
         (heads-high (cl-remove-if-not
                      (lambda (l) (string-prefix-p "## " l))
                      block-high)))
    (should (equal heads-low '("## alpha" "## beta")))
    (should (equal heads-high '("## alpha" "## beta")))))

;; ---------------------------------------------------------------------
;; Render
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-motive/render-block-shape ()
  (let* ((framing '(("motive_block_header" . "# Motive")))
         (block (dl-satan-motive-render-block
                 framing
                 (dl-satan-motive-parse dl-satan-motive-test--well-formed))))
    (should (equal (car block) "# Motive"))
    (should (member "## docs-after-error" block))
    (should (cl-some (lambda (l)
                       (string-match-p
                        "^  cue: project:emacs.d surface_transition:terminal->browser domain_kind:docs$"
                        l))
                     block))
    (should (cl-some (lambda (l)
                       (string-match-p
                        "^  cooldown_s: 1800  worked_count: 0  last_intervention_at: 2026-05-21T14:02Z$"
                        l))
                     block))))

(ert-deftest dl-satan-motive/render-block-omits-dormant ()
  "Dormant motives never render — §S3 says they are file-tolerated
but capsule-invisible."
  (let* ((framing '(("motive_block_header" . "# Motive")))
         (text (concat dl-satan-motive-test--well-formed
                       dl-satan-motive-test--malformed-cue))
         (block (dl-satan-motive-render-block
                 framing (dl-satan-motive-parse text)))
         (heads (cl-remove-if-not
                 (lambda (l) (string-prefix-p "## " l))
                 block)))
    (should (equal heads '("## docs-after-error" "## bough-status-drift")))
    (should-not (member "## bad" block))))

(ert-deftest dl-satan-motive/render-block-omits-when-no-active ()
  "Block self-suppresses with no active motives."
  (let* ((framing '(("motive_block_header" . "# Motive")))
         (block (dl-satan-motive-render-block
                 framing
                 (dl-satan-motive-parse
                  dl-satan-motive-test--malformed-cue))))
    (should (null block))))

(ert-deftest dl-satan-motive/render-block-without-framing-key-yields-nil ()
  "Mind owns the header text; absent key suppresses the section."
  (let* ((framing '(("percept_block_header" . "# Percept")))
         (parsed (dl-satan-motive-parse dl-satan-motive-test--well-formed)))
    (should (null (dl-satan-motive-render-block framing parsed)))))

;; ---------------------------------------------------------------------
;; A7 — write-side bounds
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-motive/write-rejects-too-many-actives ()
  (let ((err (dl-satan-motive-validate-for-write
              dl-satan-motive-test--four-actives)))
    (should (eq :too-many-active (plist-get err :bound)))
    (should (= 3 (plist-get err :limit)))
    (should (= 4 (plist-get err :got)))
    (should (string-match-p "too many active motives: limit 3, got 4"
                            (dl-satan-motive-format-write-error err)))))

(ert-deftest dl-satan-motive/write-rejects-too-many-ruminations ()
  (let* ((text (dl-satan-motive-test--n-ruminations 11))
         (err (dl-satan-motive-validate-for-write text)))
    (should (eq :too-many-ruminations (plist-get err :bound)))
    (should (= 10 (plist-get err :limit)))
    (should (= 11 (plist-get err :got)))))

(ert-deftest dl-satan-motive/write-rejects-ceiling-field ()
  (let ((err (dl-satan-motive-validate-for-write
              dl-satan-motive-test--ceiling)))
    (should (eq :forbidden-field (plist-get err :bound)))
    (should (equal "pestered" (plist-get err :motive)))
    (should (equal "ceiling" (plist-get err :field)))
    (should (string-match-p "forbidden field"
                            (dl-satan-motive-format-write-error err)))))

(ert-deftest dl-satan-motive/write-rejects-malformed-cue ()
  "A8 — a motive declaring a cue must declare a *valid* cue.
Missing cue → dormant on read but accepted on write (the author
might be staging work).  Malformed cue → write rejected so the
author cannot ship garbage handles to the substrate."
  (let ((err (dl-satan-motive-validate-for-write
              dl-satan-motive-test--malformed-cue)))
    (should (eq :invalid-cue (plist-get err :bound)))
    (should (equal "bad" (plist-get err :motive)))
    (should (eq :malformed-cue (plist-get err :reason)))))

(ert-deftest dl-satan-motive/write-rejects-ctx-only-cue ()
  "Cue without a sensor-observed handle is rejected on write —
otherwise the motive would silently degrade to dormant on read and
the author would not see why."
  (let ((err (dl-satan-motive-validate-for-write
              dl-satan-motive-test--ctx-only-cue)))
    (should (eq :invalid-cue (plist-get err :bound)))
    (should (eq :no-sensor-handle (plist-get err :reason)))))

(ert-deftest dl-satan-motive/write-accepts-well-formed ()
  (should (null (dl-satan-motive-validate-for-write
                 dl-satan-motive-test--well-formed))))

(ert-deftest dl-satan-motive/write-accepts-exactly-three-actives ()
  "Boundary: 3 actives + 10 ruminations is the limit, not over it."
  (let* ((three "* test: a\n  :cue: app:firefox\n  :cooldown_s: 1800\n* test: b\n  :cue: app:firefox\n  :cooldown_s: 1800\n* test: c\n  :cue: app:firefox\n  :cooldown_s: 1800\n")
         (ten (dl-satan-motive-test--n-ruminations 10)))
    (should (null (dl-satan-motive-validate-for-write three)))
    (should (null (dl-satan-motive-validate-for-write ten)))))

(ert-deftest dl-satan-motive/write-accepts-missing-cue ()
  "A motive without a cue at all is a draft — author staging work.
The write path tolerates it; the read path renders it dormant."
  (let ((text "* test: drafting\n  Prose only.\n  :cooldown_s: 1800\n"))
    (should (null (dl-satan-motive-validate-for-write text)))))

;; ---------------------------------------------------------------------
;; Capsule integration (Phase 3.3) — block lands between resonance and today
;; ---------------------------------------------------------------------

(require 'dl-satan-context)

(defmacro dl-satan-motive-test--with-framing (tmp-sym &rest body)
  "Bind TMP-SYM to a tmp dir; seed scaffold + framing (with motive
key) + a motd prompt; rebind the framing/scaffold defcustoms for
BODY's dynamic extent.  Mirrors the resonance-test framing fixture
so the two block tests use parallel scaffolding."
  (declare (indent 1))
  `(let* ((,tmp-sym (make-temp-file "satan-motive-cap-" t))
          (dl-satan-system-scaffold-file
           (expand-file-name "system/scaffold.txt" ,tmp-sym))
          (dl-satan-system-framing-file
           (expand-file-name "system/framing.txt" ,tmp-sym)))
     (unwind-protect
         (progn
           (make-directory (expand-file-name "prompts" ,tmp-sym))
           (make-directory (expand-file-name "system" ,tmp-sym))
           (with-temp-file dl-satan-system-scaffold-file (insert "SCAFFOLD"))
           (with-temp-file dl-satan-system-framing-file
             (insert "now=# Now\n"
                     "percept_block_header=# Percept\n"
                     "resonance_block_header=# Resonance\n"
                     "motive_block_header=# Motive\n"
                     "today=# Today (raw)\n"
                     "sources=# Source files\n"
                     "recent_runs=# Recent SATAN runs\n"))
           (with-temp-file (expand-file-name "prompts/motd.txt" ,tmp-sym)
             (insert "PROMPT"))
           ,@body)
       (delete-directory ,tmp-sym t))))

(ert-deftest dl-satan-motive/capsule-renders-motive-between-resonance-and-today ()
  "Phase 3.3 — when PREPARE carries a `:motive' with ≥1 active motive,
the rendered prompt contains a `# Motive' block.  Placement is
between `# Resonance' and `# Today (raw)' per §S1 sequence."
  (dl-satan-motive-test--with-framing tmp
    (let* ((spec (list :name "motd"
                       :prompt-file
                       (expand-file-name "prompts/motd.txt" tmp)))
           (prepare (list :run_id "rid-x"
                          :time_now "2026-05-22T10:00:00+10:00"
                          :percept '(:handles ("app:firefox"))
                          :resonance
                          (list :status 'ok
                                :cue '("app:firefox")
                                :matches
                                '((:trace_id "20260518T120000-aaa"
                                   :score 11.2
                                   :matched_handles ("app:firefox"))))
                          :motive
                          (dl-satan-motive-parse
                           dl-satan-motive-test--well-formed)))
           (bundle (dl-satan-context-motd spec prepare))
           (prompt (plist-get bundle :prompt))
           (idx-resonance (string-match "^# Resonance$" prompt))
           (idx-motive (string-match "^# Motive$" prompt))
           (idx-today (or (string-match "^# Today (raw)$" prompt)
                          most-positive-fixnum)))
      (should idx-resonance)
      (should idx-motive)
      (should (< idx-resonance idx-motive))
      (should (< idx-motive idx-today))
      (should (string-match-p "^## docs-after-error$" prompt)))))

(ert-deftest dl-satan-motive/capsule-omits-motive-when-empty ()
  "§S3 silent self-suppression — empty motive parse (e.g. missing
file) → no `# Motive' header."
  (dl-satan-motive-test--with-framing tmp
    (let* ((spec (list :name "motd"
                       :prompt-file
                       (expand-file-name "prompts/motd.txt" tmp)))
           (prepare (list :run_id "rid-y"
                          :time_now "2026-05-22T10:00:00+10:00"
                          :motive '(:motives nil :ruminations nil
                                    :errors nil)))
           (bundle (dl-satan-context-motd spec prepare))
           (prompt (plist-get bundle :prompt)))
      (should-not (string-match-p "^# Motive$" prompt)))))

(ert-deftest dl-satan-motive/capsule-omits-when-only-dormant ()
  "A file containing only dormant motives renders no actionable
block.  Matches the §S3 file-tolerated / capsule-invisible split."
  (dl-satan-motive-test--with-framing tmp
    (let* ((spec (list :name "motd"
                       :prompt-file
                       (expand-file-name "prompts/motd.txt" tmp)))
           (prepare (list :run_id "rid-z"
                          :time_now "2026-05-22T10:00:00+10:00"
                          :motive
                          (dl-satan-motive-parse
                           dl-satan-motive-test--malformed-cue)))
           (bundle (dl-satan-context-motd spec prepare))
           (prompt (plist-get bundle :prompt)))
      (should-not (string-match-p "^# Motive$" prompt)))))

;; ---------------------------------------------------------------------
;; with-prepare mirror (Phase 3.3) — :motive joins :percept and :resonance
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-motive/with-prepare-mirrors-motive-slot ()
  (let* ((parsed (dl-satan-motive-parse
                  dl-satan-motive-test--well-formed))
         (prepare (list :run_id "rid"
                        :time_now "2026-05-22T10:00:00+10:00"
                        :percept '(:handles ("app:firefox"))
                        :resonance '(:status no-match)
                        :motive parsed))
         (bundle (dl-satan-context--with-prepare '() prepare)))
    (should (equal parsed (plist-get bundle :motive)))
    (should (equal "rid" (plist-get bundle :run_id)))
    (should (equal "2026-05-22T10:00:00+10:00"
                   (plist-get bundle :time_now)))))

(provide 'dl-satan-motive-test)
;;; dl-satan-motive-test.el ends here
