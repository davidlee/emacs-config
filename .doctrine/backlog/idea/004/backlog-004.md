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

Not tested: the OSC 7501 support query, which needs an answer travelling back
through zmx, and anything emitted while no client is attached.

## Candidates, in order

1. Done 2026-11-07: `consult-ghostel` loads, `ghostel-status-indicator-mode` is
   on, and `dl-ghostel--status-segment` carries the indicator into lambda-line.
2. A `consult-buffer` source for detached zmx sessions, narrow key `z`, reusing
   `dl-zmx--annotation` and `dl-zmx--reattach`. `consult-ghostel` sees live
   buffers only.
3. Bridge `ghostel-program-status-functions` to zmx `state` labels with
   `zmx set`, so `dl-zmx--state-icons` shows status for detached sessions.
   ghostel `error` maps to zmx `failed`. Reports only arrive while a ghostel
   buffer is attached.
4. Make `consult-ghostel-history` work in zmx buffers. It needs
   `ghostel--shell-program`, which `ghostel-exec` does not set, so it should
   signal "Buffer has no recognized shell" (read in source, not run). The fix
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
- **`ghostel-comint-mode` for `malebolge-attach`.** The filter would run, but
  the daemon emits no escape sequences. Revisit if it emits OSC 8 links.

Bookmarks need no work: the record keeps the `zmx attach` command and jumping
respawns it. Expect 80x24 until the buffer is displayed.

## Open

- Shell integration varies by session: `zmx list` reports `kitty-shell-cwd://`
  for some sessions and `file://` for others, which suggests only sessions born
  under ghostel source it. Sessions predating a ghostel upgrade keep the old
  script.
- `ghostel-compile` for `project-compile` was not evaluated.
- Sweep ghostel's `defcustom`s for useful options this config is missing, such
  as `ghostel-status-*`, `ghostel-buffer-name-function`, `ghostel-enable-osc52`
  and `ghostel-eval-cmds`. Only `ghostel-keymap-exceptions` is set today.
