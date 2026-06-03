---
id: DR-005
slug: satan_content_percept_content_read_tool
name: Design Revision - SATAN content percept + content_read tool
created: "2026-05-31"
updated: "2026-05-31"
status: accepted
kind: design_revision  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
aliases: []
owners: []
relations:
  - type: implements
    target: DE-005
  - type: relates_to
    target: POL-001
delta_ref: DE-005
source_context:
  - "satan/dl-satan-tools-activity.el — read-only consumer pattern, dl-satan-tool-register, (cons 'ok|'error …) return"
  - "satan/dl-satan-sensor-curiosity.el — sensor watermark/probe/emit clone target"
  - "satan/dl-satan-memory-canon.el — dl-satan-memory-canon-defrule, --emit; existing panopticon.* rules"
  - "satan/dl-satan-memory-evidence.el:597 — evidence-window builder (browser-probe -> :browser_segments)"
  - "satan/dl-satan-resonance.el — §S2 admission gate (non-excluded rule_id admits cue)"
  - "~/.local/state/behaviour/content/ — panopticon content store (articles.jsonl + <shard>/<hash>.{md,json})"
code_impacts:
  - path: satan/dl-satan-tools-content.el
    change: "NEW — content_read tool (recent/get/filter/search)"
  - path: satan/dl-satan-sensor-content.el
    change: "NEW — content-backlog sensor (curiosity clone)"
  - path: satan/dl-satan.el
    change: "EDIT — (require 'dl-satan-tools-content)"
  - path: satan/dl-satan-memory-canon.el
    change: "EDIT — defrule panopticon.content"
  - path: satan/dl-satan-memory-evidence.el
    change: "EDIT — content-probe -> :content_recent in evidence window"
  - path: ~/notes/satan/tools/content_read.md
    change: "NEW — mandatory tool behavioural text (dl-satan-tool--description errors if missing)"
  - path: satan/test/
    change: "NEW — ert fixtures + suites for tool/sensor/rule"
verification_alignment:
  - id: VT-content-tool
    impact: new
    note: "ert over temp content store: recent/get/filter/search + error/empty paths"
  - id: VT-content-sensor
    impact: new
    note: "ert watermark advance / backlog count with temp state file; watermark stored as max captured_at string (DEC-5), not formatted now()"
  - id: VT-content-rule
    impact: new
    note: "ert panopticon.content emits content_domain:* handles; admittable"
design_decisions:
  - "DEC-1: canonical body = .json text_content; search projection = .md (line snippets)"
  - "DEC-2: O3 = percept-shaping only (no memory-store write); true page-recall deferred"
  - "DEC-3: search via rg subprocess, soft-fail to empty matches"
  - "DEC-4: get is char-offset paginated (page-max 5000), not single capped blob"
  - "DEC-5: sensor watermark = max captured_at string seen verbatim, never formatted now() (format-mismatch bug)"
  - "DEC-6: articles.jsonl unbounded — recent-scan-max cap (500) for v1; daily rotation is producer-side follow-up"
  - "O-1: skip malformed JSONL lines (concurrent append) rather than propagate"
  - "O-3: search via call-process arg-vector, never shell-command"
open_questions: []
---

# DR-005 – SATAN content percept + content_read tool

## 1. Executive Summary

- **Delta**: [DE-005](./DE-005.md)
- **Status**: draft (update when approved)
- **Last Updated**: 2026-05-31
- **Synopsis**: Make panopticon's new page-content store perceivable and readable
  by SATAN, without touching the memory substrate. One read-only tool
  (`content_read`), one backlog sensor (curiosity clone), one percept rule
  (`panopticon.content`) that lets captures shape resonance admission. Page
  bodies are reached on demand via the tool, paginated; they are never inlined
  into the percept.

## 2. Problem & Constraints

- **Current Behaviour**: panopticon now persists the *content* of pages the user
  dwells on (>30s) or right-clicks, into `~/.local/state/behaviour/content/`.
  SATAN cannot see it. `activity_read`'s `recent_browser` scope sees tab
  *segments* (url/title/duration) but never page bodies.
