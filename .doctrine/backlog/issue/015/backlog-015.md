# ISS-015: umbriel stream drops with connection broken by remote peer

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

The `*umbriel*` status line shows `umbriel: closed — connection broken by remote
peer (retry; g in *umbriel* reconnects)`.

Cause unknown. It may be a real fault in the stream, or a side effect of reloading
umbriel code into the live Emacs during IMP-030.

## Evidence

- 2026-11-07: seen at least three times across two IMP-030 sessions. In the second
  session the message was already showing at 11:40, before any code was reloaded
  in that session, and again at 11:46 after reloads.

- 2026-11-07 preflight findings. The message is Emacs's generic status for EOF from
  the peer, so it does not name a cause. Reloading code cannot produce it directly:
  a local `delete-process` reports `deleted`, and `umbriel--forget-process`
  detaches the handle first.
- The compositor journal has 8 lines `[ipc] subscriber fd N is not draining (~250 KB
  queued), disconnecting`, all today: 10:37:50, 10:57:13, 11:01:15, 11:09:23,
  11:12:24, 11:15:24, 11:37:15, 12:14:40. This is the eviction DEC-018 anticipated
  (`kMaxOutboundBacklog`, 256 KiB, `src/server/ipc.cpp` in umbriel).
- Other subscribers are ruled out: both `umbriel subscribe` processes have run since
  2026-11-06 08:46, and panopticon logged no `compositor_disconnected` today. The
  evicted subscriber is therefore short-lived. Emacs fits, but this is by elimination:
  the log names only an fd.
- 11:37:15 fits the 11:40 sighting. No eviction falls near 11:46, so that sighting is
  either the same closure still showing or another close path.
- Sizes: a `windows` event is a full snapshot of about 12.5 KB, so the cap is about 20
  events, plus the kernel socket buffer. At idle, 40 s produced no events after the
  snapshots.
- Unexplained: panopticon logged only 6 focus/title events in the 5 minutes before
  10:37:50 and 13 before 12:14:40. Its log undercounts broadcasts, but if the true
  count is near that, the subscriber had stopped reading for minutes, not stalled
  briefly.
- Next observation: on reconnecting, record the compositor-side fd of the Emacs
  connection (`ss -xp`) and compare it with the next eviction line.

- 2026-11-07 12:31 reproduced under observation. Reopened the stream at 12:20; the
  compositor logged `subscriber fd 168 is not draining (259072 bytes queued)` at
  12:31:07.850, and 168 is the compositor-side fd of the Emacs connection. Emacs then
  showed the message. The evicted subscriber is Emacs.
- The trigger is a broadcast storm, not a slow trickle. About 590 `windows` broadcasts
  (6.7 MB) arrived in about a second, starting with a focus change at 12:31:07.735,
  115 ms before the eviction. Earlier storms at 12:20:58, 12:21:07 and 12:21:19 were
  survived. 2447 broadcasts arrived in 10.5 minutes, so panopticon's log undercounts
  heavily and the "stopped reading for minutes" reading above is withdrawn.
- Emacs's per-event work is cheap: 27 us to parse a snapshot, 4 ms to repaint. At
  6.5 MB/s the cap plus socket buffer is about 70 ms of not reading, which is less
  than the 80 ms average GC pause here (inference; the stall itself was not observed).

- 2026-11-07 12:32 storm contents captured: 514 of 569 field changes were `x`, plus
  `w` 28, `y` 25, `active` 2, across two windows. `x` steps 4 px, then 1 px per
  broadcast (833, 838, 842 ... 1050, 1049, 1048). Read at the time as an animation;
  corrected below: these are pointer steps of a mouse drag.

- 2026-11-07 12:38-12:47 trials, compositor build `11c3a82`. Mod+R
  (`window-cycle-primary-extent`) alone is not a reliable trigger: most presses peaked
  at 3-9 broadcasts per 100 ms with no eviction. Toggling scratchpads peaked at 1-3
  per 100 ms, also no eviction, so scratchpads are ruled out as the trigger despite the
  earlier correlation with focus moving to them.
- Three storms were caught under the harness, at 12:39:29, 12:42:15 and 12:42:44: at
  least 144-191 broadcasts in 400-700 ms, 51-69 per 100 ms, mostly `x` with some `w`.
  Emacs was evicted in all three. Their trigger is unidentified.
- A subscriber pausing 50 ms or more at the start of a storm was evicted in two of the
  three, the 25 ms and shorter ones never. In the 12:42:15 storm Emacs was evicted but
  the 50 and 75 ms clients were not, so the pause placement matters and the threshold
  is approximate. Eviction is not specific to Emacs's code.

- 2026-11-07 12:52 trigger identified: dragging Emacs's tile edge with the mouse. Two
  drags gave two storms and two evictions, at 12:52:00 (104 broadcasts, 784 ms) and
  12:52:25 (399, 2616 ms). The neighbour's `x` changed in 92 and 318 steps and Emacs's
  `w` in 9 and 84, so a full `windows` snapshot goes out per pointer step and Emacs's
  own size changes far less often.

- 2026-11-07 12:53 drag trials on compositor `11c3a82`, four drags of Emacs's tile edge:
  Emacs evicted in 4 of 4. Bursts were 95-525 broadcasts over 1.1-3.4 s, peaking at
  21-34 per 100 ms. The 200 ms pause client was evicted in 3 of 4, the 100 ms client in
  1, the 25 and 50 ms clients in none. Two short storms with ghostty focused followed at
  12:55:03-04 (87 and 144 broadcasts in under 200 ms, peaking at 55 and 92 per 100 ms,
  mostly `x`). The 50, 100 and 200 ms clients were evicted and Emacs was not. What
  caused those two is unconfirmed.
- Next: repeat on compositor `1c8b369` (main) after relogging: drag Emacs's edge, then a
  border between two ghostty tiles, and compare.

- 2026-11-07 12:57-13:08 reproduced on compositor `1c8b369` (main). 12 bursts, peaks up
  to 99 broadcasts per 100 ms. Emacs was evicted at 12:57:01, and the 100 and 200 ms
  pause clients at 13:07:34, 13:07:38 and 13:08:30. So main does not fix it, and
  `wait_for_redraw`, the setting added by `aa3b6b3e`, is not enabled here. Bursts here
  were not matched to specific drags, so the rates are not comparable per drag with
  the `11c3a82` run.
- Code on main: `View::setDragPosition` (`src/view/view_animation.cpp`) schedules a
  `windows` broadcast on each changed position, and `Server::scheduleIpcWindowsEvent`
  merges only within one event-loop pass, not per frame. `Workspace::arrange`
  (`src/workspace/workspace.cpp`) also schedules one, with a comment saying the
  coalescer caps this at one per frame. The measured peak of 99 per 100 ms is far above
  that, so the coalescer does not do what the comment says. Not traced: how
  `applyDelta` reaches `arrange` for tiled drags.

- 2026-11-07 reported upstream: https://github.com/noctalia-dev/umbriel/issues/721. No
  Emacs change is planned while that is open. If the upstream fix does not land,
  automatic reconnect is the fallback; it needs a decision superseding DEC-018.

Add each further sighting here, with the time and what was happening.

- 2026-11-11 (SL-018): the client moved to the umbriel package, `~/dev/umbriel.el`. Paths and names above were rewritten to it (`dl-umbriel-*`, `my/umbriel-*` became `umbriel-*`; `my/umbriel-refresh` became `umbriel-buffer-refresh`).
