# PACKAGE_MANAGER.md — how packages get installed

How packages end up loadable in this Emacs config, what knobs control each
path, and the failure modes you've already hit. This expands on the
overview in `AGENTS.md`.

## Two layers

Packages enter Emacs through two independent layers. Understanding which
layer is responsible for a given package is the entire mental model.

```
Layer 1: nix (build time)
  ~/flakes/modules/home/emacs.nix
    → emacsWithPackagesFromUsePackage
       → parsePackagesFromUsePackage  (emacs-overlay parse.nix)
          scans every .el file under configDirs, picks symbols off
          (use-package SYM ...) forms, looks them up in melpa-nix /
          gnu-elpa-nix, builds a derivation that bundles them under
          /nix/store/...-emacs-packages-deps/share/emacs/site-lisp/elpa/.
          load-path is set up to point at that store path.
       READ-ONLY: this directory cannot be written to at runtime.

Layer 2: emacs (runtime)
  ~/.emacs.d/elpa/                          writable
    package.el          installs from package-archives        (DISABLED — see below)
    package-vc          clones a git repo into elpa/NAME/
    manual              you do whatever you want
```

`package-archives` is `nil` at runtime (`early-init.el`), so `package.el`'s
normal install path is dead. Either nix supplies the package at build time
(Layer 1), or `package-vc` clones it (Layer 2 via `package-vc-install`),
or it doesn't exist.

## Layer 1: nix and the overlay parser

`emacs.nix` calls `emacsWithPackagesFromUsePackage` with:

- `package = emacs-unstable-pgtk` (or `emacs-macport` on Darwin)
- `config = concat of every .el under configDirs`
- `alwaysEnsure = true`
- `alwaysTangle = true`
- `extraEmacsPackages = epkgs: [ ... ]` — manual extras (`eaf-with-reinput`,
  `meow`, `treemacs`, …)

The parser lives at `nix-community/emacs-overlay:parse.nix`,
`parsePackagesFromUsePackage`. For each `(use-package NAME ...)` form:

| `:ensure` | `:disabled` | `alwaysEnsure` | Parser includes? |
| --- | --- | --- | --- |
| missing  | not `t` | `true`  | yes (uses NAME) |
| missing  | not `t` | `false` | no |
| `t`      | not `t` | (any)   | yes |
| `nil`    | not `t` | (any)   | **no** |
| `"foo"`  | not `t` | (any)   | yes (uses `foo`) |
| (any)    | `t`     | (any)   | no |

Crucially, the parser does **not** read `:vc`. Setting `:vc` alone, without
`:ensure nil`, still triggers nix to look the bare name up in melpa-nix.

When a name resolves in melpa-nix the package is baked into the store
derivation. When it doesn't, it's silently skipped.

## Layer 2: runtime install paths

### `:ensure t` (or `use-package-always-ensure`)

Use-package expands to `(unless (package-installed-p 'foo) (package-install
'foo))`. With `package-archives` `nil`, `package-install` errors with
"Package 'foo' is unavailable". So at runtime, `:ensure t` only works if
the package is *already* present via nix.

### `:vc (...)` (Emacs 30+ built-in use-package)

Use-package's `:vc` handler calls `package-vc-install` with the supplied
spec. The package is cloned into `~/.emacs.d/elpa/NAME/`. This is the only
runtime path that can pull source from outside what nix provides.

`:vc` and `:ensure` are independent handlers. With `:ensure t :vc (...)`,
`:vc` runs first; the subsequent `package-installed-p` check passes and
`package-install` is skipped. Functionally equivalent to `:ensure nil :vc
(...)` but the intent is muddier. Prefer the latter.

### `package-vc-selected-packages` (in `custom-vars.el`)

A static list of `(NAME :url URL [:lisp-dir DIR] [:rev REV] ...)` specs.
`M-x package-vc-install-selected-packages` installs everything not already
present. Keep this in sync with each `(use-package NAME :vc (...))` form
— having both is defensive and matches the existing pattern for
`claude-code-ide`, `eaf`, `combobulate`, `ghostel`.

