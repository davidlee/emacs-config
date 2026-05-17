# NOTES.md — the notes system, as built

Replaces `notes-plan.local.md` (the design spec). This file describes the
implemented system: layout, modules, key surfaces, conventions, and the
opportunities deferred for later.

## What's in place

### Filesystem

```
~/notes/
  inbox.org             text capture queue
  protocol.org          firefox / org-protocol landing
  calendar.org          calendar exports
  work.org              long-running work log
  intake/               raw file/object dump (un-classified)
  journal/              daily operational log (Denote-named)
  weekly/               weekly review log (Denote-named, ISO week)
  projects/             outcome-oriented work
  areas/                ongoing responsibility / domain notes
  sources/              authored notes about external content
  slips/                durable authored ideas
  references/           retained external content (.org / .md / .pdf / .html)
  indexes/              maps and entry points
  attachments/          binaries linked from notes
  archive/              retired material
```

Own git repo. Single source of truth.

### Path module

`core/dl-notes-paths.el` — `dl-notes-root` + `dl-notes-{inbox-file,
intake-dir, journal-dir, weekly-dir, projects-dir, areas-dir, sources-dir,
slips-dir, references-dir, indexes-dir, attachments-dir, archive-dir}`.
Everything that references the corpus derives paths from these constants.

### Org module split

```
org/dl-org.el                 defaults, TODO states, styling
org/dl-org-capture.el         capture templates + protocol helpers
org/dl-org-agenda.el          org-agenda-files + C-c a
org/dl-org-links.el           C-c l store-link (other link binds in notes map)
org/dl-org-ql.el              org-ql install
org/dl-denote.el              Denote core config
org/dl-denote-templates.el    class constructors (my/denote-new-*)
org/dl-denote-journal.el      my/journal-note + my/weekly-note
org/dl-review.el              review surfaces (my/review-*)
org/dl-org-roam.el            wired but unused
completion/dl-consult-notes.el  per-class consult-notes sources
```

### TODO sequence

```
TODO(t)  NEXT(n)  STARTED(s)  WAITING(w@/!)  |  DONE(d!)  CANCELED(c@)  MOVED(m@)
```

Logging on `DONE / WAITING / CANCELED / MOVED`.

### Capture templates (`C-c c`)

```
c   Inbox text         inbox.org           * TODO …
j   Journal (today)    today's denote journal, under * Log
s   Source intake      inbox.org           :source:    + URL/AUTHOR drawer
S   Slip intake        inbox.org           :slip:
r   Reference intake   inbox.org           :reference: + URL/AUTHOR/DATE/LICENSE/TRUST drawer
p   Protocol           protocol.org        full sprig/org-capture-extension body
L   Protocol Link      protocol.org        link-only sprig template
```

Inbox is the universal landing pad; class tags hint at promotion target.
Promotion (inbox → class file) is manual: refile + class constructor +
delete the inbox stub.

### Class constructors (`C-c n N …`)

`my/denote-new-{project,area,source,slip,reference,index}` — each prompts
for title + extra keywords, prepends the class keyword, drops the file in
the right subdir. Denote identifier handles addressability regardless of
location.

### Reference metadata

Markdown (YAML frontmatter) — used in `references/`:

```yaml
title:       "Title"
date:        2026-05-17T00:00:00+10:00
tags:        ["reference", "<class>", ...]
identifier:  "20260517T000000"
status:      raw            # raw | reviewed | promoted | obsolete
trust:       unreviewed     # unreviewed | trusted | untrusted
captured-at: 2026-05-17T00:00:00+10:00
source-url:  "https://…"    # if applicable
source:      llm-generation # if applicable
```

Org files use `#+filetags: :reference:<class>:` + matching `#+status:`
/ `#+trust:` keyword lines.

LLM-generated content is `trust: unreviewed` + tagged `:llm:untrusted:`
by default until reviewed.

### Keymap (`C-c n …`, mirrored as `SPC n …` via meow leader)

Full table lives in `KEYS.md`. Condensed here for self-containment:


```
C-c n c   org-capture                          C-c n N p   new project
C-c n j   my/journal-note                      C-c n N a   new area
C-c n w   my/weekly-note                       C-c n N s   new source
C-c n n   denote                               C-c n N S   new slip
C-c n f   consult-notes                        C-c n N r   new reference
C-c n s   consult-notes-search-in-all-notes    C-c n N i   new index
C-c n l   org-store-link                       C-c n N j   journal today
C-c n i   denote-link                          C-c n N w   weekly
C-c n o   org-open-at-point-global
C-c n g   org-mark-ring-goto                   C-c n m r   denote-rename-file
C-c n b   denote-backlinks                     C-c n m R   …-using-front-matter
C-c n q   org-ql-find                          C-c n m k   denote-rename-file-keywords
                                               C-c n m t   denote-rename-file-title
C-c n v i   my/review-inbox                    (jump to first TODO)
C-c n v I   my/review-intake                   (dired intake/, newest first)
C-c n v w   my/review-weekly                   (weekly note + WAITING side window)
C-c n v s   my/review-stale                    (WAITING untouched > my/review-stale-days)
C-c n v r   my/review-references-retained      (ripgrep: status: raw)
C-c n v u   my/review-references-untrusted     (ripgrep: untrusted / unreviewed)
```

