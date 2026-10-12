# ISS-011: Background window hijack: org buffer replaces selected window on 300s timer cluster

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Symptom

With no command running, the selected window switches from the buffer being
edited to an org agenda file: a weekly journal, or the job-search project
note. If it happens mid-typing, the next keys go to the org buffer in meow
*normal* state (`a` → `meow-append`, then `org-self-insert-command`).

## Evidence (2026-10-12, live session, temporary advice; since removed)

| Time | User | Window 110 change | Timers just before |
|---|---|---|---|
| ~12:06:54 | typing | `.typ` article → job-search `.org` | (ring not yet armed) |
| 12:26:54 | away | weekly w24 → w29 | buffer-terminator .343, savehist .530, org-alert-check .833 |
| 12:31:54 | away | weekly w29 → w39 | buffer-terminator .343, auto-revert .431, org-alert-check .833 |
| 12:36:54, 12:41:54 | present | none | same cluster |
| 12:46:54, 12:51:54 | present | none | org-alert timer **disabled** at ~12:44 |

- **No command running.** Lossage for the ~12:06 event: `g`, `r`
  `self-insert-command` in the `.typ`, then `a` → `meow-append`,
  `p` → `org-self-insert-command`. The switch happened between two
  keystrokes.
- **The hijacking buffer was freshly visited.** Each cycle,
  `Undo-Fu-Session discarding: file length mismatch` is printed for the
  incoming weekly. That message comes from `undo-fu-session--recover-safe`
  on `find-file-hook`, i.e. the buffer was *just visited*, and the only
  visitor in that cluster is `org-alert-check` (`org-map-entries` over
  95 agenda files). buffer-terminator (45 min inactivity) had killed it
  in between.
- **The 300s cluster.** buffer-terminator, savehist, org-alert all run at
  the :x1:54 / :x6:54 phase.

## Ruled out

- **buffer-terminator tab scan** (`buffer-terminator--get-all-tabs-buffers`,
  which applies each inactive tab's window configuration and restores it):
  run by hand from a timer twice, once with the frame focused while
  typing. Frames, windows, buffers and focus were identical before and after.
  It also never kills visible buffers.
- **alert / libnotify**: `alert-libnotify-notify` only runs `notify-send`.
- **super-save**: saves via `with-current-buffer`; displays nothing.
- **`org-map-entries`**: does not kill buffers it opens (no
  `org-release-buffers`).
- **magit-filenotify refresh** (seen at 12:51:34): when a magit buffer has
  no window, `magit--refresh-buffer-set-positions` swaps it into the
  *selected* window and restores the old buffer under `unwind-protect`.
  Restoration was always correct, but this is a neighbouring
  background-borrows-your-window path (via
  `my/agent-review--flush`).

## Fixed along the way (real bug, not this symptom)

`my/org-setup-margins` (`org/dl-org.el`) ended with
`(set-window-buffer nil (current-buffer))` on `org-mode-hook`, which put
*any* org buffer that started in the background into the selected window. Now
it refreshes only windows already showing the buffer. Tests in
`lisp/test/dl-org-test.el`. The symptom recurred after this fix was live.

## Unproven

The code path that actually calls the window change was never captured:
no hijack occurred while the backtrace trap (`set-window-buffer`,
`switch-to-prev-buffer`, displayed-buffer `kill-buffer`) was armed and
org-alert was on. Remaining candidates, all on the org-alert visit path:
a `find-file-hook` / `after-change-major-mode-hook` entry
(e.g. `my/journal--populate-if-empty`, global minor modes), or a
C-level window change not visible to Lisp advice.

## Current state

- 2026-10-12 ~12:44–13:00: org-alert off, buffer-terminator on. No hijack.
- 2026-10-12 ~13:00 on: **org-alert on, buffer-terminator off**
  (`editing/dl-persist.el`: `buffer-terminator-mode` commented out, pointing
  here). Org notifications are wanted more than buffer-terminator.
  Recurrence ⇒ org-alert alone is the cause; none ⇒ it's the interaction
  (org-alert re-visiting files buffer-terminator killed).

## Next

1. Confirm: with org-alert off, no hijack over a day of normal use.
2. If clean, re-enable org-alert and set buffer-terminator aside
   (or the reverse) to isolate the interaction: org-alert re-visiting files
   that buffer-terminator killed.
3. Alternative notifications without a 300s 95-file scan: IDE-002
   (`appt` via `org-agenda-to-appt`, built once a day), or point
   org-alert at a narrow file set.
4. Re-arm the backtrace trap (advice on `set-window-buffer` +
   `window-buffer-change-functions` logger + timer ring) if it recurs.
