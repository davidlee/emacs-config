---
name: emacs-traps
description: The four Nix-integration traps that have bitten this Emacs config
metadata:
  type: reference
  topic: emacs
  status: canon
  updated_at: 03398479
  verified_at: 03398479
---

# Nix-integration traps

Four things that have bitten this config. Quick reference; for orientation see [AGENTS.md](../../AGENTS.md).

## 1. Flake builds see only git-tracked files

`~/flakes` is a flake input of type `git+file://...`. Untracked `.el` files do
**not** appear in the concatenated config the parser sees, so their
`use-package` forms are silently ignored and the package isn't installed.
`Cannot load X` after adding a use-package form usually means the file is still
untracked.

```
git -C ~/.emacs.d status --short    # ?? marks invisible files
git -C ~/.emacs.d add path/to/new.el
```

Staged (uncommitted) is enough — the "Git tree is dirty" warning is benign.

## 2. `:ensure nil` is a "don't install" signal

The emacs-overlay parser respects `:ensure nil` and refuses to install the
package. If the package isn't otherwise present (it isn't, since no MELPA at
runtime), `use-package` fails to load it. Either remove `:ensure nil` or add
the package to `extraEmacsPackages` in `emacs.nix`.

## 3. Never `setq` the preloaded native-comp vars — append

The Nix emacs build pre-populates `native-comp-driver-options` with `-B` flags
that point at libgccjit / glibc / gcc-libgcc / binutils:

```elisp
("-B/nix/store/.../libgccjit/lib"
 "-B/nix/store/.../glibc/lib"
 "-B/nix/store/.../gcc-libgcc/lib"
 ...)
```

Without these the linker can't find `Scrt1.o`, `crti.o`, `-lgcc_s` and native
compilation fails with `libgccjit.so: error: error invoking gcc driver`.
**Overwriting with `setq` breaks every subsequent native-compile.** Always:

```elisp
(require 'comp)    ; the vars are defined in comp.el, not autoloaded
(setq native-comp-driver-options
      (append native-comp-driver-options '("-Wl,-O2" "-Wl,--as-needed")))
```

See `core/dl-compile.el`.

## 4. `trusted-content` entries must be `~/` form

`trusted-content-p` in `files.el` runs `(abbreviate-file-name
buffer-file-truename)` before matching, so it compares `~/.emacs.d/foo/bar.el`
against your trusted entries via `string-prefix-p`. Entries built from
`expand-file-name` (`/home/david/...`) never match. Wrap in
`abbreviate-file-name` — see `core/dl-path.el:my/expand-emacs-dir`.
