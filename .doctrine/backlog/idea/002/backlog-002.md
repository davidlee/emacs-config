# IDE-002: Desktop reminders for timed org agenda entries via appt

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

Timed org entries (`SCHEDULED: <… 14:00>`, timestamped appointments) give no
advance reminder. Built-in `appt` provides reminders but only reads the
Emacs diary file, which this config doesn't use; the schedule lives in org
(`org/dl-org-agenda.el`, split personal / work files).

## Sketch

1. `org-agenda-to-appt` — feed today's timed org entries into appt; run at
   startup and on agenda rebuild (`org-agenda-finalize-hook`), refreshing
   (`appt-time-msg-list` reset) so removed entries don't linger.
2. `appt-activate`.
3. `appt-disp-window-function` → small wrapper over `notifications-notify`
   (desktop notification via the Sway notification daemon);
   `appt-delete-window-function` → no-op.
4. Behaviour test: a timed org entry yields an appt entry; the display
   function calls the notifier (stub `notifications-notify`).

## Open questions

- Personal and work files both, or one set? Different lead times?
  (`appt-message-warning-time`, `appt-display-interval`)
- Quiet hours / focus mode suppression.
- Overlap with SATAN's notify tool — should reminders route through it?

## Rejected alternative

The book config (*Use GNU Emacs*, Waclena) enables `appt-activate`,
`org-agenda-include-diary` and calendar diary/holiday marking. Without a
diary file these do nothing, the default holiday list is US-only, and its
`(require 'notifications)` is never wired to appt.
