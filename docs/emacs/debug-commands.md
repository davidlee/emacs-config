---
name: emacs-debug-commands
description: Common shell commands for inspecting/rebuilding this Emacs config
metadata:
  type: reference
  topic: emacs
  status: canon
  updated_at: pending
  verified_at: pending
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

# Reset native-comp cache after a failed compile leaves .eln.tmp files
rm ~/.emacs.d/eln-cache/30.2-*/*.tmp
```
