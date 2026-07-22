---
name: emacs-debug-commands
description: Common shell commands for inspecting/rebuilding this Emacs config
metadata:
  type: reference
  topic: emacs
  status: canon
  updated_at: 03398479
  verified_at: 03398479
---

# Common debugging commands

```sh
# What packages did the Nix wrapper actually install?
deps=$(strings $(readlink ~/.nix-profile/bin/emacs) | grep -oE '/nix/store/[a-z0-9]+-emacs-packages-deps' | head -1)
ls "$deps/share/emacs/site-lisp/elpa/" | grep -i NAME

# Rebuild after editing .el or emacs.nix
cd ~/flakes && home-manager switch --flake .#david

# Inspect the running emacs from outside
emacsclient --eval '(boundp (quote trusted-content))'
emacsclient --eval '(getenv "LIBRARY_PATH")'

# Purge stale native-comp (.eln) generations — the cure for recurring SIGSEGVs
# (jump-to-garbage crashes) after emacs rebuilds. Keeps the live gen, drops the
# rest. See trap 5 in traps.md. Wired into `just home-switch` automatically.
just clean-eln

# Confirm a crash was a native-comp segfault (not a hang) and see the frame:
coredumpctl list | grep emacs
coredumpctl info <PID>   # look for the crashing .eln in the stack trace
```
