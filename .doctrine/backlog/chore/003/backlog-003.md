# CHR-003: Move config to ~/.config/emacs (XDG)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Why

Emacs (27.1+) reads `~/.config/emacs/` only when neither `~/.emacs.d/` nor
`~/.emacs` exists. Moving follows XDG and drops a `$HOME` dotdir.

## Done so far

`155ea9a`: this repo no longer hardcodes its own path. `early-init.el` loads
`dl-path.el` via `user-emacs-directory`; Justfile recipes use the justfile
directory.

## Plan

```
transition   ~/.config/emacs/ (real)  <-  ~/.emacs.d (symlink; Emacs still uses this name)
after        ~/.config/emacs/ (real)      no ~/.emacs.d -> Emacs uses XDG
```

1. Stop Emacs. `mv ~/.emacs.d ~/.config/emacs`,
   `ln -s ~/.config/emacs ~/.emacs.d`, `just clean-eln`,
   `direnv allow` in the new location.
2. Update references outside this repo (`rg '\.emacs\.d'`):
   - `~/flakes`: `modules/home/shared/emacs.nix`, `emacs/emacs.nix`,
     `modules/home/linux/eca.nix`, `flake.nix`, `justfile`, docs.
   - `~/dev/satan`: `satan-custom.el`, `satan-memory.el`,
     `satan-attribute-render.el`, tests, `flake.nix`, docs.
   - Docs in this repo: `AGENTS.md`, `docs/emacs/*`, `README.md`.
3. When nothing references `~/.emacs.d`, remove the symlink.

## Watch during transition (two names per file)

- Same file visited under both names -> duplicate buffers; recentf /
  saveplace / project lists may record both.
- `trusted-content` matches `~/`-form strings: list both forms.
- direnv approval is keyed on the real path.
- eln-cache may recompile once under the real path.
- Agent tooling keyed on the working-directory path (e.g. Claude Code
  project memory) starts fresh under the new path unless copied.
- zmx session names derive from the dir name (`emacs.d-*` -> `emacs-*`).

## Progress log

Resume from `~/.config/emacs` (or the `~/.emacs.d` symlink) if a session
is cut off. Claude Code memory is copied to the new path key in step 1.

Survey (2026-10-10) — functional refs outside docs:
- `~/dev/satan/satan/satan-tools-vcs.el:23` — `vcs_log` bare-slug root.
- `~/.config/waybar/scripts/satan-timer.py:31` — already stale
  (`~/.emacs.d/satan/bin` gone since SL-012); target `~/dev/satan/satan/bin`.
- `~/.config/gtk-3.0/bookmarks`, `~/flakes/files/omp.custom.json:69`.
- Doc-only elsewhere; historical design/archive docs left as-is.

- [ ] 1. move + symlink + clean-eln + direnv allow + copy agent memory
- [ ] 2. functional refs fixed
- [ ] 3. agent-facing docs updated (AGENTS.md, docs/emacs/*, home-context.md)
- [ ] 4. user restarts Emacs, verifies
- [ ] 5. symlink removed, `just check`, CHANGELOG, close