- **Drivers / Inputs**: DE-005; the new panopticon content store (CI1).
- **Constraints / Guardrails**:
  - Read-only consumer. No writes/curation of the store. risk=`read`, no capability.
  - **No new redaction** — producer (panopticon extension) strips query/fragment
    and drops incognito; SATAN trusts that boundary exactly as `activity_read` does.
  - In-tree per POL-001 (thin-shell tool + canon rule + sensor all "earn the seat"/
    anti-candidate). No module extraction, no memory-substrate write.
  - Output must stay bounded (token budget): no scope returns a full body by
    default; `get` is paginated.
- **Out of Scope**: panopticon changes; `.md`/`content_html` as returned body;
  writing captures into the memory store; semantic/embedding recall; re-deriving
  browsing history from segments (that is `recent_browser`).

## 3. Architecture Intent

- **Target Outcomes**:
  - O1: `content_read` tool — list recent, get body (paginated), filter by
    domain/url, full-text search.
  - O2: content-backlog sensor — perceive uninspected captures (curiosity-style).
  - O3: `panopticon.content` percept rule — captures admit/shape resonance.
- **Guiding Principles**:
  - Mirror the established shapes (`tools-activity`, `sensor-curiosity`,
    `memory-canon` rules); abstract a shared helper only if it earns it.
  - The content store's **index of record is `articles.jsonl`**; metadata scopes
    read it, not a directory walk.
  - Bodies are pulled, never pushed: the percept carries metadata only; an agent
    fetches text via `get` when it decides to.
- **State Transitions / Lifecycle Impact**: sensor maintains its own watermark
  (`sensor-content.json`) advanced on emit; no other lifecycle state.

### Data flow (C4-ish)

```
panopticon ext ──writes──> ~/.local/state/behaviour/content/
                              ├─ articles.jsonl            (index of record)
                              └─ <shard>/<hash>.{md,json}  (md=snippet src, json.text_content=body)
                                        │
        ┌───────────────────────────────┼───────────────────────────────┐
        │ content_read tool (O1)         │ sensor-content (O2)            │ canon rule (O3)
        │  recent/filter -> articles.jsonl│  count captured_at>watermark   │  evidence: :content_recent
        │  get(hash,off)  -> json.text_content (paged)                    │  emit content_domain:<d>
        │  search(q)      -> rg .md -> hash -> articles.jsonl meta        │  -> admits §S2 resonance
        └────────────────────────────────────────────────────────────────┘
```

## 4. Code Impact Summary

| Path | Current State | Target State |
| --- | --- | --- |
| `satan/dl-satan-tools-content.el` | absent | NEW — `content_read` tool, 4 scopes, paginated `get` |
| `satan/dl-satan-sensor-content.el` | absent | NEW — content-backlog probe + watermark + disable switch |
| `satan/dl-satan.el` | requires `tools-activity` etc. | + `(require 'dl-satan-tools-content)` |
| `satan/dl-satan-memory-canon.el` | `panopticon.{current.app,docs_visit,domain_transition,…}` | + `panopticon.content` defrule |
| `satan/dl-satan-memory-evidence.el` | builds `:browser_segments` etc. | + content-probe → `:content_recent` |
| `~/notes/satan/tools/content_read.md` | absent | NEW — **mandatory** behavioural-text file; `dl-satan-tool--description` errors hard if missing (F-1). Mirror `activity_read.md` shape: scope docs, risk note, redaction-is-producer's-job caveat |
| `satan/test/` | — | NEW fixtures + ert suites (tool/sensor/rule) |

### 4.1 `content_read` tool contract (O1)

Register: `(dl-satan-tool-register (list :name "content_read" :risk 'read :args-schema … :handler …))`.
Handler returns `(cons 'ok PLIST)` / `(cons 'error STRING)` (activity convention).
`shard` = first 2 chars of hash. Reuse `dl-satan-jsonl-read-file` for `articles.jsonl`
and an activity-style `--read-json` for sidecars.

