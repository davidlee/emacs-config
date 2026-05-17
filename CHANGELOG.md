# Changelog

Notable changes to this Emacs config. Loosely dated; not versioned.

## 2026-05-17 — work compartment in `~/notes`

First-class work compartment under `~/notes/work/`, mirroring the
existing class taxonomy plus two work-native classes (`meetings/`,
`people/`).  `work.org` reroled from a sparse log into the curated
dashboard described in `work.local.md`; the pre-change contents are
preserved verbatim at `work/archive/legacy-work.org`.

**Filesystem (notes repo).** New subtree:

```
work/
  inbox.org             :work:inbox:
  intake/  journal/  weekly/  meetings/  people/
  projects/  areas/  sources/  references/  slips/  indexes/
  attachments/  archive/
  archive/legacy-work.org   ← verbatim copy of pre-change work.org
```

`work.org` itself is now the dashboard (priorities, commitments,
waiting-on, deadlines, active projects, people, meetings, daily +
weekly work review checklists, entry-point links) with
`#+filetags: :work:index:`.  Single commit in the notes repo.

**Path module.** `core/dl-notes-paths.el` extended with 16 work
constants (`dl-notes-work-file`, `dl-notes-work-dir`, then per-class
subdir constants for `inbox`, `intake`, `journal`, `weekly`,
`meetings`, `people`, `projects`, `areas`, `sources`, `references`,
`slips`, `indexes`, `attachments`, `archive`).  New `my/notes-ensure-dirs`
creates any missing personal or work directories at load time (and
on-demand) — a fresh clone is self-bootstrapping.

**Constructors.** `my/denote--new` now accepts a class string *or* a
list of class strings; work constructors prepend two keywords (`work`
+ class), so a meeting note ends up
`work/meetings/<id>--<slug>__work_meeting_<extras>.org` with
`:work:meeting:` in `#+filetags:`.  Eight new constructors land:
`my/denote-new-work-{project,area,source,slip,reference,index,
meeting,person}`.  `denote-known-keywords` extended with `meeting`,
`person`, `work`, and the cross-boundary tags `work-relevant`,
`work-adjacent`, `management`, `technical-leadership`.

**Journal/weekly.** `org/dl-denote-journal.el` refactored: the file-
name builder, skeleton builder, and `ensure-file` helper now take dir
/ suffix / tags arguments.  Personal `my/journal-note`, `my/weekly-note`,
`my/journal--ensure-today` continue to work unchanged; new
`my/work-journal-note`, `my/work-weekly-note`, and
`my/work-journal--ensure-today` write to `work/journal/` and
`work/weekly/` with `__work_journal.org` / `__work_weekly_journal.org`
suffixes and `:work:journal:` / `:work:weekly:journal:` tags.

**Capture.** Nested `("w" "Work")` group with six children:

```
w i  Work inbox        work/inbox.org           * TODO …                :work:
w j  Work journal      today's work journal     * %U %?                 under * Log
w t  Work task         work/inbox.org           * TODO %?               :work:task:
w m  Work meeting      work/inbox.org           * %? :work:meeting:     + ATTENDEES/DATE drawer
w p  Work person       work/inbox.org           * %? :work:person:      + WHO drawer
w r  Work reference    work/inbox.org           * %? :work:reference:   + URL/AUTHOR/DATE/LICENSE/TRUST drawer
```

Same shape as the existing `s/S/r` source/slip/reference pipeline:
fast capture into `work/inbox.org`; durable promotion via the work
constructors.  `w j` uses `my/work-journal--ensure-today` as the
capture target so the file is created with skeleton on first touch
of the day.

**Agenda.** Three scopes via `org-agenda-custom-commands` rather than
modal `org-agenda-files` mutation:

```
C-c a a   default dispatcher (combined union — the new default)
C-c a p   personal-only
C-c a w   work-only
C-c a c   combined (explicit)
```

`my/org-agenda-refresh-files` walks personal + work scopes with
`directory-files-recursively` and stores three lists
(`my/org-agenda-{personal,work,combined}-files`).  Custom commands
bind `org-agenda-files` to the appropriate list per invocation —
boundary by directory custody, not tag.  Crossover via `:work-relevant:`
deferred; appending a filtered list to `my/org-agenda-work-files` is
the one-line extension when that pattern materialises.

Excluded by design (mirrors the existing personal exclusion):
`areas/`, `indexes/`, `references/`, `sources/`, `slips/`, `archive/`,
`attachments/`, `intake/` and their work counterparts.

**Review.** Six work commands mirror the personal set 1:1, factored
through small private helpers (`my/review--open-inbox`,
`my/review--dired-newest`, `my/review--weekly-with-waiting`,
`my/review--stale-cutoff`):

