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

**"Unavailable" is four failures wearing two exit codes.** From the CLI's own
paths: binary missing (127), loader failure from a stray `LD_LIBRARY_PATH`
(127, diagnosis on stderr only), no compositor (`error: cannot connect to
umbriel socket`), and a stream closed with no line (exit 1). The current helper
collapses all four to `nil` (`lisp/dl-umbriel.el:25-36`), so a broken client is
indistinguishable from an empty desktop. The slice therefore owes more than an
empty-state message: it must name which failure it is showing. The loader case
is now `docs/emacs/traps.md` § 6.

**The socket removes half of those failures.** The JSON protocol is documented
for programs (`docs/user/ipc.md`: one object per line, typed action fields
validated by name, `{"ok":…}` / `{"err":…}` replies), and Emacs speaks a UNIX
socket natively (`make-network-process :family 'local`). Talking to it directly
executes nothing, so missing binary and loader failure cannot occur, errors
arrive as parsed `{"err":…}` rather than scraped stderr, and query, action and
stream share one transport. The compositor evicts a subscriber that stops
draining past 256 KiB (`src/server/ipc.cpp:711`); this holds through the CLI
too, so a stream ending under us is handled either way. Decided 2026-11-04 in
the design run (user assent), reversing the earlier non-goal.

## Scope & Objectives

1. **One socket client.** Resolve the socket path the way the CLI does
   (`UMBRIEL_SOCKET`, else `$XDG_RUNTIME_DIR/umbriel-$WAYLAND_DISPLAY.sock`),
   connect with `make-network-process :family 'local`, and frame replies by
   newline. One place sends a request object and parses its reply; queries,
   actions and the stream all go through it. Actions are typed request objects
   (`{"cmd":"action","action":…,<fields>}`), not CLI words. No `umbriel`
   process is executed, so `dl-umbriel--host-environment` and trap 6 cease to
   apply to this client.

2. **Live state from the event stream.** One long-lived socket connection
   sending `{"cmd":"subscribe","events":["windows","workspaces"]}`,
   newline-framed: each line is `{"event":…,"data":…}` carrying a *full
   snapshot* of that family. Replace held state per event; never merge deltas.
   Manual refresh stays available for the connection-down case. The compositor
   evicts a subscriber that stops draining past 256 KiB, so a stalled Emacs
   loses the stream rather than stalling the compositor. **Freshness is
   therefore connection liveness**, reported as open / closed (with reason) /
   never opened — not as a timestamp.

3. **A pure model over the parsed snapshots.** Accessors and the join that
   groups windows under their workspace, plus the display strings the buffer
   shows. No compositor calls, no buffer mutation — testable against fixtures.

   The model carries **two different addressing fields per workspace**, because
   the compositor does: the opaque `id` (synthesised `OUTPUT:serial`) joins a
   window to its workspace, while every workspace *action* takes a name or an
   index plus `--output`. Windows are the reverse — addressed by the opaque
   `id`. A row that keeps only what it displays cannot act; a row that keeps
   only ids cannot act on a workspace.

4. **The buffer.** `magit-section`, two top-level sections — workspaces, then
   windows nested under their workspace — each row showing the state that
   matters (name, layout, active/focused, occupancy; app id, title, placement,
   flags).

   Two signals must stay separate: `active` (seat-global) and `focused`
   (workspace-remembered) — a scratchpad or layer surface holding the keyboard
   makes them disagree. And the compositor's `visible` means "on the active
   workspace, not a hidden tab, not minimized", **not** "on screen": a window
   can be visible and scrolled out of view.

   Refresh without losing point, and a state that names its own failure rather
   than an empty list when the compositor is absent.

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

6. **Keys.** `my-umbriel-map` (`core/dl-keymap.el:249`) at `C-c u` carries the
   commands. The commented placeholder at `core/dl-keymap.el:433`
   (`;; (my/bind my-umbriel-map "u" #'something "hello" )`) is deleted, not
   inherited. Bindings per DEC-024: `C-c u` u/w/l/f globally; row keys in the
   buffer, with directional actions on both modified arrows and brackets.
   `C-c L` stays `my-llm-map`. No new family key is claimed, so the
   `C-c <letter>` allow-list and IMP-019 are untouched.

7. **The theory, written down.** `docs/emacs/umbriel.md`: the socket and its
   three access paths (query, action, subscribe), the snapshot-replacement
   rule, the activation-token reason focus needs the compositor, frame identity
   limits, the rule that Emacs holds no authority over layout state, and why
   Emacs uses the socket rather than the CLI.

8. **Tests and changelog.** ERT for the model, the request-object construction
   and the line framing; a `CHANGELOG.md` entry naming the commands and keys.

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

  `apps/dl-zmx.el` here predates `~/dev/zmux` (2026-10-01 vs 2026-11-02) and is
  **lag, not drift**; replacing it is **CHR-009**. This slice neither depends on
  nor blocks that work.