```
recent {limit}
  -> newest-first tail of articles.jsonl, metadata only
  -> (ok :scope "recent" :limit N
         :captures [{:hash :url :domain :title :captured_at :quality_score} …])

filter {domain, url}            ; at least one required
  -> articles.jsonl rows where (domain= DOMAIN) AND/OR (url contains URL), capped
  -> (ok :scope "filter" :domain D :url U :limit N
         :captures [{… + :excerpt} …])      ; excerpt from sidecar

get {hash, offset=0, limit=5000}
  -> char-offset page of <shard>/<hash>.json :text_content
  -> (ok :scope "get" :hash H :url :domain :title :captured_at
         :total_chars T :offset O :returned R :next_offset (or (+ O R) :null) :text "…")
  ; limit clamped [1, page-max=5000]; offset clamped (max 0 offset) (F-5);
  ;   offset>=T -> returned 0, text "", next_offset :null
  ; unknown hash (not in articles.jsonl)        -> (error "unknown content_hash: H")
  ; hash known but sidecar absent/unreadable    -> (error "content body missing for hash: H")  (F-6)
  ; NOTE: each page re-parses the full sidecar (incl. large content_html) to reach
  ; text_content. Acceptable: sidecars are single pages, parse is cheap; revisit
  ; (cache parsed text_content per hash) only if paging hot articles shows cost.

search {query, limit=10}
  -> rg --json --fixed-strings -i QUERY over <store>/  (recurses shard dirs; .md only via -g '*.md')
  -> group match lines BY FILE; file basename (minus .md) = hash; one snippet/hash (first match line, ≤200 chars)
  -> lookup each hash in articles.jsonl for metadata
  -> SORT matches by captured_at DESC (F-2: rg returns path-order, not recency)
  -> take first `limit` distinct hashes
  -> (ok :scope "search" :query Q :limit N
         :matches [{:hash :url :domain :title :snippet} …]
         :truncated_results BOOL)        ; t when more than `limit` hashes matched
  ; --fixed-strings: QUERY is literal, not regex (avoid metachar injection / rg error)
  ; INVOKE via call-process with an argument vector, NEVER shell-command (O-3):
  ;   no shell = no shell injection; --fixed-strings = no regex injection
  ; rg binary resolved by (or dl-satan-tools-content-rg-path (executable-find "rg")) (F-4)
  ; rg absent/error/no-match -> (ok … :matches [])   ; soft-fail, never error
  ; NOTE: rg matches .md frontmatter too (url/title) — acceptable (title hit is a valid hit)
```

**Caps (defcustoms):**
- `dl-satan-tools-content-default-limit` = 20, hard max 200 (recent/filter; mirror activity)
- `dl-satan-tools-content-search-limit` = 10, hard max 50
- `dl-satan-tools-content-page-max` = 5000 (chars/`get` page; clamps `limit`)
- search snippet trim ≤200 chars

**Store root**: `dl-satan-tools-content-dir` defcustom, default
`$XDG_STATE_HOME/behaviour/content/` (falling back to `~/.local/state/…`), honouring
`$XDG_STATE_HOME` like the sensors. NB `dl-satan-tools-activity-dir` hardcodes the
path — that is the bug, not the precedent (O-4); this delta does the right thing.

**rg binary**: `dl-satan-tools-content-rg-path` defcustom, default nil →
`(executable-find "rg")` (F-4). Do not hardcode `/run/current-system/sw/bin/rg`.

**Malformed-JSONL posture (O-1)**: `dl-satan-jsonl-read-file` *signals* on a bad
line. panopticon appends concurrently, so a tick can read a half-written tail
line. `content_read` (recent/filter), the sensor probe, and the evidence probe
therefore **skip malformed lines** (wrap per-line parse in `condition-case`,
drop+continue) rather than propagating — deliberately more defensive than
`activity_read`, justified by concurrent append + per-tick read frequency.

### 4.2 content-backlog sensor (O2)

