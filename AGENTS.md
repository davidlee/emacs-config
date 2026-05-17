# AGENTS.md — orientation for future agents

This config is wired into Nix. Editing `.el` files alone is not always enough — some
things only take effect after `home-manager switch`, and a few traps are specific to
the Nix integration.

## Architecture

```
~/flakes/modules/home/emacs.nix    nix wiring (emacsWithPackagesFromUsePackage)
~/.emacs.d/early-init.el           loads dl-path.el, sets package-archives nil
~/.emacs.d/core/dl-path.el         load-path, exec-path, trusted-content, direnv
~/.emacs.d/init.el                 main config
~/.emacs.d/{core,apps,lang,lisp,editing,completion,org,dev}/*.el
```

The Nix wrapper (`emacs-unstable-pgtk` overlaid by `emacs-overlay`) parses every
`.el` file under `configDirs` (listed in `emacs.nix`) and installs each
`(use-package NAME …)` it finds. **No package archives are configured at runtime**
(`package-archives nil` in `early-init.el`); MELPA is not available from inside
Emacs. To get a new package: add a `use-package` form, `git add` the file, run
`home-manager switch`.

The user's systemd `services.emacs` unit is **disabled** — the server is started
from `init.el`. Don't suggest the daemon workflow.

## The four traps

### 1. Flake builds see only git-tracked files

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

### 2. `:ensure nil` is a "don't install" signal

The emacs-overlay parser respects `:ensure nil` and refuses to install the
package. If the package isn't otherwise present (it isn't, since no MELPA at
runtime), `use-package` fails to load it. Either remove `:ensure nil` or add
the package to `extraEmacsPackages` in `emacs.nix`.

### 3. Never `setq` the preloaded native-comp vars — append

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

### 4. `trusted-content` entries must be `~/` form

`trusted-content-p` in `files.el` runs `(abbreviate-file-name
buffer-file-truename)` before matching, so it compares `~/.emacs.d/foo/bar.el`
against your trusted entries via `string-prefix-p`. Entries built from
`expand-file-name` (`/home/david/...`) never match. Wrap in
`abbreviate-file-name` — see `core/dl-path.el:my/expand-emacs-dir`.

## Naming conventions

| Bucket | Prefix | Example |
| --- | --- | --- |
| File / `provide` symbol | `dl-MODULE` | `dl-faces`, `dl-shpool` |
| Module's public internals (vars, defcustoms, defface, helpers) | `dl-MODULE-name` | `dl-shpool-command`, `dl-meow-indicator-inactive` |
| Module's private internals | `dl-MODULE--name` | `dl-shpool--attach-args` |
| Personal command (user-callable) | `my/name` | `my/apply-fonts`, `my/journal-note` |
| Helper or variable supporting a `my/` command | `my/name` | `my/font-name`, `my/auto-save-idle-timer` |

Rules of thumb:

- **Role beats file.** A `my/` command living in a `dl-MODULE` file is fine
  (`my/apply-fonts` in `dl-faces.el`).
- **`my/` propagates through the helper family.** `my/shpool--candidate-status`
  is correct even though `dl-shpool` is the file — it's plumbing for the
  `my/shpool*` commands.
- **Defcustoms are always module-owned** → `dl-MODULE-...`.
- **Private gets `--`** regardless of bucket (`dl-shpool--attach-args`,
  `my/foo--helper`).

Grandfathered exceptions:

- **`my-X-map` keymaps** (`my-window-map`, `my-file-map`, `my-term-map`, …).
  `my/bind` and the meow leader-mirror discover maps by this name — renaming
  means updating the maps *and* the dispatch code, and the names straddle
  multiple modules. Cheaper to grandfather.
- **`meow-setup` in `dl-meow.el`.** The meow docs tell users to define a
  function by this exact name; it's an external API contract.

## Common debugging commands

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

## When a change requires what

| Change | Action |
| --- | --- |
| Edit existing `.el`, no new package | `M-x eval-buffer` (live) or restart emacs |
| Add new `(use-package X)` to tracked file | `home-manager switch` |
| Add new `.el` file | `git add` it, then `home-manager switch` |
| Edit `emacs.nix` | `home-manager switch` |
| Set `:ensure nil` + want package available | Add to `extraEmacsPackages` in `emacs.nix` |

## What we know about this user's setup

- Nix flake at `~/flakes`, hostname `Sleipnir`, x86_64-linux.
- Modal editing: meow.
- Native compilation is on; eln-cache at `~/.emacs.d/eln-cache/`.
- compile-angel byte-compiles `.el` on save and load.
- Some files are intentionally untracked (`*.secret.el`, `apps/dl-spotify.el`
  historically) — check git status before assuming a "missing" file is a bug.
