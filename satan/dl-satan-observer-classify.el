;;; dl-satan-observer-classify.el --- SATAN outcome classifier -*- lexical-binding: t; -*-

;; Pure classifier extracted from `dl-satan-observer' (T1 refactor).
;; Given an intervention plist + motive plist, decides whether the
;; attribution window shows a positive outcome and which §S5 predicate
;; (if any) fired.  No state writes; the coordinator in
;; `dl-satan-observer' routes persistence.
;;
;; Reads only:
;;   - RUN-DIR/`bundle.json' for the intervention's baseline +
;;     percept handles (`--baseline-read', `--intervention-percept-handles').
;;   - Live system probes via `dl-satan-memory-evidence-assemble-
;;     with-bounds' to assemble the after-state.
;;
;; Symbol names retained verbatim from the pre-split monolith so
;; existing tests (`test/dl-satan-observer-test.el') and callers
;; remain wired without renames.

(require 'cl-lib)
(require 'dl-satan-memory-canon)
(require 'dl-satan-memory-evidence)
(require 'dl-satan-memory-grammar)

;; ---------------------------------------------------------------------
;; Configuration
;; ---------------------------------------------------------------------

(defcustom dl-satan-observer-window-mature-seconds 1800
  "Seconds after `intervention_emitted_at' before an intervention is
eligible for classification (A11).  Defaults to 30 minutes per §S5.
The gate prevents a same-tick or next-tick scan from scoring an
intervention before its attribution window has actually elapsed."
  :type 'integer :group 'dl-satan)

(defcustom dl-satan-observer-emacs-title-suffix-re
  " - GNU Emacs at .*\\'"
  "Regex matching the trailing suffix of `frame-title-format' on this
host.  The §S5 P1 predicate strips this suffix from a focus
segment's `:last_title' to recover the buffer's file path before
prefix-matching against the motive's `:project_cwd'.  Tune when
the title format changes; unmatched titles fall through and P1
silently no-ops on them."
  :type 'regexp :group 'dl-satan)

;; ---------------------------------------------------------------------
;; Baseline + after-state (Phase 5.4a)
;; ---------------------------------------------------------------------

(defun dl-satan-observer--read-json-object (path)
  "Parse the single JSON object at PATH, returning its plist.
Returns nil on missing file or parse failure.  Mirrors the lenient
contract of `dl-satan-observer--read-state' but doesn't seed an
empty value — callers need to distinguish absent from empty."
  (when (file-readable-p path)
    (condition-case _err
        (with-temp-buffer
          (let ((coding-system-for-read 'utf-8))
            (insert-file-contents path))
          (goto-char (point-min))
          (json-parse-buffer :object-type 'plist
                             :array-type 'list
                             :null-object nil
                             :false-object :false))
      (error nil))))

(defun dl-satan-observer--baseline-read (run-dir)
  "Return the intervention-time `evidence_window' for RUN-DIR.
Reads RUN-DIR/`bundle.json' and pulls out `:percept' →
`:evidence_window'.  Returns nil when bundle.json is missing,
unparseable, or lacks the percept slot — which happens on budget-
denied or pre-spawn-denied runs (phase 1 still skips percept.json
write under budget-denied; same caveat applies to bundle).

The classifier (5.4c) treats nil here as `:reason :no_baseline'."
  (let* ((path (expand-file-name "bundle.json" run-dir))
         (bundle (dl-satan-observer--read-json-object path))
         (percept (and bundle (plist-get bundle :percept))))
    (and percept (plist-get percept :evidence_window))))

(defun dl-satan-observer--window-end-iso (intervention)
  "Return the ISO8601 close-of-window for INTERVENTION.
Window end = `:intervention_emitted_at' +
`dl-satan-observer-window-mature-seconds' (30 min default).
Format matches `dl-satan-memory-evidence' helpers (%T%:z)."
  (let* ((emitted (plist-get intervention :intervention_emitted_at))
         (et (date-to-time emitted))
         (end (time-add et (seconds-to-time
                            dl-satan-observer-window-mature-seconds))))
    (format-time-string "%Y-%m-%dT%T%:z" end)))

(defun dl-satan-observer--window-crosses-midnight-p (intervention)
  "Return non-nil when INTERVENTION's 30-min window spans two calendar
days.  `dl-satan-memory-evidence-assemble-with-bounds' resolves the
panopticon segment file via `(substring END 0 10)' — a cross-day
window would read tomorrow's segments and miss most of the
window.  v0 punts on multi-day windows: the classifier yields
`:reason :crosses_midnight' instead of attempting a probe."
  (let ((start (plist-get intervention :intervention_emitted_at))
        (end (dl-satan-observer--window-end-iso intervention)))
    (not (equal (substring start 0 10) (substring end 0 10)))))

(defun dl-satan-observer--after-state (intervention motive)
  "Assemble the after-state `evidence_window' for INTERVENTION + MOTIVE.
Calls `dl-satan-memory-evidence-assemble-with-bounds' with
START = `:intervention_emitted_at',
END   = `--window-end-iso' (+30 min),
CWD   = MOTIVE's `:project_cwd' (default-directory when nil — git
        + fs probes still run, predicates 1+3 simply won't find
        path matches).

Caller is responsible for guarding midnight crossings; this helper
makes the call unconditionally."
  (let* ((start (plist-get intervention :intervention_emitted_at))
         (end (dl-satan-observer--window-end-iso intervention))
         (cwd (or (plist-get motive :project_cwd) default-directory))
         (ctx (list :time_now end
                    :mode_name "observer"
                    :run_id (plist-get intervention :run_id)
                    :current_grammar_version
                    dl-satan-memory-grammar-current-version)))
    (dl-satan-memory-evidence-assemble-with-bounds
     start end ctx (list :cwd cwd))))

;; ---------------------------------------------------------------------
;; Positive predicates (Phase 5.4b) — §S5 P1–P4
;;
;; Each takes (baseline after motive intervention) and returns non-nil
;; on fire, nil on skip / no-signal.  All pure: no I/O, no state
;; writes.  The classifier (5.4c) runs them in order; first fire
;; wins.  Predicates 1 + 3 are scoped to MOTIVE's `:project_cwd'
;; (silent skip when absent); 2 + 4 fire regardless.
;; ---------------------------------------------------------------------

(defun dl-satan-observer--title-to-path (title)
  "Strip the emacs frame-title suffix from TITLE; return the leading
absolute path or nil when the result isn't an absolute file path.
The `frame-title-format' shipped in phase 5.4-fmt emits
`<buffer-file-name> - GNU Emacs at <host>' when the buffer visits
a file and `<buffer-name> - GNU Emacs at <host>' otherwise; only
the former yields a path-prefix-matchable string."
  (when (stringp title)
    (let ((stripped (replace-regexp-in-string
                     dl-satan-observer-emacs-title-suffix-re "" title)))
      (and (string-prefix-p "/" stripped) stripped))))

(defun dl-satan-observer--predicate-editor-edit-in-window
    (_baseline after motive intervention)
  "§S5 P1 — fires when AFTER's `:focus_segments' contains an editor
segment that (a) started strictly after `:intervention_emitted_at'
and (b) carries a `:last_title' that resolves to a path under
MOTIVE's `:project_cwd'.  Silently nil when `:project_cwd' absent
or when no segment carries a last_title (e.g. panopticon segments
written before phase 5.4-pan)."
  (let ((cwd (plist-get motive :project_cwd))
        (emitted (plist-get intervention :intervention_emitted_at)))
    (when (and cwd emitted)
      (let ((prefix (file-name-as-directory (expand-file-name cwd))))
        (cl-some
         (lambda (seg)
           (let* ((surface (dl-satan-memory-canon--app-surface
                            (plist-get seg :app_id)))
                  (start-ts (plist-get seg :start_ts))
                  (path (dl-satan-observer--title-to-path
                         (plist-get seg :last_title))))
             (and (equal "editor" surface)
                  (stringp start-ts)
                  (string< emitted start-ts)
                  path
                  (string-prefix-p prefix path))))
         (plist-get after :focus_segments))))))

(defun dl-satan-observer--predicate-git-head-changed
    (baseline after _motive _intervention)
  "§S5 P2 — fires when BASELINE and AFTER report different
`:head_short' values AND the same `:remote' (cheap repo-identity
check; differing remote means the two probes saw different repos
and the comparison is meaningless).  Both sides must report a
head (a non-repo probe returns nil → P2 doesn't fire)."
  (let* ((bg (plist-get baseline :git_state))
         (ag (plist-get after :git_state))
         (b-head (plist-get bg :head_short))
         (a-head (plist-get ag :head_short)))
    (and (stringp b-head) (stringp a-head)
         (equal (plist-get bg :remote) (plist-get ag :remote))
         (not (equal b-head a-head)))))

(defun dl-satan-observer--abs-recent (fs-state)
  "Return absolute paths for FS-STATE's `:recent_files'.
`:recent_files' entries are stored relative to FS-STATE's `:cwd'
(which may be abbreviated, e.g. `~/.emacs.d'); both legs need
expanding before comparison."
  (let ((cwd (plist-get fs-state :cwd)))
    (when cwd
      (let ((abs-cwd (expand-file-name cwd)))
        (mapcar (lambda (rel) (expand-file-name rel abs-cwd))
                (plist-get fs-state :recent_files))))))

(defun dl-satan-observer--predicate-fs-recent-delta
    (baseline after motive _intervention)
  "§S5 P3 — fires when AFTER's `:recent_files' contains a path under
MOTIVE's `:project_cwd' that is absent from BASELINE's
`:recent_files'.  Silently nil when `:project_cwd' absent.
Per watch-out: `recentf-list' tracks visits, not edits — a file
opened (not modified) in the window will still satisfy this
predicate.  v0 accepts the looseness; a stricter mtime-delta is a
follow-up."
  (let ((cwd (plist-get motive :project_cwd)))
    (when cwd
      (let* ((after-abs (dl-satan-observer--abs-recent
                         (plist-get after :fs_state)))
             (baseline-abs (dl-satan-observer--abs-recent
                            (plist-get baseline :fs_state)))
             (prefix (file-name-as-directory (expand-file-name cwd))))
        (cl-some (lambda (path)
                   (and (string-prefix-p prefix path)
                        (not (member path baseline-abs))))
                 after-abs)))))

(defun dl-satan-observer--motive-bough-nanoids (motive)
  "Return the nanoids referenced by MOTIVE's `:cue' bough handles.
Strips the `bough_node:' / `bough_project:' prefix.  Returns nil
when the motive has no bough handles in its cue."
  (delq nil
        (mapcar
         (lambda (h)
           (cond
            ((string-prefix-p "bough_node:" h)
             (substring h (length "bough_node:")))
            ((string-prefix-p "bough_project:" h)
             (substring h (length "bough_project:")))))
         (or (plist-get motive :cue) nil))))

(defun dl-satan-observer--predicate-bough-event-match
    (_baseline after motive _intervention)
  "§S5 P4 — fires when AFTER's `:bough_recent' contains a bough event
whose `:nanoid' matches a `bough_node:' or `bough_project:' handle
in MOTIVE's `:cue'.  Fires regardless of `:project_cwd' (handle-
only correlation; see §S5 — `motives without a valid :cue are
dormant')."
  (let ((target-ids (dl-satan-observer--motive-bough-nanoids motive)))
    (and target-ids
         (cl-some
          (lambda (ev)
            (let ((nid (plist-get ev :nanoid)))
              (and (stringp nid) (member nid target-ids))))
          (plist-get after :bough_recent)))))

;; ---------------------------------------------------------------------
;; Public entry
;; ---------------------------------------------------------------------

(defconst dl-satan-observer--predicates
  '((:editor_edit_in_window
     . dl-satan-observer--predicate-editor-edit-in-window)
    (:git_head_changed
     . dl-satan-observer--predicate-git-head-changed)
    (:fs_recent_delta
     . dl-satan-observer--predicate-fs-recent-delta)
    (:bough_event_match
     . dl-satan-observer--predicate-bough-event-match))
  "Ordered alist mapping predicate keyword → symbol.
`dl-satan-observer-classify' runs them in order; first fire wins.
Order matters only for the `:predicate' slot recorded on the
verdict — the verdict itself is `\"positive\"' regardless.")

(defun dl-satan-observer-classify--unknown (reason)
  "Build an `:unknown' / `:low' verdict carrying REASON.
Per outcome-semantics §3 + §4: `:unknown' always emits at `:low'
confidence; `:predicates' is empty (no positive fired)."
  (list :classification :unknown
        :confidence :low
        :predicates nil
        :reason reason))

(defun dl-satan-observer-classify (intervention motive)
  "Return a verdict plist for INTERVENTION against MOTIVE (§S5).
Pure: no state writes.  Reads INTERVENTION's `:run_dir'/bundle.json
for the baseline; assembles the after-state via `--after-state'.

T1.5b PR 1 widens the legacy `(:verdict :predicate :reason)' shape
to the outcome-semantics §2 vocabulary:

  (:classification :worked | :unknown
   :confidence     :low | :medium | :high
   :predicates     (KEYWORD ...)   ; which P fired; nil when none
   :reason         KEYWORD or nil) ; why `:unknown', when applicable

Confidence derivation (§4): 1 predicate fires → `:medium'; ≥2 →
`:high'; none → `:low' (always paired with `:unknown').

Guard order:
  1. A14 — MOTIVE marked `:dormant' → `:unknown :motive_dormant'.
  2. Window crosses calendar-day boundary → `:crosses_midnight'.
     (v0 punts cross-day per §S5 watch-out —
     assemble-with-bounds would read tomorrow's panopticon
     segment file.)
  3. Baseline absent (budget-denied / pre_spawn-denied runs lack
     `bundle.json') → `:no_baseline'.
  4. Run all P1–P4; ≥1 fires → `:worked' + firers list.
  5. None fire → `:unknown' with `:reason nil'.

Step 4 replaces today's first-fire-wins semantics: PR 1 needs the
full firers list to derive `:confidence :high' on multi-fire.
PR 2 will refine step 5 into `:ignored' / `:neutral' based on
intervention surface.

Single-motive only (§S5 multi-motive correlation by overlap-count
+ file-order tiebreak lands in 5.7); callers iterate motives and
combine themselves until then."
  (cond
   ((plist-get motive :dormant)
    (dl-satan-observer-classify--unknown :motive_dormant))
   ((dl-satan-observer--window-crosses-midnight-p intervention)
    (dl-satan-observer-classify--unknown :crosses_midnight))
   (t
    (let ((baseline (dl-satan-observer--baseline-read
                     (plist-get intervention :run_dir))))
      (cond
       ((null baseline)
        (dl-satan-observer-classify--unknown :no_baseline))
       (t
        (let* ((after (dl-satan-observer--after-state intervention motive))
               (firers
                (delq nil
                      (mapcar
                       (lambda (p)
                         (and (funcall (cdr p) baseline after motive intervention)
                              (car p)))
                       dl-satan-observer--predicates))))
          (if firers
              (list :classification :worked
                    :confidence (if (> (length firers) 1) :high :medium)
                    :predicates firers
                    :reason nil)
            (dl-satan-observer-classify--unknown nil)))))))))

;; ---------------------------------------------------------------------
;; Multi-motive correlation (Phase 5.7) — overlap + file-order tiebreak
;; ---------------------------------------------------------------------

(defun dl-satan-observer--intervention-percept-handles (intervention)
  "Return the percept handle list persisted with INTERVENTION's run.
Reads `bundle.json' → `:percept' → `:handles'.  Nil when bundle is
missing or lacks the slot (budget-denied / pre_spawn-denied
runs)."
  (let* ((run-dir (plist-get intervention :run_dir))
         (path (and run-dir (expand-file-name "bundle.json" run-dir)))
         (bundle (and path (dl-satan-observer--read-json-object path)))
         (percept (and bundle (plist-get bundle :percept))))
    (and percept (plist-get percept :handles))))

(defun dl-satan-observer--rank-motives-by-overlap (motives percept-handles)
  "Rank MOTIVES by `|:cue ∩ PERCEPT-HANDLES|', descending.
Ties resolved by ascending position in MOTIVES (file order — §S5
deterministic tiebreaker so re-running the observer over the same
state yields the same correlation).  Dormant motives are skipped
(A14 — they have no usable cue).  Motives with zero overlap are
dropped — `dl-satan-observer-classify-for-motives' treats that as
`:reason :no_correlation' rather than a positive on a phantom
motive.

Returns list of `(:motive PLIST :order INT :overlap INT)' plists."
  (let* ((scored
          (cl-loop for m in motives
                   for idx upfrom 0
                   unless (plist-get m :dormant)
                   collect
                   (list :motive m
                         :order idx
                         :overlap
                         (cl-count-if
                          (lambda (h) (member h (plist-get m :cue)))
                          percept-handles))))
         (matches (cl-remove-if (lambda (r) (zerop (plist-get r :overlap)))
                                scored)))
    (sort matches
          (lambda (a b)
            (let ((oa (plist-get a :overlap))
                  (ob (plist-get b :overlap)))
              (cond
               ((> oa ob) t)
               ((< oa ob) nil)
               (t (< (plist-get a :order) (plist-get b :order)))))))))

(defun dl-satan-observer-classify-for-motives (intervention motives)
  "Pick the strongest-correlated motive in MOTIVES, then classify.
Reads INTERVENTION's `:run_dir'/bundle.json for percept handles;
intersects each motive's `:cue' against them; highest count wins,
file-order breaks ties.

Returns `dl-satan-observer-classify''s verdict shape (§2)
augmented with `:motive_id'.

When no motive overlaps with the intervention's percept handles
(or motives list is empty / bundle missing percept handles),
returns the §2 `:unknown' shape with `:reason :no_correlation' and
`:motive_id' nil — `persist-verdict' still commits the verdict so
the projection retires the pending row."
  (let* ((handles (dl-satan-observer--intervention-percept-handles
                   intervention))
         (ranked (dl-satan-observer--rank-motives-by-overlap motives handles)))
    (if (null ranked)
        (list :motive_id nil
              :classification :unknown
              :confidence :low
              :predicates nil
              :reason :no_correlation)
      (let* ((winner (plist-get (car ranked) :motive))
             (verdict (dl-satan-observer-classify intervention winner)))
        (plist-put verdict :motive_id (plist-get winner :id))))))

(provide 'dl-satan-observer-classify)
;;; dl-satan-observer-classify.el ends here