Near-clone of `dl-satan-sensor-curiosity.el`:
- `dl-satan-sensor-content-probe (&key run-id ts)`:
  guard `(and run-id (bound-and-true-p dl-satan-attribute-updates-enabled))`;
  scan `articles.jsonl`, partition rows by `(string< watermark captured_at)`;
  `count` = uninspected rows, `high-water` = max `captured_at` string seen;
  when `count > 0`: `dl-satan-attribute-build-sensor-payload :reason "content_backlog"
  :sensor-type "panopticon_content_backlog" :metric-value count
  :metric-unit "uninspected_captures"` → `enqueue` → **`mark-inspected high-water`**
  (NOT `ts`/now — see DEC-5). Return t. Soft-fail on error (`message` + nil), like curiosity.
- State file `dl-satan-sensor-content-state-file` default
  `$XDG_STATE_HOME/satan/sensor-content.json`, key `:last_inspected` holding a
  verbatim `captured_at` string (UTC-millis-`Z`); initial watermark `""` (empty
  string sorts before all timestamps).
- `dl-satan-sensor-content-enabled` defcustom (disable switch).
- **Schedule**: call `dl-satan-sensor-content-probe` from the same tick site that
  calls `dl-satan-sensor-curiosity-probe` (locate in the tick/broker probe loop;
  add alongside, gated by `-enabled`).

### 4.3 `panopticon.content` percept rule (O3)

- **Evidence probe** (`dl-satan-memory-evidence.el`): a `content-probe` reading the
  last-N (default 10) `articles.jsonl` rows → `:content_recent` plist list
  `[{:hash :domain :url :title :captured_at} …]`. Metadata only — no bodies enter
  the percept. Bound N so the window stays small; truncation noted like
  `browser_segments_middle` drops.
- **Rule**: `(dl-satan-memory-canon-defrule panopticon.content (ev _hints _ctx) …)`
  → from `:content_recent`, `dl-satan-memory-canon--emit "content_domain:<domain>"
  'observed <pointer>` per row, deduped within the rule (busy reading → one handle
  per domain). rule_id `panopticon.content` is **not** in
  `dl-satan-resonance--excluded-rule-ids` → it admits the §S2 cue.
- Effect: captures influence *which* memory traces resonate. Page bodies are **not**
  recalled here — that is the deferred follow-up (DE-005 §7 / R5).

## 5. Verification Alignment

| Verification | Impact | Notes |
| --- | --- | --- |
| VT-content-tool | new | temp store fixture: recent ordering+clamp; get page/offset/next_offset/total + negative-offset clamp (F-5); unknown-hash AND missing-sidecar errors are distinct (F-6); filter domain/url; search snippet + dedupe-by-hash + recency sort (F-2) + result-cap over fixture `.md`; malformed-line skipped not propagated (O-1); empty-store all-scopes |
| VT-content-sensor | new | temp state file: backlog count > watermark; emit-once then mark-inspected advances; disabled → no emit; soft-fail on unreadable |
| VT-content-rule | new | `:content_recent` fixture → expected `content_domain:*` handles, deduped; admittability (non-excluded rule_id) |

Gate: `just check` green; zero lint; CHANGELOG updated.

## 6. Supporting Context

- DE-005 context inputs CI1–CI4; POL-001.
- Prior art: `dl-satan-tools-activity.el`, `dl-satan-sensor-curiosity.el`,
  `dl-satan-memory-canon.el` (`panopticon.*` rules), `dl-satan-resonance.el` §S2.

## 7. Design Decisions & Trade-offs

- **DEC-1** — Canonical body = `.json` `text_content`; search projection = `.md`.
  Rationale: text_content is the clean LLM-facing body but is a newline-poor blob
  (bad snippets); `.md` is line-structured (clean rg snippets). Same content, two
  projections. Consequence: search returns hashes+snippets, agent calls `get` for
  the body — a deliberate two-step that keeps search output bounded.