## The keyword cheat sheet

| What you want                                | What to write                                  |
| -------------------------------------------- | ---------------------------------------------- |
| nix-managed package (most common)            | `(use-package foo ...)` — no `:ensure` needed  |
| Built-in mode, no install                    | `(use-package foo :ensure nil ...)`            |
| Package from a git URL (VC)                  | `(use-package foo :ensure nil :vc (:url ...))` |
| Package not yet wired anywhere               | Just add `(use-package foo)` and rebuild       |
| Skip nix entirely for a name that's in melpa | `:ensure nil` + arrange install another way    |

Rule of thumb: `:ensure nil` says "nix, don't manage this; use-package,
don't try to install via package-install either." Anything that needs
`:vc` always needs `:ensure nil` alongside it.

## Edge cases you have already hit

### VC packages that shadow a melpa-nix name (ghostel, 2026-05-15)

`apps/dl-ghostel.el` had `(use-package ghostel)`. The parser saw it,
melpa-nix had a `ghostel` recipe, nix baked it into
`/nix/store/...-emacs-packages-deps/.../ghostel-*`. Read-only. Ghostel's
runtime tries to write `ghostel-module.so` next to its `.el` source via
`M-x ghostel-download-module` or `M-x ghostel-module-compile`. Both
failed with permission errors masquerading as "Download failed" /
"`.zig-cache`: ReadOnlyFileSystem".

Fix:

1. `(use-package ghostel :ensure nil :vc (:url ... :lisp-dir "lisp"))`
2. Add `(ghostel :url ... :lisp-dir "lisp")` to
   `package-vc-selected-packages` in `custom-vars.el`.
3. `home-manager switch` to drop ghostel from the nix derivation.
4. `M-x package-vc-install-selected-packages` to clone into the writable
   `~/.emacs.d/elpa/ghostel/`.
5. `M-x ghostel-download-module` — now writes into the writable dir.

Pattern: any VC package whose name matches a melpa entry must carry
`:ensure nil` to escape Layer 1, regardless of whether you also use
`:vc`.

### `:lisp-dir` for non-standard repo layouts

`package-vc-install` clones a repo into `elpa/NAME/` and expects elisp
files at the root. Many repos put elisp under `lisp/` or `src/`. Without
`:lisp-dir`, autoloads land at the root pointing at nothing useful
(`add-to-list 'load-path` only adds the root), and `(require 'NAME)`
fails with "Cannot open load file".

`(:lisp-dir "lisp")` in the VC spec makes `package-vc--unpack-1`
(`package-vc.el:503-565`) write real autoloads into `lisp/` plus an
indirection stub at the root. Net effect: `lisp/` ends up on `load-path`.

There is heuristic detection in `package-vc--unpack`
(`package-vc.el:716-726`) that *should* pick up `lisp/` or `src/`
automatically when `:lisp-dir` is absent, but the detected value isn't
written back to `pkg-spec`, so `--unpack-1` doesn't use it. Always set
`:lisp-dir` explicitly when the repo isn't flat.

### Stale checkout after spec change

`package-vc--unpack` checks `(file-exists-p pkg-dir)` at line 694 and
prompts "Overwrite previous checkout?". If you say no — or if some flow
re-runs install without actually re-cloning — the old autoloads stay put
and your new `:lisp-dir` / `:rev` / `:branch` is ignored.

When changing the spec for a VC package: `rm -rf
~/.emacs.d/elpa/NAME/`, then `M-x package-vc-install-selected-packages`.
Don't rely on the prompt.

### `:ensure nil` confusion

`AGENTS.md` trap #2 says "`:ensure nil` means the package won't be
available." That's correct if nothing else installs the package. When
paired with `:vc (...)` (or with the package being built-in, or
manually loaded), it just means "Layer 1, leave this alone." The
package is still available via the alternate path.

