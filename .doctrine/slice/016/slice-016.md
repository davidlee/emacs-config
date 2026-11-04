# umbriel window and workspace control surface

## Context

Umbriel is a Wayland compositor with a CLI over a UNIX-socket IPC
(`docs/user/ipc.md` in `~/.local/src/umbriel`). It answers queries
(`windows`, `workspaces`, `focused-window`, `outputs`, …), takes typed
actions (`umbriel msg <action> [args]` → `{"cmd":"action",…}`), and streams
full-snapshot events (`umbriel subscribe windows,workspaces`).

Emacs currently reaches into that only for one problem: `emacsclient` brings no
activation token, so the frame it reuses stays behind the terminal. `lisp/dl-umbriel.el`
looks the frame's window up by `(pid, title)` and calls
`umbriel msg window-focus <id>` on `server-switch-hook`. That is the whole
existing surface: one hook, one action.

Two facts drive the rest of this slice.

**The plain tables cannot back an interactive buffer.** `umbriel windows` prints
`[flags]app_id \t title \t [tile WxH+X+Y] …` and `umbriel workspaces` prints
`* DP-1: 1 [scrolling] (focused)` (rendered at `src/server/ipc_commands.cpp:130`
and `:212`). Neither carries a window id, a stable workspace id, or a window's
workspace — exactly the three things needed to act on a row and to nest windows
under a workspace. `--json` returns the same entries those tables are rendered
from (`windowEntry` at `ipc_commands.cpp:617`, `IpcCommands::workspaces` at
`:806`), so JSON is a requirement, not a preference.

**Emacs has no handle on its own windows beyond the title.** A frame's window id
is assigned by the compositor; Emacs can only describe the window by
`(emacs-pid, frame name)`. `frame-title-format`
(`core/dl-interface.el`) is `<buffer-file-name or %b> - GNU Emacs at <host>`, so
two frames showing the same buffer are indistinguishable, and
`dl-umbriel-window-id` returns whichever comes first. That bounds what this
slice can promise about "the Emacs windows" and is why naming/tagging them is a
follow-up rather than a phase.

## Scope & Objectives

1. **One client layer.** Keep `dl-umbriel--host-environment` (strip
   `LD_LIBRARY_PATH`, which otherwise breaks the `umbriel` binary) as the single
   environment scrub point, and add one place that launches an action and one
   that parses a JSON reply. Queries stay synchronous (`call-process`), actions
   asynchronous (`make-process`), as the existing code already does.

2. **Live state from the event stream.** One long-lived
   `umbriel subscribe windows,workspaces` process, newline-framed: each line is
   `{"event":…,"data":…}` carrying a *full snapshot* of that family. Replace
   held state per event; never merge deltas. Closes and restarts reconnect.
   Manual refresh stays available for the process-not-running case.

3. **A pure model over the parsed snapshots.** Accessors and the join that
   groups windows under their workspace id, plus the display strings the buffer
   shows. No compositor calls, no buffer mutation — testable against fixtures.

4. **The buffer.** `magit-section`, two top-level sections — workspaces, then
   windows nested under their workspace — each row showing the state that
   matters (name, layout, active/focused, occupancy; app id, title, placement,
   flags). Refresh without losing point; a visibly stale or unavailable state
   rather than an empty list when the compositor is absent.

5. **Actions from the section at point.** v1 set:
   - window: `window-focus`, `window-move-to-workspace`, `window-toggle-floating`,
     `window-kill`, `window-center`
   - column/strip: `column-move-left`, `column-move-right`,
     `layout-scroll-left`, `layout-scroll-right`
   - workspace: `workspace-switch`, `workspace-set-layout` (scrolling, dwindle,
     master, stacking, toggle)
   - resize: `window-cycle-primary-extent` / `-back`

   Every action re-reads (or awaits the next snapshot) rather than assuming the
   effect it asked for.

6. **Keys.** `my-umbriel-map` at `C-c u` carries the commands; the
   `project-vc-dir "hello"` placeholder is removed. `C-c L` stays
   `my-llm-map`.

7. **The theory, written down.** `docs/emacs/umbriel.md`: the socket and its
   three access paths (query, action, subscribe), the snapshot-replacement
   rule, the activation-token reason focus needs the compositor, the
   `LD_LIBRARY_PATH` trap, frame identity limits, and the rule that Emacs holds
   no authority over layout state.

