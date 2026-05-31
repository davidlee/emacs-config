---
id: IP-005-P03
slug: "005-satan_content_percept_content_read_tool-phase-03"
name: IP-005 Phase 03
created: "2026-05-31"
updated: "2026-05-31"
status: completed  # one of: completed | deferred | draft | in-progress | pending
kind: phase  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
plan: IP-005
delta: DE-005
---

# Phase 03 — panopticon.content percept rule + evidence probe (O3)

## 1. Objective

Wire captures into the percept layer: a `content-probe` reads the last-N
articles.jsonl rows into the evidence window as `:content_recent` (metadata
only — no bodies), and a `panopticon.content` defrule emits `content_domain:<d>`
handles from those rows. The rule_id is NOT excluded from §S2 resonance, so
captures admit the cue automatically. Per DEC-2, this is percept-SHAPING only —
NO write into the memory store.

## 2. Links & References

- **Delta**: DE-005 (O3; risks R5 DEC-2)
- **Design Revision Sections**: DR-005 §4.3 (percept rule contract), DEC-2 (percept-shaping only)
- **Prior art**: `dl-satan-memory-canon.el` — `panopticon.current.app` defrule pattern, `dl-satan-memory-canon--emit`
- **Prior art**: `dl-satan-memory-evidence.el` — probe pattern (cons 'ok DATA), sensor_status, raw plist
- **Prior art**: `dl-satan-resonance.el` — `dl-satan-resonance--excluded-rule-ids` (panopticon.* NOT excluded)
- **Shared idiom**: `dl-satan-tools-content--read-articles-jsonl` (lenient, from P01)
- **Shared idiom**: `dl-satan-tools-content-dir` (content store root)

## 3. Entrance Criteria

- [x] DR-005 locked (DEC-2 — percept-shaping only, no memory-substrate write)
- [x] P01/P02 established (lenient jsonl reader, content store directory)
- [x] Evidence module probe pattern understood (cons 'ok DATA + sensor_status)

## 4. Exit Criteria / Done When

- [x] Evidence probe `dl-satan-memory-evidence--content-probe` reads last-N articles.jsonl (metadata only) → `:content_recent`
- [x] `sensor_status :content` tracks content probe status
- [x] `panopticon.content` defrule emits `content_domain:<d>` handles, deduped within the rule
- [x] Rule_id NOT in `dl-satan-resonance--excluded-rule-ids` → admits §S2 gate
- [x] ert green: evidence probe returns correct shape, defrule emits deduped handles, admittability
- [x] Byte-compiles clean, zero lint

## 5. Verification

- Cases (VT-content-rule):
  - Evidence probe: returns `(cons 'ok [{:hash :domain :url :title :captured_at} …])` for N=10 default
  - Evidence probe: empty store → `(cons 'ok [])`, not error
  - Evidence probe: respects `dl-satan-memory-evidence-content-limit`
  - Evidence probe: malformed line → skipped (lenient reader)
  - Defrule: emits `content_domain:<d>` per unique domain, deduped
  - Defrule: empty `:content_recent` → no emissions
  - Resonance: `panopticon.content` handles admit §S2 (not in exclude list)
- Evidence: ert pass summary in §10.

## 6. Assumptions & STOP Conditions

- Assumptions: content-probe bound N=10 (configurable); metadata only — no bodies enter evidence; evidence assemble runs before canon (existing flow); `panopticon.content` is NOT in resonance exclude list by default.
- STOP when: evidence probe format doesn't match canon rule expectations, or DEC-2 boundary is unclear.

## 7. Tasks & Progress

_(Status: `[ ]` todo, `[WIP]`, `[x]` done, `[blocked]`)_

| Status | ID  | Description | Parallel? | Notes |
| ------ | --- | ----------- | --------- | ----- |
| [x] | 3.1 | Evidence content-probe + defcustom + assembly wiring | [ ] | `dl-satan-memory-evidence.el` |
| [x] | 3.2 | `panopticon.content` defrule in canon module | [ ] | `dl-satan-memory-canon.el` |
| [x] | 3.3 | ert suite — probe shape, defrule emissions, admittability | [ ] | reuse P01 fixture |
| [ ] | 3.4 | Byte-compile + lint + git add | [ ] | |

### Task Details

- **3.1 Evidence probe**
  - **Design / Approach**: Add `(require 'dl-satan-tools-content)`. Add defcustom `dl-satan-memory-evidence-content-limit` (default 10). Add `dl-satan-memory-evidence--content-probe` reading `articles.jsonl` tail (last N) → metadata-only plists. Wire into `assemble-with-bounds`: add to `sensor_status` (:content key) and `raw` (:content_recent key). Cue-only mode skips (nil data). Follow `segments-status` pattern.
  - **Files / Components**: `satan/dl-satan-memory-evidence.el`
  - **Testing**: ert via fixture

- **3.2 Canon defrule**
  - **Design / Approach**: `(dl-satan-memory-canon-defrule panopticon.content (ev _hints _ctx) …)` → from `:content_recent`, dedupe by domain using `cl-delete-duplicates`, emit `content_domain:<domain>` per unique domain. Follow `panopticon.current.app` pattern.
  - **Files / Components**: `satan/dl-satan-memory-canon.el`
  - **Testing**: ert via fixture

## 8. Risks & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| DEC-2: accidentally write to memory store | Defrule emits handles only (no store write); resonance gate admits but doesn't persist | open |
| content-probe reads whole articles.jsonl | Tail read bounded to N rows via `--read-articles-jsonl` + `last`; small enough for evidence window | open |
| Cross-module dependency (evidence→tools-content) | Acceptable — same in-tree family; evidence already depends on tools-activity | open |

## 9. Decisions & Outcomes

- `2026-05-31` — Phase scoped from DR-005 §4.3; P03 because it depends on P01 (lenient reader, content dir) but NOT P02 (independent module)

## 10. Findings / Research Notes

- **2026-05-31**: 40/40 ert pass (23 P01 + 8 P02 + 9 new). Evidence content-probe follows segments-status pattern (cons STATUS DATA). Defrule follows `panopticon.current.app` pattern. Resonance gate: `panopticon.content` NOT in exclude list → automatic §S2 admission.
- Evidence module now depends on `dl-satan-tools-content` (lenient reader). Content-probe is metadata-only (no bodies in evidence window).

## 11. Wrap-up Checklist

- [x] Exit criteria satisfied
- [x] Verification evidence stored (ert summary in §10)
- [x] DE/IP updated if scope shifted
- [x] Hand-off note to P04 (integration — home-manager switch + full suite + CHANGELOG)