So `:ensure nil` is not by itself a problem — only `:ensure nil` *with
no fallback install path* is.

## Proposed middle path — opt-in nix builds

Status quo: `alwaysEnsure = true` makes the parser default to "include."
You opt *out* per-package with `:ensure nil`. This is convenient for the
common case but means VC packages whose name happens to be in melpa-nix
get silently dragged into the read-only store, and the failure mode is
spectacularly indirect (see ghostel).

The proposed flip: `alwaysEnsure = false`. The parser then defaults to
"don't include." You opt *in* per-package with `:ensure t`.

Tradeoffs:

| | Current (`alwaysEnsure = true`)               | Proposed (`alwaysEnsure = false`)      |
| --- | --- | --- |
| Common case | "just add `use-package`, rebuild"            | "add `use-package` + `:ensure t`, rebuild" |
| VC package   | needs `:ensure nil :vc` (easy to forget)   | needs `:ensure nil :vc` (still — but the symptom of forgetting is a clean "package not found" rather than a silent read-only-store trap) |
| Audit        | hard — every `use-package` is implicitly in scope | easy — only `:ensure t` forms are nix's problem |
| Migration    | n/a                                          | one-time pass over every `use-package` in `core/ apps/ lang/ ...` to add `:ensure t` where wanted |
| Failure mode when wrong | "package was unexpectedly read-only" | "package was unexpectedly missing" |

The migration cost is the obvious blocker. It's mechanical but not
trivial — roughly: grep for `(use-package` across `core/`, `apps/`,
`lang/`, `editing/`, `completion/`, `org/`, `dev/`, `lisp/`, and add
`:ensure t` to each one whose package should be nix-managed. Built-in
modes (those using `:ensure nil` today) and VC packages stay as they are.

Reasonable counter: the friction is concentrated in VC packages, which
are a small minority. Paying the audit cost to make their failure mode
slightly nicer is not obviously worth it. Decision deferred until the
next time the read-only-store trap bites.

## Quick reference

### Common commands

```sh
# What is nix bundling in the active emacs?
nix-store -q --requisites $(readlink -f $(which emacs)) | grep emacs-

# Is package FOO in the nix derivation?
nix-store -q --requisites $(readlink -f $(which emacs)) | grep -i FOO

# What's in writable elpa?
ls ~/.emacs.d/elpa/

# Rebuild after editing .el or emacs.nix
cd ~/flakes && home-manager switch --flake .

# Force re-install of a VC package after spec change
rm -rf ~/.emacs.d/elpa/FOO && emacsclient -e '(package-vc-install-selected-packages)'

# Locate the overlay parser
find /nix/store -maxdepth 5 -name parse.nix -path '*emacs*'
```

### Files involved

| File | Role |
| --- | --- |
| `~/flakes/modules/home/emacs.nix`              | Layer 1 entry point. `extraEmacsPackages` for things outside use-package scanning. |
| `~/.emacs.d/early-init.el`                     | Sets `package-archives nil` — disables `package-install`. |
| `~/.emacs.d/custom-vars.el`                    | `package-vc-selected-packages` lives here. |
| `~/.emacs.d/apps/dl-ghostel.el`                | Reference example of `:ensure nil :vc :lisp-dir`. |
| `~/.emacs.d/apps/dl-claude.el`                 | Reference example of `:vc` without `:ensure nil` (works because name isn't in melpa-nix). |
| `~/.emacs.d/apps/dl-eaf.el`                    | Reference example of `:ensure nil :demand t` for a package supplied by `extraEmacsPackages`. |
| nix-community/emacs-overlay `parse.nix`        | Layer 1 parser. Cached at `/nix/store/*-source/parse.nix`. |
| emacs `lisp/emacs-lisp/package-vc.el`          | Layer 2 VC install machinery. |