8. **Tests and changelog.** ERT for the model, the argv/JSON construction and the
   stream framing; a `CHANGELOG.md` entry naming the commands and keys.

## Non-Goals

- **Scratchpad management, "collect all Emacs frames onto one workspace", and
  tagging Emacs windows.** These are the interesting next moves but each needs
  a frame-identity scheme that does not exist yet (see Context). Follow-ups, not
  phases here.
- **zmx and ghostel.** `~/dev/zmux`'s own doctrine settles where the boundary
  is: zmux supplies a session name and an attach argv and never names Emacs,
  ghostty, umbriel or systemd (`.smut/xjyJ6hf8wR75QVny_ha_l.json`,
  `VOCABULARY.md`); "open a window attached to session X" is umbriel's verb
  (`.smut/NfUwybMWibnvvdcYAMxp1.json`). So window integration belongs in this
  config, not in zmux — which is what this slice is. Composing zmx sessions into
  the buffer would require mapping ghostel buffers to frames, which needs the
  same missing frame identity.
- Overview, screencast, effect presets, layers, outputs, input-capture
  permissions, tearing, colour management, virtual outputs.
- Talking to the socket directly with `socat`/`make-network-process` instead of
  the CLI.
- Mouse-driven control, and any local mirror of layout state that could
  disagree with the compositor.

## Affected surface

- `lisp/dl-umbriel.el` — client, model, buffer, actions (existing 65 lines grow;
  split into a second file only if it stops reading as one responsibility)
- `lisp/test/dl-umbriel-test.el` — the existing ERT file, extended
- `core/dl-keymap.el` — populate `my-umbriel-map`, drop the placeholder
- `docs/emacs/umbriel.md` — new, the theory
- `CHANGELOG.md` — release note

## Risks & assumptions

- **No compositor is reachable from the agent environment** (`WAYLAND_DISPLAY`
  empty, no socket in `/run/user/1000`). Fixtures and `cl-letf` fakes carry the
  testable layers; the live check is manual, on the host, and the slice's exit
  criteria must say so rather than pretend otherwise.
- The subscribe process outlives buffers. Its lifetime, and reconnection after a
  compositor restart, are the parts most likely to rot silently — an exited
  child must surface as stale state, not as a plausible-looking stale buffer.
- The stream is verbose during pointer drags (the compositor reports carried and
  dragged windows while the drag is held). Rendering must not become the
  bottleneck: repaint coalesced, and only the buffer that is displayed.
- Frame titles are not unique, so any command phrased as "the Emacs window"
  cannot be more precise than "some window whose title matches". Out of scope
  here, but the doc must not imply otherwise.
- Assumes `umbriel` remains on `PATH` in a plain shell and that the JSON field
  names in `ipc_commands.cpp` are the contract. A field rename upstream breaks
  the buffer silently; the model's accessors should default rather than error.

## Verification / closure intent

- `just check` green (ERT suite), `bin/elisp-locate-paren-error` clean on every
  touched `.el`.
- ERT covers: workspace/window accessors and the workspace-join over fixtures;
  action argv construction and the JSON request shape; the stream filter
  against hand-fed lines, including a malformed line and a family the buffer
  ignores; the buffer rendering a fixture without a compositor.
- Manual host check, recorded in the slice notes: open the buffer, change focus
  and workspace from umbriel's own binds, confirm the buffer tracks without a
  manual refresh; run each v1 action and confirm the compositor's reply in the
  buffer or the echo area.
- `docs/emacs/umbriel.md` exists and answers: how to query, how to act, how the
  stream behaves, why focus needs the compositor, and where Emacs must not keep
  state.
- `CHANGELOG.md` names the buffer command and the `C-c u` keys.

## Summary

Give Emacs a real view of the compositor — one JSON client, one live snapshot
stream, one magit-section buffer, a small action set — so that moving frames,
switching workspaces and changing layout stop being terminal work.

## Follow-Ups

- **Frame identity.** Give each frame a unique, stable name so a window can be
  addressed as this frame, not merely a window with this title. Everything below
  depends on it.
- **Tagging Emacs windows** to act on a set (all ghostel sessions, all notes
  frames) at once.
- **Collect Emacs frames onto one workspace**, and its inverse: scatter.
- **Scratchpad management** — which windows are scratchpad members, revealed or
  hidden, from the same buffer.
- **zmx/ghostel composition** — group the buffer by session once frames are
  addressable, so a terminal is identified by its session rather than its title.
