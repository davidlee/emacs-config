
# bough B2: --max-depth N on node subtree

**Upstream bough CLI gap.** `bough --json node subtree <NANOID>` returns the
full subtree with no depth limit. SATAN's `project_subtree` scope fetches the
full subtree and prunes in elisp at a configurable depth (default 3), marking
the truncation with `children_truncated_count`. For large projects the
full-subtree fetch is wasted work and the JSON pipe is needlessly large.

Proposed shape: `bough --json node subtree <NANOID> [--max-depth N]`
- `--max-depth 0` → root only; `--max-depth 3` → root + three levels.
- truncated parents get `children_truncated_count: N` (mirrors elisp today).
- no flag → today's full-subtree behaviour (backwards-compatible).
- pure server-side filter on tree assembly; no schema change.

B1 (per-status-transition history) was closed by bough DR-116 (2026-05-21).

Migrated from `docs/satan/bough-gaps.md` §B2 (2026-05-30).
