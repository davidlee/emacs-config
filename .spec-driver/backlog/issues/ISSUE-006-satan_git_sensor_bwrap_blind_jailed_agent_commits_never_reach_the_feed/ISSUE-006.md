---
id: ISSUE-006
name: "SATAN git sensor bwrap-blind: jailed-agent commits never reach the feed"
created: "2026-06-05"
updated: "2026-06-05"
status: open  # one of: in-progress | open | resolved | triaged
kind: issue  # one of: audit | delta | design_revision | issue | memory | phase | plan | policy | problem | prod | requirement | risk | spec | standard | task | verification
categories: [satan, sensor]
severity: p2  # one of: p1 | p2 | p3 | p4
impact: systemic  # one of: user | systemic | process
---

# SATAN git sensor bwrap-blind: jailed-agent commits never reach the feed

## Problem

The SATAN git-activity sensor undercounts commits, and the observation traces
(`dl-satan-observer` / tick-pulse) consequently report the user as "idle /
reading" while a bwrap-jailed agent (`clanker`) is shipping large volumes of
code. The perception layer is reasoning from a deaf sensor.

## Root cause

The feed is produced by a global git `post-commit` hook
(`satan/bin/satan-git-post-commit`) wired via host `core.hooksPath`. A bwrap
jail carries none of its three prerequisites: the `~/.config/git/hooks/`
symlink isn't bind-mounted, `~/.local/state/behaviour/segments/` isn't mounted
writable, and the overlaid `$HOME` has no `~/.gitconfig`. So jailed-agent
commits never produce a segment row. **Not** author-filtering — the hook
records `%an` verbatim.

Full analysis + evidence: [[mem.fact.satan.git-sensor-bwrap-blind]].

## Evidence (2026-06-05)

- `~/dev/forgettable` last 50 commits: 30 `clanker`, 20 `David Lee`.
- 06-04 segment file: 16 `forgettable` rows, all `David Lee`, **zero
  `clanker`**.
- Secondary undercount: feed is 24h-windowed + `seg-limit`-capped.

## Fix (placement decided)

Capture moves to **panopticon** (`~/dev/panopticon`, owns
`~/.local/state/behaviour/`) as a new host-side producer modeled on
`sway_watcher`: poll tracked repos with `git log`, dedup by sha, append
segments. Host-side → env-agnostic → catches jailed commits; sandbox stays
sealed (do **not** mount the segments tree into the jail). Producer is
**Python** (panopticon house language; workload is syscall-bound). POL-001
confirms a git poller does not earn an `.emacs.d` seat.

## Cross-repo sequencing

1. **panopticon** (separate repo, no spec-driver): build `panopticon-git`
   producer + systemd service/timer. *Primary work; not governed by this
   project.*
2. **.emacs.d** (this project, deferred): once panopticon emits git segments,
   retire/demote `satan/bin/satan-git-post-commit` to avoid double-write, and
   reconcile AGENTS.md + the hook CAVEAT docs. *This is the future `.emacs.d`
   delta — premature to scope until (1) lands.*

