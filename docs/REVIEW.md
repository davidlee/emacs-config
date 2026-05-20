# Emacs config review — 2026-05-17

Scope: ~5000 lines across ~70 files in `/home/david/.emacs.d`. Audited via one structural pass + four cross-cutting audits (duplication / coupling / keybindings / hooks) + four hotspot deep-dives (shpool / denote cluster / visual layer / persist+capture). Trivial fixes applied in-tree (see §Fixes applied). Everything else stays here as recommendations.

The cluster of trap-checks in AGENTS.md is currently clean: no untracked `.el`, `trusted-content` uses the `~/` helper, `dl-compile.el` correctly `append`s onto `native-comp-driver-options` / `native-comp-compiler-options`. No silent landmines.

## Fixes applied

| File | Change |
| --- | --- |
| `init.el:69` | Removed duplicate `(require 'dl-term)` (line 65 already loads it) |
| `init.el:86-89` | Removed 4 dead commented `set-face-attribute`/`set-frame-font` lines |
| `editing/dl-persist.el:161` | Removed redundant global `before-save-hook` add for `my/eglot-format-buffer-if-connected` (already wired buffer-local at line 157 via `my/eglot-on-save-setup`) — was firing format twice per save in eglot buffers |
| `lisp/dl-buffer-management.el:12-13` | Removed orphan `<f9>` binding next to `toggle-maximize-buffer`; same binding already lives in `dl-keybind.el:105` where bindings belong |
| `core/dl-font.el:180-188` | Removed duplicate `with-eval-after-load 'org` face block — `my/apply-fonts` already calls `my/apply-org-faces` |
| `completion/dl-vertico.el:1` | Fixed misnamed file header (`dl-orderless.el` → `dl-vertico.el`) |
| `completion/dl-vertico.el:20-22` | Removed duplicate `savehist` setup; `dl-completion.el` already enables it earlier in init order |

Net: ~25 lines removed, 0 lines added, one save-time bug closed.

---

## High-leverage recommendations

### 1. Decide org-roam's fate
`NOTES.md` already flags org-roam as "wired but unused". It is bound at `C-c n r` and configures its own `org-roam-capture-templates` with directories (`notes/`, `projects/`, `refs/`) that don't align with the denote class structure (`projects/`, `areas/`, `slips/`, ...). This is a quiet split-brain: a roam capture from `C-c n r c` produces files outside the promotion pipeline.

- **Kill**: delete `org/dl-org-roam.el`, drop the require from `init.el:56`, remove `my-roam-map` bindings from `core/dl-keymap.el`.
- **Integrate**: rewrite roam capture templates to land in denote directories with denote keywords; align `org-roam-directory` with the denote root.

Either is defensible. The status quo is the worst option.

### 2. `lisp/denote-roam.el` is orphaned (291 lines)
Vendored copy of BardofSprites/denote-roam. Never `require`d, never `denote-roam-mode`'d, hardcodes `denote-roam-directory` to `"~/notes/"` independently of `dl-notes-paths.el`. References only appear inside its own file and in `emacs-deep-research.md`.

**Fix**: delete it. If the bridge becomes useful later, install the upstream package via Nix.

### 3. Other orphaned files (none loaded transitively — verified)
None of the following are `require`d from `init.el` or from any other file. `dl-global-text-scale.el` looks similar but is in fact required by `dl-keybind.el:40`, so it's fine.

- `core/dl-dwim.el` (20 lines)
- `editing/dl-comment.el` (5 lines)
- `editing/dl-iedit.el` (2 lines)
- `editing/dl-select.el` (4 lines)
- `apps/dl-diagram.el` (5 lines)
- `apps/dl-treemacs.el` (5 lines, redundant with `init.el:73` `(require 'treemacs)`)
- `org/dl-org-gcal.el` (16 lines)

**Fix**: delete each, or wire it up. Several are 2–5-line stubs — likely abandoned experiments. Confirm each before deleting.

### 4. EAF is eager-loaded
`apps/dl-eaf.el` has 5 `use-package` forms (eaf, eaf-browser, eaf-pdf-viewer, eaf-image-viewer, eaf-markdown-previewer), several with `:demand`. EAF is heavy and rarely needed at startup.

**Fix**: drop `:demand`, add `:commands` (e.g. `:commands (eaf-open-browser)`) or `:defer t`. Probably the largest single startup-time win in the config.

### 5. Org loads eagerly
`org/dl-org.el` declares `(use-package org :ensure nil :custom ...)` with no `:defer` / `:hook` / `:mode` / `:bind` triggers. `org-bullets` similarly has zero triggers.

**Fix**:
```elisp
(use-package org :ensure nil :mode ("\\.org\\'" . org-mode) :custom ...)
(use-package org-bullets :hook (org-mode . org-bullets-mode))
```

### 6. Eglot configuration scattered across three files
- `dev/dl-eglot.el` — main `:hook` + custom
- `lang/dl-nix.el:52-55` — `add-to-list 'eglot-server-programs` for nixd (correctly placed near nix, but eagerly loads eglot)
- `editing/dl-persist.el:130-162` — `my/eglot-connected-p`, format-on-save, organize-imports-on-save

