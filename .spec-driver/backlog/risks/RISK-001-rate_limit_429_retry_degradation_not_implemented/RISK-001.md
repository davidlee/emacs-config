---
id: RISK-001
name: Rate-limit (429) retry/degradation not implemented
created: "2026-05-30"
updated: "2026-05-30"
status: suspected  # one of: accepted | expired | in-progress | open | resolved | triaged
kind: risk  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
categories: [satan, resilience]
likelihood: 0.2  # 0.0-1.0
severity: p3
impact: 0.2  # 0.0-1.0
---

# Rate-limit (429) retry/degradation not implemented

Tier-based wind-down is **token-only**: rate-limit degradation was deferred
because 0/91 recent failures were 429s — all were config errors or budget
ceiling. Rate-limit retry is a follow-up if it becomes a real problem.

**Trigger to act:** 429s appear as a real failure mode in the run history.
Unblocks the companion provider-error-typing work (IMPR-005).

Migrated from `docs/satan/resilience-design.md` §6 "Resolved decisions" #2 (2026-05-30).