`C-c o h` → `consult-org-heading` (in-buffer outline search).

### consult-notes per-class narrow keys

At the consult prompt: `j w p a s S r i` SPC narrows to journal /
weekly / projects / areas / sources / slips / references / indexes.
Bare Denote-named files at `dl-notes-root` come through
`consult-notes-denote-mode`.

## Design principles (the ones that bite)

- **Org files are the source of truth.** Databases, caches, indexes are
  acceleration layers. Any single package should be removable without
  destroying the corpus.

- **Class vs state.** Class = what a note *is* (project / area / source
  / slip / reference / index / journal / weekly / archive). State = where
  it *is* in the workflow (inbox, active, waiting, done, canceled,
  unreviewed, trusted, untrusted). `inbox.org` and `intake/` are states,
  not classes.

- **Capture must be fast; triage can be slow.** Templates exist to drop
  fragments in without classifying. The promotion pipeline (inbox →
  source / slip / reference; intake → references / attach / delete) is
  where classification happens.

- **Promote only when material earns permanence.** Delete aggressively
  from `inbox.org` and `intake/`. Capture queues are not archives.

- **Authored vs retained must stay separate.** `references/` is
  retained external content (verbatim). `sources/` is authored
  interpretation of that content. `slips/` is a single durable claim
  extracted from sources / journal / etc.

- **LLM output is external, untrusted reference material** until
  reviewed and refined.

- **Denote-id addressability.** Files can move between class subdirs;
  Denote identifier in the filename + front matter keeps Denote-id links
  working. Path-based links break — avoid them.

- **Directories give coarse ergonomics. Tags / properties give
  retrieval metadata. Links give semantic relationships.** Don't
  conflate.

- **Reports and queries beat schema expansion.** Before adding a new
  tag or front-matter field, ask whether an `org-ql` predicate over
  existing data would do.

- **Build review loops before elaborate taxonomies.** Phase 6
  `dl-review.el` exists so the system has feedback. New conventions
  are easier to justify once a review surface exposes the gap.

## What's deferred

Concrete next steps if/when the friction is felt:

- **Capture templates that earn their keep.** A file-intake template
  (drops a path into `intake/`, opens a capture pointing at it) was
  scoped in the plan, deferred — wire it when a file-intake habit
  actually forms.

- **More `org-ql` dashboards.** Active-projects view, this-week's
  STARTED items, recently-modified-by-class. Add to `dl-review.el`
  per concrete request.

- **Smarter stale-WAITING.** Current predicate is "no timestamp in
  N days" — approximation. True "time in WAITING" needs LOGBOOK
  walking. Replace if approximation gives false positives.

- **References review for non-flagged content.** `v r` and `v u`
  only surface entries with explicit `status:` / `trust:` /
  `:untrusted:` markers. New references default to `status: raw`,
  so anything captured after Phase 7 surfaces automatically. Pre-
  Phase-7 unflagged content is invisible — triage manually or
  backfill metadata.

- **Citar.** Skipped — no bibliography content. Wire `dl-citar.el`
  when a `.bib` or org-cite `bibliography:` shows up.

- **Active-keyword discovery.** Denote infers keywords from
  existing files (`denote-infer-keywords t`) so completion learns
  the corpus vocabulary. If a tag taxonomy emerges that needs
  enforcement, consider `denote-known-keywords` enforcement or a
  pre-save hook — not yet warranted.

- **`~/tasks/` legacy markdown** (`10_daily/`, `20_weekly/`,
  `30_projects/`, `50_notes/`) — out of scope for the Emacs config.
  Triage per-tree (move into new layout, archive in bulk, or delete)
  whenever the user makes the call.

- **`indexes/` content.** Topic maps, project maps, area maps —
  built by hand as the corpus grows. Convention exists; content
  doesn't yet.

- **Agenda scope.** `org-agenda-files` currently scans `inbox.org`,
  `projects/`, `journal/`, `weekly/`. `areas/` and `indexes/` are
  excluded by design (ongoing responsibility / map content, not
  actionable). Revisit if recurring tasks end up in `areas/` notes.

## Pointers

- `~/.emacs.d/KEYS.md` — full keymap reference (this doc has only the
  notes-map subset).
- `~/.emacs.d/CHANGELOG.md` — phase-by-phase history of the build-out.
- `~/.emacs.d/AGENTS.md` — Nix integration traps (read before editing
  packaging-adjacent code).
- `~/.emacs.d/CLAUDE.md` → `AGENTS.md` — project conventions for AI
  collaborators.
- `~/.claude/plans/yes-use-dl-for-staged-quiche.md` — the original
  implementation plan (phases 1-7). The plan is done; this file is the
  forward-looking reference.
