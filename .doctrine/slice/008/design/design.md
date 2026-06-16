---
id: DR-008
slug: satan_git_activity_perception_24h_feed_window_watermark_retire_git_state_commit_role
name: "Design Revision - SATAN git-activity perception: 24h feed window, retire git_state commit role"
created: "2026-06-02"
updated: "2026-06-02"
status: draft
kind: design_revision  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
aliases: []
owners: []
relations:
  - type: implements
    target: DE-008
delta_ref: DE-008
source_context:
  - "docs/satan/perceptual-design.md — git-activity sensor + vcs_log (shipped 2026-05-30)"
  - "Investigation 2026-06-02 — /home/david/.claude/plans/purring-launching-peacock.md"
code_impacts:
  - path: satan/dl-satan-memory-evidence.el
    current: "One 10-min window for all feeds; git probe starved; git-feed-paths drops intermediate days and steps by 86400s; git-commits-status takes (last filt limit) over unsorted append order; one malformed line blanks the probe; single :window_start_at; git_state runs live git log in broker cwd."
    target: "Git-specific 24h window for the git probe only (+ :git_window_start_at); git-feed-paths enumerates every CALENDAR day; git-commits-status sorts by :end_ts before limit + tolerates per-file parse errors; git_state commit/head role demoted."
  - path: satan/dl-satan-observer-classify.el
    current: ":git_head_changed (P2) compares baseline/after git_state head_short, implicitly scoped to motive :project_cwd via --after-state cwd."
    target: ":git_commit_observed — repo-scoped (motive :project_cwd / project: cue) + window-anchored ((:intervention_emitted_at, window-end]) scan of after.git_commits; no baseline."
  - path: satan/dl-satan-tank.el
    current: "git line renders git_state head_short + dirty flag."
    target: "git line renders :git_commits summary (count + newest); git_state head/dirty not surfaced (dirty deferred)."
  - path: satan/dl-satan-memory-canon.el
    current: "vcs.recent_commit emits project:<slug> per repo in :git_commits, merged by handle; cwd.project also emits from git_state.remote."
    target: "Unchanged behaviour; verify --merge idempotence across ticks under the 24h backlog (verify-and-guard). cwd.project's git_state.remote source left for the active-project follow-up."
  - path: satan/test/dl-satan-observer-test.el
    current: "P2 predicate tests assert :git_head_changed firing on :git_state :head_short fixtures + exact registry-order lists."
    target: "Rewrite for :git_commit_observed on :git_commits :end_ts fixtures; update registry-order assertions to the new key."
  - path: docs/satan/attributes/outcome-semantics.md
    current: "Predicate vocabulary lists :git_head_changed among S5 P1-P4."
    target: "Replace with :git_commit_observed; note the cross-repo feed source."
  - path: CHANGELOG.md
    current: "P2 documented as :head_short-diff predicate."
    target: "Add DE-008 entry: git feed 24h window + repo-scoped commit-observed predicate; P2 retired."
  - path: docs/satan/perceptual-design.md
    current: "Describes observer git refs / git_state semantics (~:340)."
    target: "Update to git feed 24h window + :git_commit_observed; note git_state demotion."
  - path: satan/dl-satan-sensor-alerts.el
    current: "Renders the :git sensor_status into the prompt sensor block (:51/:80) — prompt-visible consumer not previously listed."
    target: "No code change required; verify the :git line renders correctly under the new feed (regression check only)."
verification_alignment:
  - id: VT-git-window
    impact: new
    note: "git window math: git probe sees commits outside the 10-min focus window but inside 24h."
  - id: VT-feed-paths-multiday
    impact: new
    note: "git-feed-paths enumerates every day across a multi-day [start,end]."
  - id: VT-new-commit-predicate
    impact: new
    note: "cross-repo new-commit predicate fires once on a fresh commit, holds on repeats."
  - id: VT-p2-retired
    impact: regression
    note: ":git_head_changed removed from registry and tests; no orphaned references."
  - id: VA-live-tick
    impact: new
    note: "throwaway commit + forced tick → appears in next percept.json; sensor_status:git=ok."
design_decisions:
  - "DEC-1: git feed gets its own window (default 24h), un-clamped by run_started; other feeds keep 10-min."
  - "DEC-2: no persistent watermark — reuse per-run baseline/after + canon handle-merge (verify-and-guard)."
  - "DEC-3: git_state demoted, not deleted; :dirty plumbing left dormant pending active-project follow-up."