- **DEC-2** — O3 is percept-shaping only; no write into the memory store.
  Rationale: the memory substrate is the deferred IMPR-007 extraction candidate
  ("biggest editor-mismatch"); writing a new trace source into it now would grow
  the wrong half (POL-001). Consequence: "recall a captured page by topic" is
  *not* delivered here; captures instead bias which existing traces resonate, and
  bodies are reached via the tool. True page-recall is a named follow-up.
- **DEC-3** — search uses an `rg` subprocess (present at
  `/run/current-system/sw/bin/rg`). Soft-fails to empty matches (never errors) so
  a missing/failed rg degrades gracefully like other probes.
- **DEC-4** — `get` is char-offset paginated (page-max 5000), not a single capped
  blob. Rationale: deterministic bound on every page regardless of article length;
  long bodies remain fully reachable via `next_offset`. Consequence: callers loop
  on `next_offset` until `:null`.
- **DEC-5** — the sensor watermark is the **max `captured_at` string seen verbatim**,
  never a formatted `now()`. Rationale: content `captured_at` is UTC-millis-`Z`
  (`2026-05-31T05:25:45.968Z`); curiosity's `mark-inspected` defaults to
  `format-time-string "…%:z"` → local-offset form (`+10:00`). A lexical `string<`
  between the two formats is meaningless (compares `Z` vs `+`, millis vs none).
  Storing the high-water `captured_at` keeps every comparison within one format, so
  `string<` is valid. This is the one place the content sensor must NOT copy
  curiosity verbatim. (Sharp edge — flag for a memory record on close.) Confirmed by
  external review F-7: the broker passes `(plist-get prepare :time_now)` as `ts` —
  broker-generated, not a panopticon `captured_at`; comparing them lexically is
  meaningless.
- **DEC-6** — `articles.jsonl` grows unbounded (unlike daily-rotated `focus-*.jsonl`),
  and `recent`/`filter`/sensor-probe/evidence-probe all read the whole file — the
  last three on every tick (F-3). Accepted for v1 (negligible at hundreds of rows).
  Mitigations, cheapest first: (a) `recent` reads a bounded tail rather than the
  whole file — `dl-satan-tools-content-recent-scan-max` (default 500) caps rows
  parsed for the metadata scopes; (b) the **real** fix is daily rotation of
  `articles.jsonl`, which is a **panopticon (producer) change — out of scope here**,
  flagged as a follow-up. If the store reaches thousands of rows before rotation
  lands, revisit a seek-from-end tail read.

## 8. Open Questions

- [ ] None blocking. Implementation-time: confirm the exact tick/probe call site
  for the sensor (mirror curiosity's registration) during Phase execution.
- [ ] Follow-up (producer): daily-rotate `articles.jsonl` in panopticon — the real
  fix for DEC-6 unbounded growth. Out of scope for DE-005.

## 9. Rollout & Operational Notes

- **Migration / Backfill**: none — new files only.
- **Nix**: `dl-satan-tools-content.el` + `dl-satan-sensor-content.el` must be
  `git add`ed (flake parser sees only tracked files — trap #1) and sit under a
  parsed `configDir`; new `(require …)` means a `home-manager switch`, not just
  `eval-buffer`. `satan/` is already a parsed configDir (existing
  `dl-satan-tools-*.el` are installed), so no `emacs.nix` change is needed beyond
  tracking the new files.
- **Tool description file**: `~/notes/satan/tools/content_read.md` must exist before
  the first dispatch or the run crashes (F-1, `dl-satan-tool--description` hard
  error). It is NOT git-tracked under `.emacs.d` (lives in `~/notes`) — ship it in
  the same change but note it is outside the flake.
- **Observability**: sensor emits `panopticon_content_backlog` attribute signals;
  visible via the existing attribute/audit surfaces.
- **Recovery / Rollback**: set `dl-satan-sensor-content-enabled` nil to silence
  the sensor; the tool is read-only and inert unless called.

## 10. References & Links

- `docs/satan/perceptual-design.md` §S2 (resonance gate), sensor/percept v0.
- `docs/satan/INDEX.md`; `docs/emacs/traps.md` (Nix traps 1–4).
- POL-001 (extraction policy).
