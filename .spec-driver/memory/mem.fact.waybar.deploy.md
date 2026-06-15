---
id: mem.fact.waybar.deploy
name: waybar config is a plain dotfile, not flake-managed
kind: memory
status: active
memory_type: fact
created: '2026-06-10'
updated: '2026-06-10'
verified: '2026-06-10'
confidence: high
tags:
- waybar
- satan
- deploy
scope:
  globs:
  - '~/.config/waybar/**'
summary: ~/.config/waybar/ deploy = edit in place + systemctl --user reload waybar;
  NOT home-manager switch
---

# waybar config is a plain dotfile, not flake-managed

## Summary

`~/.config/waybar/` (config.jsonc, style.css, scripts/) is a **plain editable
dotfile**, tracked only by the home dotfiles repo at `/home/david`. It is NOT a
nix-store symlink and NOT managed by `~/flakes`.

Deploy: edit in place, then `systemctl --user reload waybar`. No
`home-manager switch`.

## Context

Verified 2026-06-10 (`readlink -f ~/.config/waybar` returns itself; files are
regular `-rw-`, not store symlinks). The DE-010 phase-02 assessment claimed this
config lives in `~/flakes` / needs `home-manager switch` — that is **wrong**. The
2026-05-19 satan-inbox CHANGELOG entry is correct. Corrected in CHANGELOG under
the 2026-06-10 satan-backlog widget entry.

Both SATAN waybar widgets live here: `scripts/satan-inbox.sh`,
`scripts/satan-backlog.sh`. See [[mem.fact.satan.ingest-cursor-require]] for the
backlog widget's emacsclient dependency.