open_questions:
  - "Q1 (RESOLVED): canon --merge is per-run; per-tick project:<slug> emissions land in the percept capsule, not durable store traces — re-listing the 24h backlog is benign. No watermark needed."
  - "Q2: git capsule reuses seg-limit (10) for the newest-N tail; sufficient for busy days, or add git-seg-limit? (defer unless evidence). The observer predicate is unaffected — it scans the full filtered set."
  - "Q3 (follow-up): relax the observer :crosses_midnight guard now that the git feed spans calendar days."
---

# DR-008 – SATAN git-activity perception: 24h feed window, retire git_state commit role

## 1. Executive Summary

- **Delta**: [DE-008](./DE-008.md)
- **Status**: draft
- **Synopsis**: SATAN ingests commits from the global post-commit hook but never perceives them, because the git feed shares the 10-minute attention window built for continuous focus/browser signals. Give the git feed its own 24h horizon, fix the day-enumeration bug that blocks any horizon >1 day, and retire the pwd-coupled `git_state` commit role (and its `:git_head_changed` predicate) in favour of a cross-repo "new commit observed" predicate. No new persistent state.

## 2. Problem & Constraints

- **Current Behaviour**: `dl-satan-memory-evidence-window-minutes` = 10 (`dl-satan-memory-evidence.el:46`) drives `--bounds` (`:265`), producing one `(start . end)` window applied to *every* feed. Commits are bursty; they almost never land in the 10 min before a tick that fires. Empirically every tick on 2026-06-02 reported `git_commits = {}`, `sensor_status:git = "missing"`, despite the segment files being fresh and the reader returning all commits for a full-day window. The legible "last commit" line is `git_state` — live `git log` in the broker's incidental `default-directory` (one repo, currently `~`=nix-config), the source of the misleading "stuck on May 28".
- **Drivers**: User report; investigation `purring-launching-peacock.md`.
- **Constraints**: Work stays in `.emacs.d/satan/` (POL-001 not engaged — no module extraction). Live daemon; `just check` must stay green; focus/browser/content feeds must not regress.
- **Out of Scope**: hook script, segment format, `vcs_log` tool contract; retargeting `git_state` `:dirty` to active-project root (follow-up delta).

## 3. Architecture Intent

- **Target Outcomes**:
  - The git feed perceives commits over a rolling 24h horizon, independent of the attention window. (Note: `sensor_status:git` means feed *readability*, not "commits exist" — a readable-but-empty window is still `"ok"`; success is observed via a non-empty `evidence_window.git_commits`, not the status string.)
  - SATAN reacts to genuinely-new commits exactly once, via the observer's existing per-run baseline/after pairing — no new persistent state, no duplicate canon nodes.
  - `git_state` stops masquerading as cross-repo "last commit"; perception reads the hook feed.
- **Guiding Principle**: separate **awareness** (the capsule's 24h backlog — a *view*) from **reaction** (the observer outcome — a per-run *delta*). The first wants a wide window; the second is naturally idempotent because the observer already snapshots before/after.

## 4. Core Design

### 4.1 Git-specific window (DEC-1)

Add:

```elisp
(defcustom dl-satan-memory-evidence-git-window-minutes 1440
  "Look-back horizon (minutes) for the git-activity feed.
Decoupled from `dl-satan-memory-evidence-window-minutes' (the focus/
browser attention window) because commits are bursty: a 10-min window
almost never catches one.  Default 24h." :type 'integer :group 'dl-satan)
```

Inside `dl-satan-memory-evidence-assemble-with-bounds` (`:554`), derive a git-only start from `end` and pass it to the git probe **only**:

```elisp
(git-start (dl-satan-memory-evidence--iso-format
            (time-subtract (date-to-time end)
                           (seconds-to-time
                            (* 60 dl-satan-memory-evidence-git-window-minutes)))))
