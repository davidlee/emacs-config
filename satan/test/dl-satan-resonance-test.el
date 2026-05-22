;;; dl-satan-resonance-test.el --- Phase 2 resonance ert -*- lexical-binding: t; -*-

;; Phase 2 of perceptual-design.md.  Covers:
;;
;;   A4   resonance block IFF gate passes + memory reachable + ≥1 match
;;   A5   gate exclusion comprehensive (mode/day/week/project/file_kind)
;;
;; The store is stubbed via the derive helper's `:store-resonate' opt
;; so tests never touch PG.  Phase 2.4 fixtures cover gate-skip,
;; zero-matches, and psql-down paths explicitly.

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-resonance)

;; ---------------------------------------------------------------------
;; Helpers
;; ---------------------------------------------------------------------

(defun dl-satan-resonance-test--percept (handles sources)
  "Return a minimal percept plist with HANDLES + per-handle SOURCES.
SOURCES is a list of plists in handle order; each carries `:rule_id'."
  (list :handles handles
        :handle_sources sources))

(defun dl-satan-resonance-test--src (rule-id handle)
  "Source row matching `dl-satan-percept--sources-rows' output for HANDLE."
  (list :handle handle :rule_id rule-id))

(defun dl-satan-resonance-test--ok-stub (matches)
  "Return a `:store-resonate' stub returning (ok . MATCHES) regardless of args."
  (lambda (&rest _) (cons 'ok matches)))

(defun dl-satan-resonance-test--err-stub (msg)
  "Return a `:store-resonate' stub returning (error . MSG)."
  (lambda (&rest _) (cons 'error msg)))

;; ---------------------------------------------------------------------
;; Gate (A5 — exclusion comprehensive)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-resonance/gate-skip-ctx-only ()
  "Cue containing only ctx-derived handles (mode + day + week) is
gate-skipped — no store call, status `gate-skip'."
  (let* ((called 0)
         (percept (dl-satan-resonance-test--percept
                   '("day:2026-05-19" "mode:motd" "week:2026-W21")
                   (list (dl-satan-resonance-test--src
                          "time.day_week" "day:2026-05-19")
                         (dl-satan-resonance-test--src
                          "ctx.mode" "mode:motd")
                         (dl-satan-resonance-test--src
                          "time.day_week" "week:2026-W21"))))
         (stub (lambda (&rest _) (cl-incf called) (cons 'ok nil)))
         (result (dl-satan-resonance-derive
                  percept (list :store-resonate stub))))
    (should (eq (plist-get result :status) 'gate-skip))
    (should (null (plist-get result :matches)))
    (should (= called 0))))

(ert-deftest dl-satan-resonance/gate-skip-project-cwd-only ()
  "Cue with only cwd-derived `project:*' is gate-skipped (§S2)."
  (let* ((percept (dl-satan-resonance-test--percept
                   '("project:emacs.d")
                   (list (dl-satan-resonance-test--src
                          "cwd.project" "project:emacs.d"))))
         (result (dl-satan-resonance-derive
                  percept
                  (list :store-resonate
                        (dl-satan-resonance-test--ok-stub
                         '((:trace_id "t1" :score 5.0
                            :matched_handles ("project:emacs.d"))))))))
    (should (eq (plist-get result :status) 'gate-skip))
    (should (null (plist-get result :matches)))))

(ert-deftest dl-satan-resonance/gate-skip-file-kind-only ()
  "Cue with only `file_kind:*' (cwd-derived) is gate-skipped."
  (let* ((percept (dl-satan-resonance-test--percept
                   '("file_kind:elisp")
                   (list (dl-satan-resonance-test--src
                          "cwd.file_kind" "file_kind:elisp"))))
         (result (dl-satan-resonance-derive
                  percept
                  (list :store-resonate
                        (dl-satan-resonance-test--ok-stub nil)))))
    (should (eq (plist-get result :status) 'gate-skip))))

(ert-deftest dl-satan-resonance/gate-skip-all-excluded-combined ()
  "A5 — full exclude list combined still skips.  Cues that mix every
excluded rule but nothing sensor-observed must NOT admit."
  (let* ((percept (dl-satan-resonance-test--percept
                   '("day:2026-05-19" "file_kind:elisp" "mode:motd"
                     "project:emacs.d" "week:2026-W21")
                   (list (dl-satan-resonance-test--src
                          "time.day_week" "day:2026-05-19")
                         (dl-satan-resonance-test--src
                          "cwd.file_kind" "file_kind:elisp")
                         (dl-satan-resonance-test--src
                          "ctx.mode" "mode:motd")
                         (dl-satan-resonance-test--src
                          "cwd.project" "project:emacs.d")
                         (dl-satan-resonance-test--src
                          "time.day_week" "week:2026-W21"))))
         (result (dl-satan-resonance-derive
                  percept
                  (list :store-resonate
                        (dl-satan-resonance-test--ok-stub nil)))))
    (should (eq (plist-get result :status) 'gate-skip))))

(ert-deftest dl-satan-resonance/gate-skip-empty-cue ()
  "Empty handle list is gate-skipped without calling the store."
  (let* ((called 0)
         (percept (dl-satan-resonance-test--percept nil nil))
         (stub (lambda (&rest _) (cl-incf called) (cons 'ok nil)))
         (result (dl-satan-resonance-derive
                  percept (list :store-resonate stub))))
    (should (eq (plist-get result :status) 'gate-skip))
    (should (= called 0))))

;; ---------------------------------------------------------------------
;; Gate admit
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-resonance/gate-admits-when-panopticon-observed ()
  "A single sensor-observed handle (panopticon.current.app) admits the
cue; the full handle list is forwarded to the store (excluded handles
still contribute score weight per §S2 — gate is admit-only)."
  (let* ((passed nil)
         (percept (dl-satan-resonance-test--percept
                   '("app:firefox" "day:2026-05-19" "mode:motd")
                   (list (dl-satan-resonance-test--src
                          "panopticon.current.app" "app:firefox")
                         (dl-satan-resonance-test--src
                          "time.day_week" "day:2026-05-19")
                         (dl-satan-resonance-test--src
                          "ctx.mode" "mode:motd"))))
         (stub (lambda (&rest args)
                 (setq passed args)
                 (cons 'ok
                       '((:trace_id "20260518T120000-a"
                          :score 7.5
                          :matched_handles ("app:firefox" "mode:motd"))))))
         (result (dl-satan-resonance-derive
                  percept (list :store-resonate stub))))
    (should (eq (plist-get result :status) 'ok))
    (should (equal (plist-get passed :cue-handles)
                   '("app:firefox" "day:2026-05-19" "mode:motd")))
    (should (= 1 (length (plist-get result :matches))))))

(ert-deftest dl-satan-resonance/gate-admits-bough-event ()
  "`bough_event:*' (bough.recent_status_change) admits."
  (let* ((percept (dl-satan-resonance-test--percept
                   '("bough_event:status_changed" "day:2026-05-19")
                   (list (dl-satan-resonance-test--src
                          "bough.recent_status_change"
                          "bough_event:status_changed")
                         (dl-satan-resonance-test--src
                          "time.day_week" "day:2026-05-19"))))
         (result (dl-satan-resonance-derive
                  percept
                  (list :store-resonate
                        (dl-satan-resonance-test--ok-stub
                         '((:trace_id "tid" :score 3.0
                            :matched_handles ("bough_event:status_changed"))))))))
    (should (eq (plist-get result :status) 'ok))))

(ert-deftest dl-satan-resonance/limit-forwarded-to-store ()
  "Default limit is 3 (design §S2 top 1–3); explicit `:limit' overrides."
  (let* ((passed nil)
         (percept (dl-satan-resonance-test--percept
                   '("app:firefox")
                   (list (dl-satan-resonance-test--src
                          "panopticon.current.app" "app:firefox"))))
         (stub (lambda (&rest args) (setq passed args) (cons 'ok nil))))
    (dl-satan-resonance-derive percept (list :store-resonate stub))
    (should (= (plist-get passed :limit) 3))
    (setq passed nil)
    (dl-satan-resonance-derive
     percept (list :store-resonate stub :limit 1))
    (should (= (plist-get passed :limit) 1))))

;; ---------------------------------------------------------------------
;; A4 — block emitted IFF ok + matches
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-resonance/zero-matches-yields-no-match-status ()
  "Gate passes + store returns ok with no rows → status `no-match'
(distinct from gate-skip); block omits."
  (let* ((percept (dl-satan-resonance-test--percept
                   '("app:firefox")
                   (list (dl-satan-resonance-test--src
                          "panopticon.current.app" "app:firefox"))))
         (result (dl-satan-resonance-derive
                  percept
                  (list :store-resonate
                        (dl-satan-resonance-test--ok-stub nil))))
         (block (dl-satan-resonance-render-block
                 '(("resonance_block_header" . "# Resonance"))
                 result)))
    (should (eq (plist-get result :status) 'no-match))
    (should (null block))))

(ert-deftest dl-satan-resonance/psql-down-yields-memory-unreachable ()
  "Store error → status `memory-unreachable' (handover watch-out: not a
run failure); block omits.  Audit consumers can distinguish from
gate-skip via `:status'."
  (let* ((percept (dl-satan-resonance-test--percept
                   '("app:firefox")
                   (list (dl-satan-resonance-test--src
                          "panopticon.current.app" "app:firefox"))))
         (result (dl-satan-resonance-derive
                  percept
                  (list :store-resonate
                        (dl-satan-resonance-test--err-stub "psql exit 1"))))
         (block (dl-satan-resonance-render-block
                 '(("resonance_block_header" . "# Resonance"))
                 result)))
    (should (eq (plist-get result :status) 'memory-unreachable))
    (should (null block))))

(ert-deftest dl-satan-resonance/render-block-shape ()
  "A4 — ok + ≥1 match renders header + per-match trace_id/score/matched
lines.  Header text comes from framing.txt; rendering with a different
key suppresses the block (mind owns the header)."
  (let* ((framing '(("resonance_block_header" . "# Resonance")))
         (result (list :status 'ok
                       :cue '("app:firefox")
                       :matches
                       '((:trace_id "20260518T120000-aaa"
                          :score 11.2
                          :matched_handles ("project:emacs.d"
                                            "surface_transition:terminal->browser"
                                            "domain_kind:docs"))
                         (:trace_id "20260515T080000-bbb"
                          :score 6.5
                          :matched_handles ("app:firefox" "mode:motd")))))
         (lines (dl-satan-resonance-render-block framing result)))
    (should (equal (car lines) "# Resonance"))
    (should (equal (nth 1 lines)
                   "- 20260518T120000-aaa  score 11.2"))
    (should (equal (nth 2 lines)
                   (concat "    matched: project:emacs.d, "
                           "surface_transition:terminal->browser, "
                           "domain_kind:docs")))
    (should (equal (nth 3 lines)
                   "- 20260515T080000-bbb  score 6.5"))
    (should (equal (nth 4 lines)
                   "    matched: app:firefox, mode:motd"))))

(ert-deftest dl-satan-resonance/render-block-without-framing-key-yields-nil ()
  "Mind owns the header text; absent key in framing.txt suppresses the
section.  Guards against silent fallback to a hardcoded header."
  (let* ((framing '(("percept_block_header" . "# Percept")))
         (result (list :status 'ok
                       :matches '((:trace_id "tid" :score 1.0
                                   :matched_handles ("app:firefox"))))))
    (should (null (dl-satan-resonance-render-block framing result)))))

(ert-deftest dl-satan-resonance/render-block-omits-on-gate-skip ()
  "A4 — gate-skip never renders a block, even with framing key present."
  (let* ((framing '(("resonance_block_header" . "# Resonance"))))
    (should (null (dl-satan-resonance-render-block
                   framing (list :status 'gate-skip :matches nil))))))

(provide 'dl-satan-resonance-test)
;;; dl-satan-resonance-test.el ends here