**Fix**:
- Move the eglot-save functions and hooks out of `dl-persist.el` into `dev/dl-eglot.el`. Persist is for *session* persistence; LSP-on-save is an LSP concern.
- Wrap the nix server-program registration in `with-eval-after-load 'eglot` to defer eglot loading.

### 7. Face customization scattered (memory-flagged rule)
Memory says face/visual stuff lives in `core/dl-font.el`. Two strays:

- `core/dl-meow.el:13-14` — `set-face-attribute` for meow indicator faces (well-structured; already re-applied on `enable-theme-functions`). Move the `dl-meow--apply-indicator-faces` defun to `dl-font.el`; keep the `add-hook` near meow's `:config`.
- `editing/dl-fold.el:71-73` — `set-face-attribute 'treesit-fold-replacement-face`. Move into a new `my/apply-treesit-fold-faces` in `dl-font.el`, called from `my/apply-fonts`.

### 8. `dl-font.el` is missing a theme-reload hook
`dl-meow.el` adds `dl-meow--apply-indicator-faces` to `enable-theme-functions`, but `dl-font.el`'s `my/apply-fonts` is called once at startup only. Press `<f5>` → all font/face attrs are clobbered by the new theme until the next restart.

**Fix** (one line in `dl-font.el`):
```elisp
(add-hook 'enable-theme-functions (lambda (&rest _) (my/apply-fonts)))
```

### 9. `defadvice` in `core/dl-core.el:99`
The pre-2.0 `defadvice` form on `find-file` (parent-directory-maybe). Functional but deprecated.

**Fix**:
```elisp
(advice-add 'find-file :before
            (lambda (filename &optional _wildcards)
              (let ((dir (file-name-directory filename)))
                (unless (or (null dir) (file-exists-p dir))
                  (make-directory dir t)))))
```

### 10. Naming: `my/` vs `dl-` is mixed
The config has a strong `dl-` prefix convention for files and a strong `my/` convention for commands/helpers. Both used consistently *within* their domain. But some helpers cross: `my/narrow-or-widen-dwim`, `my/bind`, `my/eglot-toggle` live in `core/dl-keymap.el`; `meow-setup` (no prefix at all) in `core/dl-meow.el:43` masquerades as a meow built-in.

**Fix**: pick a rule and stick. Suggestion: `dl-` for module-defined functions, reserve `my/` for personal commands that live in `dl-keymap`/`dl-keybind`. Rename `meow-setup` → `dl-meow-setup` (the meow package does NOT export a function by that name; this is a custom defun named confusingly).

---

## Medium-leverage cleanups

### Dead commented blocks
- `editing/dl-persist.el:21-49` — 29 lines of commented `easysession` config
- `editing/dl-persist.el:57-81` — 25 lines of commented `saveplace`/`desktop` config
- `completion/dl-vertico.el:15-17` — commented `vertico-posframe` trial
- `core/dl-theme.el:43-45` — commented `solaire-mode` config (verify)