...
(git-probe (if cue-only (cons "ok" '())
             (dl-satan-memory-evidence--git-commits-status
              (dl-satan-memory-evidence--git-feed-paths root git-start end)
              git-start end seg-limit)))
```

`focus-probe`, `browser-probe`, `content-probe` keep the existing `start`. Note `git-start` is **un-clamped by `run_started`** (unlike `--bounds`' `start`): the backlog is deliberately wider than the run.

**Distinct window field (HIGH, external-review).** The raw plist exposes a single `:window_start_at` (`memory-evidence.el:638`); tank renders it (`tank.el:190`). With git on a 24h window and everything else on 10 min, a "commits in window" label keyed off `:window_start_at` would *lie*. Add `:git_window_start_at git-start` to the raw plist and have the tank git line reference it.

**Sort before limit (HIGH, external-review).** `--git-commits-status` currently does `(last filt limit)` over file-append order. Across interleaved repos, multiple day-files concatenated in path order, and amended/backdated `%cI` committer dates, append order ≠ instant order — so the newest-`limit` tail and any "max `:end_ts`" can be wrong. Sort `filt` by parsed `:end_ts` ascending **before** `(last filt limit)`. The observer predicate (§4.3) additionally scans the full filtered set for window rows, so a busy day (>`seg-limit` commits) cannot truncate the attribution-window commit out of view.

### 4.2 Multi-day feed-paths fix

`dl-satan-memory-evidence--git-feed-paths` (`:223`) currently returns only `start-day` and `end-day`, silently skipping intermediate days — harmless at 10 min, wrong at 24h+ (e.g. a window 2026-05-31T23:50 → 2026-06-02T00:10 must read 05-31, 06-01, 06-02). Replace with a day-by-day enumeration from `start-day` to `end-day` inclusive:

**DST correctness (HIGH, external-review).** Stepping `(time-add day-t 86400)` from local midnight is wrong across a DST fall-back (Melbourne 2026-04-05): `00:00` → `23:00+10:00` (still the 5th) → `+86400` skips to the 6th's `23:00`, duplicating one date and missing the next. The hook buckets by **committer-date local calendar day** (`git-<%F>`), so enumeration must increment **calendar dates**, not seconds:

```elisp
(defun dl-satan-memory-evidence--git-feed-paths (root start end)
  "Return segments/git-%F.jsonl paths for every calendar day in [START, END]."
  (let* ((start-day (substring start 0 10))
         (end-day (substring end 0 10))
         (day start-day)
         (acc '()))
    (while (string-lessp day end-day)            ; lexical = chronological for %F
      (push (expand-file-name (format "segments/git-%s.jsonl" day) root) acc)
      (setq day (dl-satan-memory-evidence--next-day day)))   ; calendar +1 day
    (push (expand-file-name (format "segments/git-%s.jsonl" end-day) root) acc)
    (nreverse acc)))
```

`--next-day` uses calendar arithmetic (`calendar-gregorian-from-absolute` / `+1`), DST-immune because it never touches clock seconds. `string-lessp` on `%F` strings is a valid chronological order.

`--git-commits-status` already tolerates missing/unreadable paths (`cl-remove-if-not #'file-readable-p`) and `--filter-segments` bounds rows to `[start,end]`, so reading extra day-files is safe **for missing files**. **Malformed-line hardening (MEDIUM, external-review):** today one bad JSONL line anywhere makes the whole probe return `"malformed"` and drops *all* commits — a wider window enumerates more files, raising exposure. Wrap the per-file read so a parse error skips that file (degrade, don't blank), keeping good in-window commits from sibling files.

### 4.3 Repo-scoped, window-anchored "commit observed" predicate (DEC-2, revised post-external-review)

**External-review correction (CRITICAL).** `--after-state` (`observer-classify.el:102`) assembles with `:cwd = motive :project_cwd`, and the old P2 ran `git log` in that cwd — so P2 was implicitly **scoped to the motive's repo**. A naive "any commit, baseline-vs-after" replacement discards that scoping and would mark an intervention `:worked` (`observer-classify.el:478`) because the user committed in an *unrelated* repo. It would also misfire on pre-deploy baselines (`--baseline-read` returns non-nil old `git_state`-only evidence with no `:git_commits`, so "baseline empty → fire" fires once *per pending intervention* on any 24h commit).

**Corrected design** — drop the baseline comparison entirely; anchor to the attribution window and the motive's repo. Replace `:git_head_changed` / `--predicate-git-head-changed` (`:172-186`, registry `:408`) with `:git_commit_observed` / `--predicate-git-commit-observed`:

```elisp
(defun dl-satan-observer--predicate-git-commit-observed
    (_baseline after motive intervention)
  "Fire when AFTER perceives a commit in MOTIVE's repo during the window.
Scoped (like P1/P3) to MOTIVE's `:project_cwd'; no project_cwd → no fire.
A row matches when its `:repo' is MOTIVE's project root (path-normalised)
or its `:slug' matches a `project:' cue token, AND its `:end_ts' lies in
(`:intervention_emitted_at', window-end].  No baseline needed — the
attribution window is the anchor, so stale/pre-deploy baselines cannot
misfire."
  (let ((cwd (plist-get motive :project_cwd)))
    (and cwd
         (cl-some (lambda (row)
                    (and (dl-satan-observer--git-row-matches-motive row motive)
                         (dl-satan-observer--git-row-in-window
                          row intervention)))
                  (plist-get after :git_commits)))))
```

- `--git-row-matches-motive`: `(file-equal-p (expand-file-name (plist-get row :repo)) (expand-file-name cwd))`, falling back to `:slug` ∈ motive `project:` cue tokens.
- `--git-row-in-window`: `:end_ts` parsed to a time, strictly after `:intervention_emitted_at` and not after `--window-end-iso`.

This is strictly more correct than P2 (P2 only saw HEAD move in the cwd repo; this sees the actual commit row, cross-checked to the window). It needs neither a persistent watermark nor the baseline. Register under the same slot/order as P2 (`first-fire-wins` order preserved). The predicate scans **all** `after.git_commits` rows (not just a newest tail) — see §4.1 sort/limit note so window rows are never truncated away.

**Inherited limitation (HIGH, accepted v0):** `dl-satan-observer-classify` short-circuits to `:crosses_midnight` *before* `--after-state` (`observer-classify.el:469`) for interventions whose 30-min window spans midnight. The git predicate inherits that punt; the 24h feed window does not help because the observer never reaches `assemble`. Out of scope here — tracked as a follow-up (relax the midnight guard now that the git feed is day-spanning).

### 4.4 git_state demotion (DEC-3) & tank render

- `dl-satan-memory-evidence--git-state` (`:398`) keeps running (cheap; `:dirty` plumbing stays for the follow-up) but nothing in the *perception/outcome* path consumes its `:head_short`/`:commits` any more.
- Tank (`dl-satan-tank.el:201-205`) git line switches from `git_state` head/dirty to a `:git_commits` summary:

```elisp
(let ((gc (plist-get state :git_commits)))
  (format "git:           %d commit(s) since %s%s\n"
          (length gc)
          (or (plist-get state :git_window_start_at) "?")     ; not :window_start_at
          (if gc (format " · newest %s" (plist-get (car (last gc)) :sha)) "")))
```

(After §4.1's sort, `(car (last gc))` is genuinely the newest.)

`:dirty` is **not** rendered until the active-project follow-up lands (avoids surfacing a meaningless incidental-repo dirty flag).

**Second git_state consumer (left intentionally)**: canon's `cwd.project` rule (`dl-satan-memory-canon.el:414`) derives `project:<slug>` from `git_state.remote` (else `fs_state.cwd`). Because `git_state` stays in the plist, this rule is *not* broken by demotion; and `vcs.recent_commit` already emits the cross-repo `project:<slug>` and "`--merge` dedupes against `cwd.project`, keeping the higher-priority origin". So `cwd.project`'s git_state-derived emit is the lower-priority, pwd-coupled one — harmless under merge, but genuine noise. **Out of scope here**; the active-project follow-up that retargets `:dirty` should also retarget this rule's cwd/remote source. Named so it is not a later surprise.

## 5. Verification Alignment

See frontmatter `verification_alignment`. ERT suites under `satan/test/` (`*-memory-evidence-test.el`, `dl-satan-observer-test.el`). Key cases: git window admits a commit outside the 10-min focus window; multi-day `git-feed-paths` over a 3-day range; predicate fires-once-then-holds (`:git_commits` `:end_ts` fixtures); registry-order assertions updated to the renamed key; P2 fully removed (no `:git_head_changed` / `:head_short`-fixture references survive); live VA — throwaway commit + forced tick.

**Removal-surface checklist** (adversarial-review finding): `satan/dl-satan-observer-classify.el` (predicate + registry), `satan/test/dl-satan-observer-test.el` (cases + order asserts + fixtures), `docs/satan/attributes/outcome-semantics.md` (vocabulary), `CHANGELOG.md`. A final `rg ':git_head_changed|git-head-changed'` must come back empty (outside historical CHANGELOG context).

## 5a. Adversarial Review

### Internal pass (2026-06-02)

- **F1 — wider removal surface than first drafted.** Renaming the P2 key touches the observer test (cases, registry-order assertions, `:head_short` fixtures), `outcome-semantics.md`, and `CHANGELOG.md`. Integrated into §4.3 / §5 / code_impacts.
- **F2 — second `git_state` consumer.** Canon `cwd.project` reads `git_state.remote`. Not broken by demotion (plist retained) and superseded by `vcs.recent_commit` merge priority; named and scoped to the follow-up (§4.4).
- **F3 — filter semantics validated.** `--filter-segments` is overlap-based (`:end_ts ≥ start ∧ :start_ts ≤ end`); commit rows (instant `start_ts==end_ts`) included whenever the instant lies in window.

### External pass (gpt-5.2-codex via codex MCP, 2026-06-02)

- **CRITICAL — predicate lost repo scoping.** P2 was implicitly motive-repo-scoped via `--after-state`'s `:cwd = :project_cwd`; a cross-repo firer would credit interventions for unrelated commits. **Resolved** — §4.3 rewritten to scope by motive repo + anchor to the attribution window (no baseline).
- **HIGH — pre-deploy baseline misfire.** `--baseline-read` returns non-nil old evidence; "baseline empty → fire" would fire per pending intervention. **Resolved** — baseline comparison dropped entirely (§4.3).
- **HIGH — midnight guard bails before after-state.** Accepted v0 limitation; the git predicate inherits the punt; follow-up to relax the guard (§4.3).
- **HIGH — single `:window_start_at` would make the capsule lie.** **Resolved** — add `:git_window_start_at` (§4.1, §4.4).
- **HIGH — `(last filt limit)` over unsorted append order.** **Resolved** — sort by `:end_ts` before limiting; predicate scans full filtered set (§4.1, §4.3).
- **HIGH — DST `+86400s` day stepping.** **Resolved** — calendar-date enumeration (§4.2).
- **MEDIUM — one malformed line blanks the whole probe.** **Resolved** — per-file parse tolerance (§4.2).
- **MEDIUM — `sensor_status:git "ok"` ≠ commits exist.** **Resolved** — wording corrected (§3); success measured by non-empty `git_commits`.
- **MEDIUM — canon `--merge` is per-run, not cross-tick.** **Investigated & de-escalated** — per-tick canon `project:<slug>` emissions land in the per-run *percept capsule* (`percept.json`), not durable store traces (`memory-store-mark` is an explicit agent action, not auto-called per tick). Re-listing the backlog each tick is a benign view. DEC-2 (no watermark) holds; verify-and-guard *resolved* rather than guarded.
- **LOW — missed prompt-visible + doc surface.** `sensor-alerts.el` renders the `:git` sensor into the prompt; `docs/satan/perceptual-design.md` still describes the old git_state/observer semantics. Added to code_impacts.

### Governance

POL-001 (module extraction) not engaged; no spec authority moves; delta-first correct (no tech spec for this surface).

## 6. Design Decisions & Trade-offs

- **DEC-1** Git-only 24h window. *Alt*: widen the global window — rejected, would bloat focus/browser context and re-introduce stale-segment noise. *Alt*: per-feed window table — over-engineered for two distinct cases.
- **DEC-2** No persistent watermark; reuse baseline/after + canon merge. *Alt*: watermark file — more state, a storage-shape decision, and R1/R3; only justified if the capsule must visually flag "new since last tick" (not required). Verify-and-guard covers the one assumption (canon merge idempotence, Q1).
- **DEC-3** Demote, don't delete, `git_state`. *Alt*: delete it now — loses the `:dirty` plumbing the follow-up needs and forces an `fs_state`-style retarget in the same delta. Deferred deliberately.

## 7. Open Questions

- [x] Q1 — Canon `--merge` is per-run only; per-tick emissions populate the percept capsule, not durable store traces. Re-listing the 24h backlog is benign. **No watermark needed; DEC-2 holds.**
- [ ] Q2 — git capsule tail uses `seg-limit` (10); revisit only if a real day exceeds it (observer predicate scans the full filtered set, so unaffected). Owner: implementer.
- [ ] Q3 (follow-up delta) — relax the observer `:crosses_midnight` guard now that the git feed spans calendar days.

## 8. Rollout & Operational Notes

- **Migration**: none (behaviour-only). New file? No — edits to tracked `.el`, so `eval-buffer`/daemon restart suffices; no `home-manager switch` unless a file is added. §4.3 baseline edge is self-healing.
- **Observability**: success is directly visible — `sensor_status:git` flips to `"ok"` and `evidence_window.git_commits` populates in `~/notes/satan/runs/*/percept.json`.
- **Rollback**: revert the commit; feed returns to 10-min starvation (status quo ante), no data migration to undo.
