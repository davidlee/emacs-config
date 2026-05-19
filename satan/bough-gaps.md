# Bough CLI gaps surfaced by SATAN memory substrate

Two read-side capabilities are missing from `bough 0.1.0` that SATAN's
memory substrate works around in elisp. Both workarounds are stable;
neither blocks v1. Filing here so they can land at bough's pace.

Context: SATAN consumes bough exclusively via `bough --json` (no
direct PG access; enforced by grep-lint). The `bough_read` tool in
SATAN exposes six scopes — `node`, `recent_changes`, `active`, `day`,
`week`, `project_subtree` — and maps each to one or more CLI calls.
The two gaps below land in `recent_changes` and `project_subtree`.

---

## B1. Per-status-transition history

**Today**

`bough --json node tree` supports date filters on `updated_at` and
`created_at` (e.g. `--after updated_at=2026-05-19T00:00:00Z`) but
exposes no notion of *when status changed*. There is no `status_at`
filterable field, and no per-node history endpoint in the CLI.

**Why SATAN cares**

The `recent_changes` scope is meant to answer "which tasks moved
since X?" — the natural input to an evidence window. Without
status-change time, SATAN falls back to "nodes whose `updated_at >=
since`", which is correct but loose: a title rename, an annotation,
or a description edit all look the same as a status transition.

The substrate documents the looser semantics in its tool description
("nodes whose updated_at >= since"). When B1 lands, SATAN tightens
`recent_changes` to literal transitions; the trace schema already
admits `event:status_changed` and pairs like `bough_event:status_changed`.

**Proposed shape (either is sufficient)**

1. New subcommand:
   ```
   bough --json node history <NANOID> [--since ISO8601] [--limit N]
   bough --json node transitions --since ISO8601 [--workspace WS] [--limit N]
   ```
   Returns rows of `{nanoid, from_status, to_status, at, actor?}`.
   The workspace-wide form is what SATAN actually wants for
   `recent_changes`; the per-node form is independently useful for
   audit and would compose with `node`.

2. Or: extend `node tree` with a `status_at` filterable field
   (alongside `updated_at` / `created_at`), and emit one row per
   transition rather than one per node when the filter is active.
   Closer to existing surface area, harder to interpret — option 1
   is preferred.

**Plumbing**

Status changes already write rows somewhere (the TUI shows transition
history); exposing them is a read-path addition, not a model change.

---

## B2. `--max-depth N` on `node subtree`

**Today**

`bough --json node subtree <NANOID>` returns the full subtree with no
depth limit. There is no `--max-depth`, `--level`, or `--limit` flag.

**Why SATAN cares**

The `project_subtree` scope feeds the LLM a bounded view of a
project's structure. SATAN currently fetches the full subtree and
prunes in elisp at a configurable depth (default 3), marking the
truncation point with a `children_truncated_count` field so the
caller knows pruning happened. For small workspaces this is fine.
For larger projects (think: the user's personal task tree across
years), the full-subtree fetch is wasted work and the JSON pipe gets
unnecessarily large before the prune step throws most of it away.

**Proposed shape**

```
bough --json node subtree <NANOID> [--max-depth N]
```

- `--max-depth 0` returns the root only.
- `--max-depth 3` returns root + three levels of children.
- When the limit is hit, each truncated parent gets a
  `children_truncated_count: N` field in the JSON output (mirrors
  what SATAN already does in elisp).
- No flag → today's behaviour (full subtree). Backwards-compatible.

**Plumbing**

Pure server-side filter on tree assembly; no schema change.

---

## Not gaps, recorded for completeness

- `bough day show -d <DATE>` returning `error: day not found` for
  uncreated days is correct and SATAN handles it (the tool translates
  to `ok { day: null }`). No change needed.
- The lack of a `bough week` subcommand is fine; `day list MON SUN`
  composes adequately.
- `node get` returning only the node with `parent_nanoid` (not the
  chain or annotations) is acceptable — SATAN composes with `node
  annotations` and walks parent_nanoid upward. A convenience
  `--with-chain --with-annotations` would be ergonomic but not
  load-bearing; do not prioritise.
