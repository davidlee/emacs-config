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
  work.org              work dashboard (curated; not a sink)
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
  work/                 work compartment (see below)
```

Work compartment mirrors the class taxonomy plus two work-native
classes (`meetings/`, `people/`) and has its own inbox + intake +
archive — directory custody, not just tag:

```
~/notes/work/
  inbox.org             work text capture queue
  intake/               work file/object dump
  journal/              daily work log (Denote-named, __work_journal.org)
  weekly/               weekly work review (Denote-named, __work_weekly_journal.org)
  meetings/             durable meeting notes
  people/               1:1 / standing follow-ups
  projects/             work projects
  areas/                ongoing work responsibilities
  sources/              authored notes about work content
  references/           retained work material
  slips/                durable work claims / insights
  indexes/              work maps / entry points
  attachments/          binaries linked from work notes
  archive/              retired work material
```

`~/notes/work.org` is the **dashboard**: priorities, commitments,
waiting-on, deadlines, active projects, people, meetings, work review
checklists, entry-point links.  It is curated by hand and is **not**
a capture sink — fast work capture lands in `work/inbox.org`.

Own git repo. Single source of truth.

### Path module

`core/dl-notes-paths.el` — `dl-notes-root` + `dl-notes-{inbox-file,
intake-dir, journal-dir, weekly-dir, projects-dir, areas-dir, sources-dir,
slips-dir, references-dir, indexes-dir, attachments-dir, archive-dir}`,
plus a parallel `dl-notes-work-*` set for the work compartment
(`dl-notes-work-file`, `dl-notes-work-dir`, then `-inbox-file`,
`-intake-dir`, `-journal-dir`, `-weekly-dir`, `-meetings-dir`,
`-people-dir`, `-projects-dir`, `-areas-dir`, `-sources-dir`,
`-references-dir`, `-slips-dir`, `-indexes-dir`, `-attachments-dir`,
`-archive-dir`).  Everything that references the corpus derives paths
from these constants.  `my/notes-ensure-dirs` (called at load) creates
any missing dirs so a fresh clone bootstraps without manual `mkdir`.

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
c    Inbox text         inbox.org             * TODO …
j    Journal (today)    today's denote journal, under * Log
s    Source intake      inbox.org             :source:    + URL/AUTHOR drawer
S    Slip intake        inbox.org             :slip:
r    Reference intake   inbox.org             :reference: + URL/AUTHOR/DATE/LICENSE/TRUST drawer
p    Protocol           protocol.org          full sprig/org-capture-extension body
L    Protocol Link      protocol.org          link-only sprig template

w i  Work inbox         work/inbox.org        * TODO … :work:
w j  Work journal       today's work journal, under * Log
w t  Work task          work/inbox.org        :work:task:
w m  Work meeting       work/inbox.org        :work:meeting:    + ATTENDEES/DATE drawer
w p  Work person        work/inbox.org        :work:person:     + WHO drawer
w r  Work reference     work/inbox.org        :work:reference:  + URL/AUTHOR/DATE/LICENSE/TRUST drawer
```

Inbox is the universal landing pad; class tags hint at promotion target.
Promotion (inbox → class file) is manual: refile + class constructor +
delete the inbox stub.  Fast work capture lands in `work/inbox.org`;
durable work material is promoted via `my/denote-new-work-*`.

### Class constructors

Personal — `C-c n N …`:
`my/denote-new-{project,area,source,slip,reference,index}` — each
prompts for title + extra keywords, prepends the class keyword, drops
the file in the right subdir.

Work — `C-c n W {p,a,s,S,r,x,m,P}`:
`my/denote-new-work-{project,area,source,slip,reference,index,
meeting,person}` — same pattern, but prepends **two** keywords
(`work` + class), drops the file under `work/<class>/`, so a meeting
note ends up at `work/meetings/<id>__…__work_meeting_<extras>.org`
with `:work:meeting:` in `#+filetags:`.  Class is encoded twice — by
location *and* by tag — so downstream filters (org-ql, consult-notes,
agenda regex) can pick either signal.

Denote identifier handles addressability regardless of location.

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

C-c n W h   open work.org (dashboard)          C-c n W p   new work project
C-c n W i   open work/inbox.org                C-c n W a   new work area
C-c n W I   dired work/intake/                 C-c n W m   new work meeting
C-c n W j   my/work-journal-note               C-c n W P   new work person
C-c n W w   my/work-weekly-note                C-c n W s   new work source
C-c n W q   my/work-org-ql-find                C-c n W S   new work slip
                                               C-c n W r   new work reference
                                               C-c n W x   new work index

C-c n W v i   my/review-work-inbox                 (jump to first TODO)
C-c n W v I   my/review-work-intake                (dired work/intake/)
C-c n W v w   my/review-work-weekly                (weekly + WAITING side window)
C-c n W v s   my/review-work-stale                 (work WAITING > stale-days)
C-c n W v r   my/review-work-references-retained   (ripgrep status: raw)
C-c n W v u   my/review-work-references-untrusted  (ripgrep untrusted)
```

Agenda dispatcher: `C-c a a` combined (default), `C-c a p` personal-only,
`C-c a w` work-only, `C-c a c` combined (explicit).  `C-c o h` →
`consult-org-heading` (in-buffer outline search).

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

- **Agenda scope.** `org-agenda-files` is the combined union of
  personal + work operational files (inbox + journal + weekly +
  projects; work also pulls in meetings + people).  `areas/`,
  `indexes/`, `references/`, `sources/`, `slips/`, `archive/`,
  `attachments/`, `intake/` and their work counterparts are excluded
  by design (ongoing responsibility / map / retained material, not
  actionable).  Scope is picked per invocation via
  `org-agenda-custom-commands`: `C-c a p` personal, `C-c a w` work,
  `C-c a c` combined.  `my/org-agenda-refresh-files` rebuilds the
  file lists; call after adding new dirs / notes if you don't want to
  wait for the next restart.

- **Cross-boundary tags.** `:work-relevant:`, `:work-adjacent:`,
  `:management:`, `:technical-leadership:` are in `denote-known-keywords`
  so completion offers them.  Auto-inclusion of `:work-relevant:`
  personal files in the work agenda is deferred — append a filtered
  file list to `my/org-agenda-work-files` when that pattern earns its
  keep.

## Pointers

- `~/.emacs.d/KEYS.md` — full keymap reference (this doc has only the
  notes-map subset).
- `~/.emacs.d/CHANGELOG.md` — phase-by-phase history of the build-out.
- `~/.emacs.d/AGENTS.md` — agent orientation (links to Nix integration
  traps at `docs/emacs/traps.md`; read before editing packaging-adjacent code).
- `~/.emacs.d/CLAUDE.md` → `AGENTS.md` — project conventions for AI
  collaborators.
- `~/.claude/plans/yes-use-dl-for-staged-quiche.md` — the original
  implementation plan (phases 1-7). The plan is done; this file is the
  forward-looking reference.