```
my/review-work-inbox
my/review-work-intake
my/review-work-weekly
my/review-work-stale
my/review-work-references-retained
my/review-work-references-untrusted
```

Plus `my/work-org-ql-find` — work-scoped wrapper around `org-ql-find`
bound to `C-c n W q`.

**Keymap.** `C-c n W` is a fourth notes sub-prefix alongside
`N / m / v`.  Constructors live directly under `W` (so personal
constructors at `C-c n N …` aren't overloaded); reviews under `W v`.
Eighteen new binds total.  `SPC n W …` works automatically through
the existing `my-notes-map` Meow leader mirror — `W` is not in the
keypad reserved set (`g`, `m`, `c`, `x`).

**Touched:** `core/dl-notes-paths.el`, `org/dl-denote.el`,
`org/dl-denote-templates.el`, `org/dl-denote-journal.el`,
`org/dl-org-capture.el`, `org/dl-org-agenda.el`, `org/dl-review.el`,
`core/dl-keymap.el`, `NOTES.md`, `KEYS.md`.  Notes repo: `work.org`,
`work/inbox.org`, `work/archive/legacy-work.org`.  No new requires in
`init.el` — all extensions live in modules already loaded.

Deferred: cross-boundary `:work-relevant:` agenda inclusion; work
deadlines / people-followups / active-projects review surfaces
(add when friction earns them).

## 2026-05-17 — notes system overhaul, Phase 7 (root-note triage)

Content-level work in `~/notes/`. No Emacs-config changes — just
re-homing the 6 root-level Denote notes left after Phase 1 into class
subdirs, and adding the reference metadata block to the 2 LLM-era
markdowns so the Phase 6 review queries start surfacing them.

**Re-homing.** Six `git mv`s, history preserved. Classification:

| Note | New dir | Signal |
|---|---|---|
| `substrate__emacs_idea_project_tech.org` | `projects/` | `:project:` tag in filename |
| `emacs-note-system__emacs_org_project_tech.org` | `projects/` | `:project:` tag in filename |
| `ricing-emacs__emacs_oss_tech.org` | `projects/` | content: TODO/NEXT list of emacs packages = active workstream |
| `risk-governance-glossary__…` | `indexes/` | content: glossary ≡ index per plan |
| `proficiency-with-emacs__emacs_org_pkm_tech.org` | `areas/` | content: topic map for ongoing emacs learning |
| `orchestration__ai_design_dev_tech.org` | `areas/` | content: standing principles in a domain |

The plan said all 6 had explicit class tags. Only 2 actually did; the
rest were classified from content. No external file-path-based links
existed (only the files' own `#+identifier:` lines reference them) so
no link surgery was needed. Denote-id-based links would survive a
move regardless.

Note for `ricing-emacs` in `projects/`: agenda now pulls in its
TODO/NEXT items (`dl-notes-projects-dir` is in `org-agenda-files`).
That's the intended shape of project-tier notes; if any item should
not be agenda-visible, change its keyword.

**Reference metadata.** Both Markdown references in `references/`
gained the metadata block the Phase 1 plan specified
(`status: raw`, `trust: unreviewed`, `captured-at:`). Each updated
its `tags:` list to start with `reference`. The plan said both were
LLM-generated; only one actually is:

- `pkm-research-report__pkm_research_slop.md` — LLM-generated (has
  ChatGPT/Claude `citeturn…` citation markers). Tags now include
  `reference, llm, untrusted`; `source: llm-generation` added.
- `how-a-researcher-uses-denote__emacs_pkm_web.md` — human-written
  blog post from lambdaland.org. Tags include `reference, web`;
  `source-url: https://lambdaland.org/posts/2025-07-11_research_notes/`
  added; trust still `unreviewed` until reviewed.

**Verification.** Both Phase 6 review queries now match:
`my/review-references-retained` (ripgrep `status: raw`) → 2 hits.
`my/review-references-untrusted` (ripgrep `untrusted` /
`trust: unreviewed`) → 2 hits.

**Out of scope:** `~/tasks/{10_daily, 20_weekly, 30_projects,
50_notes}` legacy markdown (per plan: "out of scope for the Emacs
config but flagged"). Single-format `archive/`, `attachments/`,
`intake/` triage is also a content task and will happen as captures
roll through.

That closes the planned overhaul. Phases 1-7 done; everything left is
either content (triaging incoming captures) or downstream
elaborations (more `dl-review` queries, more capture templates as
they earn their keep, eventual `dl-citar.el` if a bibliography ever
materializes).

## 2026-05-17 — notes system overhaul, Phase 6 (review module)

Phase 6: `org/dl-review.el` lands with six review commands wired
under the `C-c n v …` sub-prefix that Phase 4 stubbed out. Two
shapes:

- **Navigational** — open the buffer you want for a review pass.
- **Reporting** — surface items matching a review predicate, via
  `org-ql` for Org files or `consult-ripgrep` for the mixed
  `references/` formats (.org / .md / .pdf / .html).

```
C-c n v i   my/review-inbox                 open inbox + jump to first TODO
C-c n v I   my/review-intake                dired intake/, sorted newest first
C-c n v w   my/review-weekly                open weekly note + side window of WAITING items
C-c n v s   my/review-stale                 org-ql: WAITING items untouched > my/review-stale-days (7 default)
C-c n v r   my/review-references-retained   ripgrep: references with `status: raw`
C-c n v u   my/review-references-untrusted  ripgrep: `:untrusted:` tag or `trust: unreviewed`
```

**Stale-WAITING predicate.** Approximation: a WAITING item is stale
if no timestamp (active or inactive) in its subtree falls within the
last `my/review-stale-days` (defvar, default 7). Captured as
`(and (todo "WAITING") (not (ts :from CUTOFF)))`. Not exact — true
"time in WAITING" requires walking LOGBOOK state-change entries — but
the timestamp-of-anything-recent approximation is honest enough for
weekly triage. The user can flip the defvar to tighten.

**References review uses ripgrep, not org-ql.** `references/` is
explicitly multi-format per the plan (LLM markdowns, PDFs, web
clippings, .org files). Both `v r` and `v u` use `consult-ripgrep`
against the literal metadata strings (`status: raw`,
`trust: unreviewed`, `:untrusted:`) so any format with those flags
shows up. Current matches: zero — the 2 existing LLM .md references
predate the Phase 1 metadata convention and haven't been tagged.
Tagging them is a content-level task (Phase 7-ish), unblocked but
not done.

**`my/review--notes-files`** picks the query universe:
`inbox.org`, `projects/`, `areas/`, `sources/`, `slips/`,
`journal/`, `weekly/`. References excluded — they're not authored
content. Intake also excluded — it's an object dump, not Org.

**Touched:** `org/dl-review.el` (NEW; `git add`-ed so the flake
parser sees it), `core/dl-keymap.el` (six binds under
`my-notes-review-map`), `init.el` (`require 'dl-review`).

Phase 7 (root-note triage; promote the 6 root-level Denote notes
into class subdirs; tag the 2 LLM .md references for review) is the
last config-related slice — and it's mostly content work, not
Emacs-config work.

## 2026-05-17 — notes system overhaul, Phase 5 (org-ql + consult-notes + consult-org)

Phase 5 of the notes overhaul: install the new retrieval tools and
wire them to the existing Phase 4 keybinds. Concrete saved-search and
review commands continue to defer to Phase 6 (`dl-review.el`).

**New modules:**

- `org/dl-org-ql.el` — installs `org-ql`. `C-c n q` (`org-ql-find`)
  bound in Phase 4 now resolves. The dashboards/queries mentioned in
  the plan land in Phase 6 alongside the review commands — they're
  the same body of work (`my/notes-stale-items`, weekly review etc.
  are all `org-ql` queries).
- `completion/dl-consult-notes.el` — installs `consult-notes` with
  per-class file-dir sources backed by `dl-notes-*-dir` constants:

  ```
  Journal     j    Slips       S    Areas       a
  Weekly      w    References  r    Sources     s
  Projects    p    Indexes     i
  ```

  Narrow keys are typed at the consult prompt to scope to one class
  (e.g. `j SPC` for journal only). `consult-notes-denote-mode` is
  enabled on top so bare Denote-named files at `dl-notes-root` (the 6
  root-level notes pending Phase 7 triage) are still picked up.

**`consult-org-heading` binding** (consult bundles `consult-org`):

- `C-c o h` (`my-org-map "h"`) — in-buffer outline search. Lives in
  `core/dl-keymap.el` so it inherits the meow leader mirror
  (`SPC o h`).

**citar skipped.** Plan §5 says "only if a bibliography exists. Skip
otherwise." `rg -l 'citar|bibliography'` against `~/notes` returned
nothing meaningful — no `.bib` files, no `bibliography:` org-cite
front matter. Adding `citar` now would be speculative. The Phase 2
"deferred module" `org/dl-citar.el` stays unborn until there's
content to back it.

**Nix install verified.** Both packages landed in the new
`emacs-packages-deps` derivation under:

```
share/emacs/site-lisp/elpa/{org-ql-20250421.133, consult-notes-20260222.1928}
```

(Plus transitive deps `org-super-agenda`, `peg`, `ts`.) `consult-org`
needs no install — bundled with `consult`.

**Note for the running session.** The currently-running Emacs is
still backed by the *old* wrapper's elpa cache, so a restart is
needed to load `org-ql` / `consult-notes` from the proper path
on init. In the meantime, the live-eval workflow used to verify
phase 5 added the new elpa subdirs to `load-path` ad-hoc; that's
session-local and goes away on restart, which is the right shape.

**Touched:** `org/dl-org-ql.el` (NEW), `completion/dl-consult-notes.el`
(NEW), `core/dl-keymap.el` (consult-org-heading bind), `init.el`
(two requires).

Phase 6 (review workflow — `dl-review.el` with inbox/intake/weekly
sweeps and stale-item queries) and Phase 7 (root-note triage) remain.

## 2026-05-17 — notes system overhaul, Phase 4 (capture pipeline + `C-c n …` consolidation)

Phase 4 of the notes overhaul (plan
`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). Two slices: capture
templates aligned with the promotion pipeline, and a single
`C-c n …` namespace with three sub-prefixes.

**New module: `org/dl-denote-templates.el`** — class constructors that
wrap `denote` per class. Each prompts for title + extra keywords, then
calls `denote` with the class tag prepended and the right subdir:

```
my/denote-new-project    -> projects/    :project:
my/denote-new-area       -> areas/       :area:
my/denote-new-source     -> sources/     :source:
my/denote-new-slip       -> slips/       :slip:
my/denote-new-reference  -> references/  :reference:
my/denote-new-index      -> indexes/     :index:
```

Class is encoded twice — by file location *and* by the leading keyword
— so downstream filters (org-ql, consult-notes, agenda regex) can pick
either signal.

**Capture rework (`org/dl-org-capture.el`).** Old template letters
`i / f / P / r` were replaced with a pipeline-aligned set; old `j`
datetree (`journal/log.org`) was retired in favour of appending into
today's Denote-named journal file:

```
c   Inbox text        -> inbox.org   * TODO …
j   Journal (today)   -> today's denote journal, under * Log
s   Source intake     -> inbox.org   * … :source:    + URL/AUTHOR drawer
S   Slip intake       -> inbox.org   * … :slip:
r   Reference intake  -> inbox.org   * … :reference: + URL/AUTHOR/DATE/LICENSE/TRUST drawer
p   Protocol          unchanged (sprig/org-capture-extension)
L   Protocol Link     unchanged
```

The `j` target uses a new helper `my/journal--ensure-today` in
`dl-denote-journal.el`, which creates today's file with the skeleton if
absent so capture has somewhere to land before the user has hit
`C-c n j` for the day. The helper is shared with `my/journal-note`
itself (extracted alongside `my/journal--today-file` and
`my/journal--today-skeleton`).

Dropped templates: `i` (renamed to `c`), `f` (use `c` and delete the
TODO marker, or `denote`/class constructors), `P` (use `C-c n N p`),
old `r` "Reading note" (repurposed for reference intake). The
`f` file-intake template the plan flagged as optional is not yet
written — intake-dir workflow is content-level (Phase 7).

**Keymap consolidation (`core/dl-keymap.el`).** Single `my-notes-map`
at `C-c n` (mirrored as `SPC n` via mode-specific-map = meow leader),
with three sub-prefixes (`my-notes-new-map`, `my-notes-manage-map`,
`my-notes-review-map`). Full table:

```
C-c n c   org-capture                          C-c n N p   new project
C-c n j   my/journal-note                      C-c n N a   new area
C-c n w   my/weekly-note                       C-c n N s   new source
C-c n n   denote                               C-c n N S   new slip
C-c n f   consult-notes              (Ph5)     C-c n N r   new reference
C-c n s   consult-notes-search…     (Ph5)     C-c n N i   new index
C-c n l   org-store-link                       C-c n N j   journal today
C-c n i   denote-link                          C-c n N w   weekly
C-c n o   org-open-at-point-global
C-c n g   org-mark-ring-goto                   C-c n m r   denote-rename-file
C-c n b   denote-backlinks                     C-c n m R   …-using-front-matter
C-c n q   org-ql-find               (Ph5)     C-c n m k   denote-rename-file-keywords
                                               C-c n m t   denote-rename-file-title
C-c n v   (review prefix — commands Ph6)
```

Phase-5 bindings (`f / s / q`) are wired to symbols that aren't yet
installed; the void-function error only surfaces if pressed before
Phase 5 lands. Cheaper than stubbing them out twice — `declare-function`
forms at the top of `dl-keymap.el` keep the byte-compiler quiet.

Plan §4b had split keyword edits into `m k` (add) and `m K` (remove),
but denote 3.x collapsed those into a single editor
(`denote-rename-file-keywords`) that prepopulates the existing list and
lets the user add or remove inline. Collapsed the bindings to match:
`m k` only, `m K` unbound.

**Migrations from previous bindings**:

- `C-c n n / l / b / r / R` (`:bind` block in `dl-denote.el`) → moved to
  `my-notes-map` (`n` denote, `i` denote-link [was `l`], `b` backlinks,
  `m r` rename, `m R` front-matter rename). The `dl-denote.el` `:bind`
  block was removed.
- `C-c n j / w` (`global-set-key` in `dl-denote-journal.el`) → moved to
  `my-notes-map`. The redundant `(define-key … "C-c n d" nil)` retire-
  binding is gone too — `C-c n d` simply isn't defined anymore.

**Denote known-keywords extended** to include the full class set
(`area`, `slip`, `index`, `weekly`) so completion at the keyword prompt
suggests them.

**Touched:** `org/dl-denote-templates.el` (NEW — `git add`-ed so the
flake parser sees it), `org/dl-org-capture.el` (template rewrite),
`org/dl-denote-journal.el` (factored helpers; binds moved out),
`org/dl-denote.el` (binds moved out; known-keywords extended),
`core/dl-keymap.el` (notes map + sub-prefixes + meow leader mirror),
`init.el` (`require 'dl-denote-templates`).

Phases 5-7 (org-ql / consult-notes / citar; review workflow; root-note
triage) remain.

## 2026-05-17 — notes system overhaul, Phase 3 (Denote-named journaling) + org-modern fix

**Journaling moves to Denote naming.** `dl-denote-journal.el` rewritten:

- `my/journal-note` (new name; replaces `my/daily-note`) →
  `journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org`. Today
  resolves to `20260517T000000--2026-05-17-sunday__journal.org`,
  matching the 5 migrated files from Phase 1.
- `my/weekly-note` (kept the name) → `weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org`.
  Identifier anchors on the ISO-week Monday, so the file sorts to the
  start of its week regardless of which day it's first opened. Today
  resolves to `20260511T000000--2026-w20__weekly_journal.org`.
- New helper `my/journal--iso-monday` shifts a time back to its ISO
  Monday using `%u` (1=Mon … 7=Sun).
- Templates set `#+title:`, `#+filetags:`, `#+date:` on first-open;
  body skeletons unchanged from before.

**Keybind rebind** (per the agreed Phase 4 keymap):

- `C-c n d` (was `my/daily-note`) — unbound via
  `(define-key global-map ... nil)`.
- `C-c n j` → `my/journal-note` (new).
- `C-c n w` → `my/weekly-note` (unchanged).

Roll-own rather than upstream: denote 4.1.3 in the Nix overlay ships
without the `denote-journal` submodule (split off in 4.x and not yet
packaged here). The roll-own is ~40 lines and lets us keep the exact
filename convention the migrated files use (`T000000` + weekday-in-slug).

The Phase 2 `j` capture template (datetree in `journal/log.org`) is
left in place — different ergonomic shape (quick fragment append vs.
full-page operational log). Retire later if it goes unused.

**org-modern fix** (longstanding no-op, flagged in Phase 2):

```elisp
;; was:
(use-package org-modern
  :after
  (add-hook 'org-mode-hook #'org-modern-mode)
  (add-hook 'org-agenda-finalize-hook #'org-modern-agenda))

;; now:
(use-package org-modern
  :hook ((org-mode            . org-modern-mode)
         (org-agenda-finalize . org-modern-agenda)))
```

`:after` takes a package list, so the two `add-hook` forms were being
parsed as package names and silently dropped — `org-modern-mode` was
never actually attached to `org-mode-hook`. Now it auto-enables on
every Org buffer (no more manual toggle).

**Touched:** `org/dl-denote-journal.el` (rewrite), `org/dl-org.el`
(org-modern hooks).

## 2026-05-17 — notes system overhaul, Phase 2 (module decomposition)

Pure refactor: split `org/dl-org.el` into focused modules. No behaviour
change — every binding, template, advice, and var resolves the same as
before.

**New modules** (all under `org/`, all tracked via git so the Nix flake
parser picks them up):

- `dl-org-capture.el` — capture templates (7: `i/f/j/P/r/p/L`),
  `my/capture-body`, `my/capture-entry`, `my/sanitize-link-description`,
  `my/org-capture-delete-client-frame` + the
  `my/org-capture-delete-frame-on-finalize` flag, advice on
  `org-capture-finalize`/`kill`, and the `C-c c` global binding.
- `dl-org-agenda.el` — `org-agenda-files` (now derived from
  `dl-notes-*` constants), `C-c a` global binding. Custom agenda
  commands land here in Phase 5.
- `dl-org-links.el` — `C-c l` (`org-store-link`). Home for the Phase 4
  consolidated `C-c n l/i/o/g` link namespace.
- `dl-denote-journal.el` — `my/daily-note`, `my/weekly-note`, and their
  `C-c n d/w` bindings. Home for the Phase 3 Denote-named rewrite.

**Slimmed `dl-org.el`**: keeps org defaults (directory, todo keywords,
tag-alist, log-done, return-follows-link, speed-commands), org-modern
and org-bullets styling, and the mode-hook spacing tweak. Everything
else moved out.

**init.el load order** (in section `;; Org`):

```
(require 'dl-org)
(require 'dl-org-capture)
(require 'dl-org-agenda)
(require 'dl-org-links)
(require 'dl-denote)
(require 'dl-denote-journal)
(require 'dl-org-roam)
```

**Modules deferred** rather than created empty (per "no half-finished
implementations"):

- `dl-denote-templates.el` — class constructors (`my/denote-new-project`
  etc). Phase 3/4 when they have content.
- `dl-org-ql.el` / `dl-citar.el` — Phase 5, when the packages land.
- `dl-review.el` — Phase 6.
- `dl-writing.el` — `core/dl-prose.el` already covers prose/spelling
  cleanly; the plan's `dl-writing.el` is redundant with what exists.
  Keeping `dl-prose.el` where it is.

**Known pre-existing bug** (left untouched, flagged for later):
`org-modern`'s `use-package` block uses `:after` followed by `add-hook`
calls — `:after` takes a package list, not body forms, so the hooks
never get added. `org-modern-mode` is currently not actually enabled on
`org-mode-hook`. Fix: change `:after` to `:config` (or `:hook`). Not
part of Phase 2's "no behaviour change" promise.

**Touched:** `init.el`, `org/dl-org.el` (slimmed), 4 new modules under
`org/`.

## 2026-05-17 — notes system overhaul, Phase 1 (paths + dirs + TODO)

First slice of the notes-system overhaul plan
(`~/.claude/plans/yes-use-dl-for-staged-quiche.md`). No new packages, no
module decomposition — just the substrate.

**Filesystem.** `~/notes` was a symlink to `~/tasks/00_inbox/`; promoted
in place: `rm` the symlink, `mv ~/tasks/00_inbox ~/notes`. Reorganised
inside the new real `~/notes/`:

- Created `intake/ journal/ weekly/ projects/ areas/ sources/ slips/
  indexes/ references/ attachments/ archive/`.
- `_archived/` → `archive/`, `assets/` → `attachments/`, `context/` →
  `references/` (the two LLM research markdowns land here; will need
  `:reference:llm:untrusted:` tags on review per the plan).
- 5 daily files in `2026/YYYY-MM-DD.org` → renamed to Denote-style
  `YYYYMMDDT000000--yyyy-mm-dd-weekday__journal.org` under `journal/`.
- Deleted empty placeholders (`indices/`, `notes/`, `refs/`, `writing/`)
  whose names don't match the new vocab. `projects/` was already
  on-name; kept.
- 6 root-level Denote notes left at root — homing into class subdirs is
  Phase 7 triage (content, not config).
- `.git/`, `.gitignore`, `.org-roam.db` preserved via the bulk dir
  move. Corpus history intact.
- `~/tasks/{10_daily, 20_weekly, 30_projects, 40_areas, 50_notes,
  90_archive}` left untouched — legacy parking, separate triage.

**New module: `core/dl-notes-paths.el`.** Single source of truth for
notes paths. Defines `dl-notes-root`, `dl-notes-inbox-file`, and
per-class dir constants (`dl-notes-{intake,journal,weekly,projects,
areas,sources,slips,indexes,references,attachments,archive}-dir`), plus
`my/notes-path` for joining segments under root. Required early in
`init.el` (after `dl-core`).

**Downstream rewires** (replace string literals with constants):

- `org/dl-org.el`: `org-directory`, `org-default-notes-file`,
  `org-agenda-files`, all capture-template file paths, and
  `my/daily-note`/`my/weekly-note` now derive from `dl-notes-*`. Daily
  and weekly point at the new `journal/`/`weekly/` dirs but keep the
  simple `YYYY-MM-DD.org` / `YYYY-WNN.org` naming for now — Denote-named
  rewrite is Phase 3. Agenda dropped the (gone) `writing/` and added
  `weekly/`. Duplicate `(global-set-key "C-c c" #'org-capture)` (had
  shadowed itself at L130) removed.
- `org/dl-denote.el`: `denote-directory` → `dl-notes-root`.
- `org/dl-org-roam.el`: `org-roam-directory` → `(file-truename
  dl-notes-root)`. Roam stays wired but unused (separate
  acceleration layer per the plan; not the primary navigator).

**TODO state expansion.** Old: `TODO NEXT WAIT | DONE CANCELLED`. New:
`TODO NEXT STARTED WAITING(w@/!) | DONE(d!) CANCELED(c@) MOVED(m@)`.
Logging triggers added (`!` for done, `@` for waiting/canceled/moved).
One existing match (`work.org:5` had `** WAIT`) swept via `sed` to
`WAITING`. `CANCELLED` → `CANCELED` rename had no matches.

**Touched:** `core/dl-notes-paths.el` (new — tracked via git so the Nix
flake parser sees it), `init.el`, `org/dl-org.el`, `org/dl-denote.el`,
`org/dl-org-roam.el`, plus the filesystem migration outside the repo.

Phases 2-7 (module decomposition, Denote-based journaling, capture
template rework + keymap consolidation, org-ql/consult-notes/citar,
review workflow, root-note triage) remain.

## 2026-05-16 — org-protocol capture from Firefox

Wired up [sprig/org-capture-extension](https://github.com/sprig/org-capture-extension)
end-to-end. Three bugs found en route:

- **Desktop handler used `%F` (files) instead of `%u` (URL)**, so the
  Emacs-provided `emacsclient.desktop` silently dropped the
  `org-protocol://` URI and created a blank frame. New
  `~/.local/share/applications/org-protocol.desktop` (tracked via the
  sparse `~/` worktree) handles the scheme with `%u`, `--create-frame`,
  `--no-wait`.
- **`(concat org-directory "protocol.org")`** produced
  `~/notesprotocol.org`. Replaced with `expand-file-name`.
- **Duplicate template key `p`**: "Project task" shadowed "Protocol"
  (assoc returns first match). Renamed Project task to `P`.

Templates corrected to use the org-protocol plist keys (`%:link`,
`%:description`) instead of `%u` (which is the inactive timestamp, not
the URL) and `%c` (clipboard pollution).

Two improvements from the sprig README, with safety tweaks:

- **`my/sanitize-link-description`** replaces `[` `]` in the `L`
  template's description so ArXiv-style titles don't break the
  `[[link][desc]]` syntax.
- **Auto-close the emacsclient frame** after `org-capture-finalize` /
  `org-capture-kill`.  Uses a boolean flag set by the template (cleaner
  than sprig's counter) and guards with `(frame-parameter nil 'client)`
  + `(cdr (frame-list))` so manual `C-c c p` from the main frame is
  safe and the last frame is never deleted.  Refile is covered by the
  finalize advice — refile calls finalize internally.

**Touched:** `org/dl-org.el`, `~/.local/share/applications/org-protocol.desktop`.

## 2026-05-16 — session leader + meow `h` as C-c, autosave hook fix

Two related cleanups around the leader system.

**`my-session-map` (`C-c j` / `SPC j` / `h j`).** Easysession's defaults
were `C-c s*`, which `define-key` silently descended into `my-search-map`
(squatting in the search namespace). Moved them onto their own prefix
with which-key labels and meow leader mirror, via `my/bind`:

```
C-c j s   save           C-c j r   rename
C-c j l   load           C-c j R   reset
C-c j L   load+geometry  C-c j u   unload
                         C-c j d   delete
```

**Meow normal `h` → `mode-specific-map`.** Bound `h` directly to the C-c
keymap, so `h f f`, `h j s` etc. work from normal state as a third path
alongside `C-c` and `SPC`. Bonus over `SPC`: lowercase `g` / `m` work
without the capital workaround (no meow-keypad in the way). Dropped
`meow-left` — home-row arrows live on a layer.

**Autosave bug.** `(add-hook 'after-focus-change-function …)` was wrong
— that variable holds a single function (`#'ignore` advised by
`blink-cursor--rescan-frames`), not a hook list. `add-hook` cons'd the
function onto the existing advised form, producing an uncallable list and
spamming `Invalid function:` on every focus event. Replaced with
`add-function :after`, arity-tolerant via a `&rest _` wrapper.

**Touched:** `core/dl-keymap.el`, `editing/dl-persist.el`, `KEYS.md`.

## 2026-05-16 — file manager: dired/dirvish + yazi/broot wrappers

Consolidated the file-management stack on Dired + Dirvish, with Yazi and
Broot reachable as ghostel terminals that hand a path back to Emacs on
exit. Single home for everything under `my-file-map` (`C-c f` / `SPC f`):
`d` dired-jump, `D` dirvish, `t` dirvish-side, `F` project-find-file, `p`
project-switch, `y` yazi, `b` broot. Existing `f/s/S/r` kept.

Retired `dired-preview`, `dired-sidebar`, `nerd-icons-dired`, `dired-subtree`,
plus a duplicate `recentf` block in `editing/dl-persist.el` and the stray
`("C-c f" . dirvish-dwim)` bind that was shadowing the prefix. `C-x C-n`
moved from `dired-sidebar-toggle-sidebar` to `dirvish-side`.

Yazi uses `--cwd-file`, Broot uses `--outcmd` (parses the `cd PATH` line —
use **alt-enter** to fire `:cd`). Sentinel kills the ghostel buffer on exit.

See `FILE_MANAGER.md` for the full layout and the traps hit along the way
(missing `(require 'dl-dirvish)` in `init.el`, `lexical-binding` cookie on
the wrong line).

**Touched:** `apps/dl-dired.el`, `apps/dl-dirvish.el`, `core/dl-keymap.el`,
`core/dl-interface.el`, `editing/dl-project.el`, `editing/dl-persist.el`,
`init.el`.

## 2026-05-16 — nixd over nil, with flake-aware completion

Switched the Nix LSP from `nil` to `nixd` and fed it workspace settings so it
can evaluate the flake at `~/flakes`:

- `nixpkgs.expr` resolves to the flake's own nixpkgs input → completion for
  real package attrs (`pkgs.<TAB>`).
- `options.nixos` → `nixosConfigurations.Sleipnir.options` (option completion
  + docs under `config.*` in NixOS modules).
- `options.home-manager` → `homeConfigurations.david.options` (same for HM
  modules).
- `formatting.command` → `alejandra`, matching the flake's treefmt.

Hostname and HM user are hardcoded constants in `lang/dl-nix.el`. First
completion in a session is slow (full flake eval); subsequent calls are
cached. Activate with `M-x eglot-reconnect` in a `.nix` buffer.

**Touched:** `lang/dl-nix.el`.

## 2026-05-16 — vterm → ghostel

Replaced the vterm/multi-vterm/vterm-toggle stack with [ghostel](https://github.com/dakra/ghostel)
(libghostty-vt). Shpool session management (`apps/dl-shpool.el`) was ported to
ghostel's API in the same change — `shpool attach` is now spawned directly via
`ghostel-exec` instead of "open vterm, then send `exec shpool attach NAME`".

**Touched:** `apps/dl-term.el`, `apps/dl-shpool.el`, `core/dl-keymap.el`.

### Recovery — restoring vterm

To roll back, drop ghostel and reinstate the three blocks below in
`apps/dl-term.el`, plus the old `my-term-map` bindings in `core/dl-keymap.el`.

`apps/dl-term.el` (was the entire ghostel section):

```elisp
(use-package vterm
  :commands vterm
  :custom
  (vterm-kill-buffer-on-exit t)
  :bind (:map vterm-mode-map
          ("C-c <escape>" . vterm-send-escape))
  :config
  (setq vterm-max-scrollback 100000))

(use-package multi-vterm
  :after vterm
  :commands (multi-vterm multi-vterm-next multi-vterm-prev))

(defun my/vterm-named (name)
  "Open or create a named (for NAME) vterm buffer."
  (interactive "sVTerm name: ")
  (let ((buf-name (format "*vterm:%s*" name)))
    (if (get-buffer buf-name)
      (pop-to-buffer buf-name)
      (vterm buf-name))))

(use-package vterm-toggle
  :custom
  (vterm-toggle-hide-method 'delete-window)
  (vterm-toggle-fullscreen-p nil)
  :bind (([C-f1] . vterm-toggle)
          ([C-f2] . vterm-toggle-cd))
  :init
  (add-to-list 'display-buffer-alist
    '((lambda (buffer-or-name _)
        (let ((buffer (get-buffer buffer-or-name)))
          (equal major-mode 'vterm-mode)))
       (display-buffer-reuse-window display-buffer-at-bottom)
       (dedicated . t)
       (reusable-frames . visible)
       (window-height . 0.3)))
  :config
  (define-key vterm-mode-map [(control return)] #'vterm-toggle-insert-cd)
  (define-key vterm-mode-map (kbd "M-n")        #'vterm-toggle-forward)
  (define-key vterm-mode-map (kbd "M-p")        #'vterm-toggle-backward))
```

`core/dl-keymap.el` — replace the current `ghostel`/`ghostel-other` lines:

```elisp
(my/bind my-term-map "t" #'multi-vterm      "vterm")
(my/bind my-term-map "n" #'multi-vterm-next "vterm-next")
(my/bind my-term-map "P" #'multi-vterm-prev "vterm-prev")
```

`apps/dl-shpool.el` — shpool used to `(vterm buf-name)` then send
`exec shpool attach NAME\n` via `vterm-send-string` + `vterm-send-return`.
Mode checks were `'vterm-mode'`. Git history at this commit's parent has the
full pre-port version if needed.
