# IDE-004: Make zmx sessions first-class in ghostel integration

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

`apps/dl-zmx.el` terminals are `ghostel-exec` buffers running `zmx attach`, not
plain shell buffers. Most ghostel extensions assume a plain shell, so they skip
or mishandle these buffers. The value is in closing that gap, not in enabling
the extensions as shipped.

Assessed against ghostel `3f3631e` (2026-11-06), module 0.61.0.

## Evidence: zmx forwards terminal reports to ghostel

Ran one script emitting the sequences below, directly in ghostel (control) and
through `zmx attach`, recording ghostel's hooks in hidden buffers. Both runs
recorded the same events.

| Sequence | Reached ghostel through zmx |
|---|---|
| OSC 2 title | yes (`ghostel-title`) |
| OSC 7 directory | yes (`default-directory`) |
| OSC 133 C / D | yes (`ghostel-command-start-functions`, `-finish-functions`, exit 0) |
| BEL | yes (`ghostel-bell-functions`) |
| OSC 9, OSC 777 | yes (`ghostel-notification-functions`) |
| OSC 9;4 progress | yes (`ghostel-program-status-functions`, `working` 40) |
| OSC 7501 status | yes (`ghostel-program-status-functions`, `blocked` 40) |

A second probe ran in hidden buffers with an isolated `ZMX_DIR`:

| Case | Result |
|---|---|
| OSC 7501 support query, attached | ghostel's answer comes back through zmx, same as direct |
| OSC 7501 support query, detached | no answer; DA1 (device attributes) is still answered |
| BEL, OSC 9, OSC 7501 while detached | lost: no event on reattach, `ghostel-program-status` nil |
| Title and directory set while detached | restored on reattach |
| Buffer killed (detach) with a `working` record | hook fires with the record removed, as for a process exit |
| New zsh session through `ghostel-exec` and zmx | OSC 133 arrives (`false` finishes with exit 1); no status record |

Unproven: a real program reporting status through zmx. Text printed while
detached was not established, as the hidden buffer's text can't be trusted.

Probing from a shell inside a zmx session: unset `ZMX_SESSION`, or `zmx attach`
switches session instead of attaching.

## Candidates, in order

1. Done 2026-11-07: `consult-ghostel` loads, `ghostel-status-indicator-mode` is
   on, and `dl-ghostel--status-segment` carries the indicator into lambda-line.
2. Done 2026-11-07: `dl-zmx-consult-source`, hidden, on narrow key `z`, offers
   every session without a live terminal buffer, not only `clients=0`, so a
   session attached from another terminal is reachable. `consult-ghostel` sees
   live buffers only. Tried by hand: it lists and reattaches. It previews plain
   `zmx history`, which is about 4 ms for 3000 lines. `--vt` keeps colour but also
   carries `ESC (`, OSC 7 and mode sequences that `ansi-color` leaves or strips
   only in part, so colour needs more filtering.
3. Replaced 2026-11-07: a Claude Code harness in zmux, beside
   `harness/pi/zmx-state.ts`, writing `zmx set . state=...` from inside the
   session. That work belongs to the zmux repo. Nothing here changes:
   `dl-zmx--state-icons` already shows the label. See Rejected for the bridge.
4. Make `consult-ghostel-history` work in zmx buffers. It needs
   `ghostel--shell-program`, which `ghostel-exec` does not set, so
   `ghostel-shell-history` signals "Buffer has no recognized shell" (run). The fix
   sets a private variable; an upstream hook would be cleaner.
5. A `zmx:` Org link type, such as `[[zmx:emacs.2]]`.
6. Replace the Eat block in `apps/dl-term.el` with
   `ghostel-eshell-visual-command-mode`. `eat-eshell-mode` and
   `eat-eshell-visual-command-mode` sit under `:custom` with no value, so both
   are nil and the integration is dead. Eat can leave `emacs.nix` if nothing
   else needs it.

## Rejected

- **Stock `ghostel-org` for zmx buffers.** `ghostel-org-open` passes no identity
  to the bookmark handler. If the buffer is not live, it starts a plain shell
  named `term-P.ID`, and `dl-zmx--open` then sees a live process and never
  attaches.
- **`desktop.el` for zmx.** `ghostel-desktop--spawn` refuses `command`
  identities, `desktop-save-mode` is off, and zmx already holds the session
  list. A restore would also create an empty session if the original died.
- **Bridging `ghostel-program-status-functions` to `state` labels.** Reports only
  arrive while a ghostel buffer is attached, so a label freezes at detach: a
  session that blocks while detached still shows `working`. It would also be a
  third `state` writer, against zmux's "nothing watches", and would have to ignore
  the record removal that fires on every detach.
- **`ghostel-comint-mode` for `malebolge-attach`.** The filter would run, but
  the daemon emits no escape sequences. Revisit if it emits OSC 8 links.

Live-terminal preview needs no work: with two terminals open, `C-c m b` left no
stray bottom windows in the real minibuffer. An earlier run driving the preview
function directly, with a stand-in `ghostel-mode`, had suggested it would.

Bookmarks need no work: the record keeps the `zmx attach` command and jumping
respawns it. Expect 80x24 until the buffer is displayed.

## Open

- `dl-zmx--open` displays the buffer before `ghostel-mode` is set, so the
  `apps/dl-term.el` docking rule misses a first attach: reattaching from `C-x b z`
  landed in another window (run). `my/zmx-new` shares the path. Setting the mode
  first is safe for ghostel, as `ghostel--init-buffer` skips a buffer already in
  it, but it would dock every new terminal. Undecided.
- Shell integration varies by session: `zmx list` reports `kitty-shell-cwd://`
  for some sessions and `file://` for others, which suggests only sessions born
  under ghostel source it. Sessions predating a ghostel upgrade keep the old
  script.
- `ghostel-compile` for `project-compile` was not evaluated.
- Sweep ghostel's `defcustom`s for useful options this config is missing, such
  as `ghostel-status-*`, `ghostel-buffer-name-function`, `ghostel-enable-osc52`
  and `ghostel-eval-cmds`. Only `ghostel-keymap-exceptions` is set today.