- Overview, screencast, effect presets, layers, outputs, input-capture
  permissions, tearing, colour management, virtual outputs.
- Mouse-driven control, and any local mirror of layout state that could
  disagree with the compositor.

## Affected surface

Split per DEC-014 (STD-001: one concern per file), in `apps/` beside the
other external-program integrations; every new file is
`git add`ed before any `home-manager switch` (trap 1).

- `apps/dl-umbriel.el` — the socket client: path, transport, stream, held
  state, failures (existing 65 lines `git mv`ed from `lisp/`, rebuilt; header rewritten)
- `apps/dl-umbriel-model.el` — new, the pure model and display strings
- `apps/dl-umbriel-buffer.el` — new, the `magit-section` buffer, its commands
  and buffer keymap
- `apps/dl-umbriel-focus.el` — new, the `server-switch-hook` frame focus,
  moved out of `dl-umbriel.el` and rebuilt on the client (DEC-023)
- `init.el` — requires `dl-umbriel-focus` and `dl-umbriel-buffer` in place of
  `dl-umbriel` (`:23`)
- `lisp/test/dl-umbriel-test.el` (client), `dl-umbriel-model-test.el`,
  `dl-umbriel-buffer-test.el`, `dl-umbriel-focus-test.el` — one per source file;
  the stale red focus test is replaced
- `core/dl-keymap.el` — populate `my-umbriel-map` (DEC-024), drop the placeholder
- `docs/emacs/umbriel.md` — new, the theory
- `CHANGELOG.md` — release note

## Risks & assumptions

- **No compositor is reachable from the agent environment** (`WAYLAND_DISPLAY`
  empty, no socket in `/run/user/1000`). Fixtures and `cl-letf` fakes carry the
  testable layers; the live check is manual, on the host, and the slice's exit
  criteria must say so rather than pretend otherwise.
- The subscribe connection is long-lived (opened by the buffer, closed when it
  is killed, DEC-018). Its lifetime, and reconnection after a compositor
  restart, are the parts most likely to rot silently — a closed connection
  must surface as stale state, not as a plausible-looking stale buffer.
- The stream is verbose during pointer drags (the compositor reports carried and
  dragged windows while the drag is held). Rendering must not become the
  bottleneck: repaint coalesced, and only the buffer that is displayed.
- Frame titles are not unique, so any command phrased as "the Emacs window"
  cannot be more precise than "some window whose title matches". Out of scope
  here, but the doc must not imply otherwise.
- Assumes Emacs's environment carries `UMBRIEL_SOCKET` or `XDG_RUNTIME_DIR` +
  `WAYLAND_DISPLAY` (the CLI needs the same), that the socket-path rule in
  `docs/user/ipc.md` stays stable, and that the JSON field names in
  `ipc_commands.cpp` and the action fields in `ipc.md` are the contract. A field rename upstream breaks
  the buffer silently; the model's accessors should default rather than error.
- Emacs has never owned a long-lived connection here (`set-process-filter`
  appears nowhere in this config today), so the risk is not complexity but
  silence: an unnoticed closed connection renders a plausible, permanently stale
  buffer.

## Verification / closure intent

- `just check` green (ERT suite), `bin/elisp-locate-paren-error` clean on every
  touched `.el`.
- ERT covers: workspace/window accessors and the workspace-join over fixtures;
  action request-object construction against `ipc.md`'s field table; the line
  filter
  against hand-fed lines, including a malformed line and a family the buffer
  ignores; the buffer rendering a fixture without a compositor; and that the
  failure modes (socket path unresolvable, socket absent or refused, connection
  closed, `{"err":…}` reply) reach distinct states rather than one `nil`.
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

- **Frame identity — IDE-003.** A creation-time handshake: each frame briefly
  carries a unique title token, the first snapshot showing it binds frame →
  window id (stable for the window's life), and `emacsclient -F` can add a role.
  Built on this slice's stream, id-keyed state and snapshot waiter (DEC-020).
  Everything below depends on it.
- **Tagging windows** to act on a set (all ghostel sessions, all notes frames).
  Emacs frames: frame parameters once IDE-003 lands. Other apps' windows: an
  Emacs-side map, or compositor-held `k:v` metadata if umbriel's developers take
  up the idea (the user is raising it; upstream is not ours to change).
- **Collect Emacs frames onto one workspace**, and its inverse: scatter.
- **Scratchpad management** — which windows are scratchpad members, revealed or
  hidden, from the same buffer.
- **zmx/ghostel composition** — group the buffer by session once frames are
  addressable, so a terminal is identified by its session rather than its title.
