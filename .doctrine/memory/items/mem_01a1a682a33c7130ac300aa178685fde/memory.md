`doctrine check gate` proxies to `just gate` when unconfigured, and this repo's
justfile has no `gate` recipe, so it fails with "justfile does not contain
recipe `gate`". AGENTS.md's Commit Gate is `just check`; `doctrine check
commit` proxies to it. Use `just check` (host, session shell) for audit/close
gates until a `gate` recipe or doctrine check config is added.

To separate the committed tree from uncommitted user edits, run `just check`
in a detached `git worktree add --detach <scratch>/wt HEAD` — but
`dl-project/here-infers-from-buffer-not-tab-root` and
`dl-project/keeps-unrestored-layout` fail when the worktree lives under /tmp
(path-sensitive tests), so read those two as location artefacts there.