Total ~60 lines of rot. Delete unless any of these are imminently-planned (`desktop-save-mode` may be on the way back — the memory notes `.emacs.desktop` behaviour, suggesting it's been used).

### Use-package duplicates with identical settings (DRY)
| Package | Locations | Notes |
| --- | --- | --- |
| `dired` | `apps/dl-dired.el:7-19` + `apps/dl-dirvish.el:2-8` | Same `dired-listing-switches`, same `(put 'dired-find-alternate-file 'disabled nil)`. Not a conflict but redundant. **Fix**: keep `dl-dired.el`, remove from `dl-dirvish.el`. |
| `diredfl` | `apps/dl-dired.el:21-22` + `editing/dl-project.el:79-80` | Identical `:hook` config. **Fix**: keep `dl-dired.el`, remove from `dl-project.el`. |
| `markdown-mode` | `lang/dl-markdown.el` + `lang/dl-lang-common.el:9-10` | `dl-lang-common.el` only adds visual-line-mode hook. **Fix**: merge the hook into `dl-markdown.el`. |
| `nerd-icons` | `core/dl-interface.el` + `apps/dl-dired.el:24` | Audit flagged; verify which has the canonical config. |

### Overlapping `(use-package emacs ...)` blocks
Eight separate `use-package emacs` blocks across the config — `dl-core.el`, `dl-completion.el`, `dl-vertico.el`, `dl-project.el`, `dl-persist.el`, etc. Several settings are set in multiple blocks with the same value:

- `enable-recursive-minibuffers t` — in `dl-completion.el:9` AND `dl-vertico.el:31`
- `read-extended-command-predicate #'command-completion-default-include-p` — same two files

**Fix**: settle on a rule. Option A: each `use-package emacs` block owns a clearly named *domain* (core defaults, completion-relevant emacs settings, minibuffer-relevant settings, ...). Option B: collapse them into `dl-core.el` and leave domain-specific custom-vars in their own non-emacs blocks. A is more readable; B is more DRY.

### `dl-persist.el` scope creep
At 176 lines it covers buffer-terminator + auto-revert + autosave + eglot-on-save + undo-fu + vundo. Eglot save logic (see §6) doesn't belong. After moving eglot out and deleting commented blocks, file drops to ~95 lines and cleanly does just "session-level file persistence".

### `dl-font.el` is misnamed
At 205 lines, it's the universal *visual customization* hub: font roles, face heights, weights, line-numbers, mode-line, org headings, flymake underlines, jinx. "Fonts" undersells it. Rename to `core/dl-faces.el` or `core/dl-visual.el` — matches the actual responsibility and reinforces the memory rule that face stuff goes here.

### Hooks: anonymous lambdas
- `org/dl-org.el:49` — multi-statement lambda in `org-mode-hook` (margins + hl-line). Extract to `my/org-setup-margins`.
- `apps/dl-magit.el:20` — lambda disabling `ws-butler-mode` in `git-commit-mode`. Extract to `my/git-commit-disable-ws-butler`.

Named defuns are easier to remove cleanly (anonymous hooks accumulate on `.emacs.desktop` restore, per the memory).

### `editing/dl-fold.el` uses bare `add-hook` for ~47 lines
Procedural style instead of `use-package :hook`. Consolidating into per-package `use-package` blocks would cut ~30% and align with the rest of the config.

---

## Low-leverage polish

- `dl-shpool.el:230` — rename `my/shpool-attach-args` → `my/shpool--attach-args` (internal helper, only called by `my/shpool--open`).
- `dl-shpool.el:298-303` and `:317-319` — `customize-save-variable` called redundantly; one of each pair only modifies `restore-sessions`.
- `core/dl-interface.el:120` — `mapc` over hook list; `dolist` reads better.
- `core/dl-keybind.el` — `(use-package hydra :demand t)` is correct (downstream files reference `…/body`) but worth noting it's the only `:demand` in this file.
- `core/dl-meow.el` — solid module. Indicator-face logic is well-shaped; only the function-residence rule (move to `dl-font.el`) applies.

---

## Per-area summary

**Keybindings** — `dl-keymap.el` (488 lines) is large but well-organized: helpers → prefix-map declarations → which-key labels → bindings by family → meow integration. No structural problem. `dl-policy-lint.el` enforces the `C-c <letter>` policy at startup. `my/bind` is consistently used (195 call sites). No actual binding *conflicts* found. Per-file globals (e.g. `<f3>` deadgrep, `<f5>` theme rotate, `C-v`/`M-v` scroll overrides, function-key term chords) are all in non-policy chord space and documented inline. The `<f9>` duplication was the only real bug (now fixed).

**Hooks & advice** — Mostly clean. `define-advice` / `advice-add` are used appropriately for lambda-line modeline patches. The deprecated `defadvice` in `dl-core.el:99` and the two anonymous-lambda hooks (org, magit) are the only style hits. The duplicate `before-save-hook` add for eglot format-buffer (now fixed) was the one real bug.

**Coupling** — `dl-notes-paths.el` is a healthy hub (11 dependents, ordered correctly in init). No circular requires. `init.el:73 (require 'treemacs)` bypasses the use-package form in the orphaned `apps/dl-treemacs.el` — collapse into one place.

**Visual layer** — Clear boundary between `dl-theme.el` (theme rotation + olivetti), `dl-font.el` (face hub, misnamed), `dl-interface.el` (UI behaviour — scrolling, frames, popper, beacon), `dl-modeline.el` (lambda-line + margin-aware advice). The face-scatter issues and missing theme-reload hook (§7, §8) are the only structural concerns.

**Denote cluster** — Architecture is tight (single-source paths via `dl-notes-paths.el`, factory pattern via `my/denote--new` parameterized by class + subdir, clean personal/work parallel structure in capture templates). The two big issues are the orphan `denote-roam.el` (§2) and the dormant org-roam (§1).

**Capture/persist** — `dl-org-capture.el` (174 lines) is single-responsibility and well-organized. `dl-persist.el` has scope creep (eglot) and ~55 lines of dead commented config.

**Shpool** (398 lines) — Surprisingly clean for its size. Strict top-down order (schema → primitives → discovery → completion → marginalia → registry → vterm I/O → interactive commands). No dead code, naming is consistent (`my/shpool-*` public, `my/shpool--*` private — one stray to fix). One-way coupling. Could stay as-is.

---

## Suggested order of operations

If acting on these, I'd sequence roughly:

1. **Decisions** (no code): org-roam keep/kill (§1); orphan files keep/kill (§3); `my/` vs `dl-` rule (§10); `dl-font.el` rename (medium).
2. **Lazy-loading wins** (§4 EAF, §5 org) — biggest startup impact, small diffs.
3. **Eglot consolidation** (§6) and face migration (§7, §8) — cleanup that also fixes a real UX bug (theme rotation).
4. **Dead code purge** — orphan files (§3), denote-roam (§2), commented blocks (medium).
5. **DRY pass** — use-package duplicates, overlapping `emacs` blocks (medium).
6. **Polish** — defadvice (§9), anonymous lambdas, `dl-fold.el` style.

None of these are urgent. The config is in good shape — the report is long because the codebase is large, not because the codebase is bad.
