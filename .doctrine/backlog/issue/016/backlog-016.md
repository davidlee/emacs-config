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
