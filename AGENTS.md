@.doctrine/state/boot.md
If you have NOT seen `BOOT-SENTINEL: doctrine-governance-snapshot` anywhere in your context (system prompt or preceding messages), you MUST read the file referenced above now. If you HAVE seen it, you MUST NOT — the content is already in context.

# AGENTS.md — orientation for future agents

## Commit Gate

`just check` is green

## Elisp checks

For Emacs Lisp edits:

1. Never manually balance parentheses across a whole file.
2. After changing any .el file, run:
   bin/elisp-locate-paren-error FILE
3. If it fails:
   - first inspect `error.line` if present;
   - then inspect the first item in `open_stack`;
   - restrict repairs to the reported line or `toplevel.start_line..toplevel.end_line`.
4. Re-run `bin/elisp-locate-paren-error FILE` until it returns {"ok":true}.
5. Only then run byte compilation/tests.

## Misc 

when searching:
- use rg | fd, not find | grep
- don't search / or ~/
- ~/flakes/ has the nixOS and home-manager configuration
- ./elpa/ has packaged installs - hidden by .gitignore so use eg fd -I

keep exploration bounded:
- before exploring: define stopping conditions, positive and negative

provide the user with choices, exposing important tradeoffs.

don't assume. ask questions to clarify. perform bounded exploration where necessary to frame the right questions.

when implementation is successful / committed, update CHANGELOG.md with concise notes.

CHANGELOG.md is very large, sip it.

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
from `init.el`.

## When a change requires what

| Change | Action |
| --- | --- |
| Edit existing `.el`, no new package | `M-x eval-buffer` (live) or restart emacs |
| Add new `(use-package X)` to tracked file | `home-manager switch` |
| Add new `.el` file | `git add` it, then `home-manager switch` |
| Edit `emacs.nix` | `home-manager switch` |
| Set `:ensure nil` + want package available | Add to `extraEmacsPackages` in `emacs.nix` |
| Adding stuff that has nothing to do with a text editor | [read](./docs/satan/refactor/extraction-policy.md)| 

## four traps 

1. **Flake builds see only git-tracked files** — untracked `.el` is invisible to the parser.
2. **`:ensure nil`** — emacs-overlay refuses to install. Use `extraEmacsPackages` instead.
3. **Never `setq` preloaded native-comp vars** — `append` to `native-comp-driver-options`.
4. **`trusted-content` entries must be in `~/` form** — `abbreviate-file-name` before adding.

Full detail: [docs/emacs/traps.md](docs/emacs/traps.md).

## More

- [docs/emacs/naming.md](docs/emacs/naming.md) — `dl-MODULE` / `my/` / `--private` conventions.
- [docs/emacs/secrets.md](docs/emacs/secrets.md) — 1Password env-var flow, `dl-secret.el` API.
- [docs/emacs/debug-commands.md](docs/emacs/debug-commands.md) — rebuild, inspect, cache reset.
- [docs/satan/INDEX.md](docs/satan/INDEX.md) — SATAN agent runtime (governance, memory, patch-agent, …).

## What we know about this user's setup

- Nix flake at `~/flakes`, hostname `Sleipnir`, x86_64-linux.
- Modal editing: meow.
- Native compilation is on; eln-cache at `~/.emacs.d/eln-cache/`.
- compile-angel byte-compiles `.el` on save and load.
- Some files are intentionally untracked (`*.secret.el`, `apps/dl-spotify.el`
  historically) — check git status before assuming a "missing" file is a bug.
- Global git `post-commit` hook (`satan/bin/satan-git-post-commit`, symlinked
  from `~/.config/git/hooks/` via `core.hooksPath`) feeds the SATAN git-activity
  sensor — appends a JSONL row per commit to
  `~/.local/state/behaviour/segments/git-<day>.jsonl`. The global `core.hooksPath`
  **disables repo-local `.git/hooks/`**; `~/.gitconfig` is not Nix-managed, so
  this is a manual one-time machine setup.
