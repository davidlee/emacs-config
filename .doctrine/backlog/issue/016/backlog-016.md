# ISS-016: font roles name families that do not resolve

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

A font role naming a family that does not exist falls back silently. Found through
IMP-030: `header-line-active` asked for `Inter Regular` and got `JetBrains Mono NL`.

## Evidence

- 2026-11-07, `find-font` on a live frame, `my/known-fonts` (`core/dl-faces.el`):
  `Inter`, `Inter Display` and `Inter Variable` resolve; `Inter Regular` and
  `Source Sans 3` do not.
- `inter` feeds the `ui`, `serif` and `org-heading` roles. `ui` sets
  `minibuffer-prompt`, `completions-*`, `header-line`, `tab-bar` and `tab-line`.
- The `inter` entry now names `Inter Display` (committed, not yet loaded in the
  session that found this). Inter Display is the cut drawn for large sizes, so
  plain `Inter` may suit these small UI faces better. Not compared yet.
- `my/font-roles` also names `geist` and `monaspace-argon`;
  only `my/known-fonts` was checked, not whether each role's key has an entry.

## Possible fix

Warn when a role's family does not resolve, so this cannot recur silently.

## Findings, 2026-11-07

- After `Inter Display` loaded, every role resolved. The only unresolved entry was
  `source-sans` (not installed, unused), now removed.
- Rendered at 14px, `Inter Display` is the tightest of six candidates. `ui` and
  `tab-line` now use `Inter`; `org-heading` keeps `Inter Display` through a new
  `inter-display` entry.
- `header-line-inactive` drew in `default`: it inherits
  `modus-themes-ui-variable-pitch`, which has no family under foxglove-dark. Tab faces
  also have no family or inheritance. `my/chrome-role-faces` now names them all.
- `ui` was too broad. `header` and `tab` existed but nothing read them; they now own
  the header and tab bar faces, in mono, and a new `tab-line` role owns the tab line.
  `ui` keeps the minibuffer and completions. The `*umbriel*` legend aligns by columns,
  so a proportional header crowds its icons.
- `org-body` had no consumer. It now sets `dl-faces-org-body`, which org buffers remap
  `default` to, so a role change reaches open buffers.
- `mono-alt`, `mono-narrow` and `serif` have no consumer. Kept as spare roles for later
  use, and marked so. `serif` named a sans (`inter`); it now names `source-serif`.
- `my/apply-fonts` ran on every `prog-mode` buffer and line-number toggle. It also hid
  `my/apply-lambda-line-faces`, whose height 140 it overwrote. Both removed.
- `geist-sans` named a weight (`Geist Medium`) as a family, the `Inter Regular` mistake.
  Now `Geist`.
- No resolve warning added: nothing unresolved remains, and it would not have caught
  the unused roles.
