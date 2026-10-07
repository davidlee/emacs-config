# STD-001: One concern per file

## Statement

Each file owns exactly one concern, and its name says which. Code goes in the
file whose concern it serves, not the file where the related package happens
to be configured.

- **Cohesion:** everything in a file serves the concern its name states.
  `dl-modeline.el` is modeline format; `dl-prose.el` is prose behaviour.
- **Cross-cutting concerns get one home.** When a concern (e.g. faces) spans
  many packages, it collects in a single file rather than scattering into
  each package's `use-package` block. Faces → `core/dl-faces.el`, via
  `with-eval-after-load 'PACKAGE`; no `:custom-face` in distant blocks.
- **Coupling:** a file reaches into another concern only through that
  concern's public surface (functions, variables, hooks), never by
  configuring it inline.

When a change doesn't obviously fit an existing file's concern, ask before
bundling it somewhere nearby; a new file is cheaper than a muddied one.

**Note:** A standard with status "default" is recommended unless there is
justification to deviate; `required` mandates it.

## Rationale

Finding where something is configured should be answerable from file names
alone. Bundling by proximity ("flymake is set up in the modeline file, so its
faces go there too") makes every file a little bit about everything, so visual
tuning, behaviour and layout can no longer be changed independently.

## Scope

Applies to: all first-party elisp in `~/.emacs.d` (`core/`, `editing/`,
`apps/`, …).

Excluded: `custom-vars.el` (written by Customize), vendored or `elpa/` code.

## Verification

Review guideline. For faces, mechanically:

```sh
rg -n -e 'set-face-attribute|:custom-face|face-spec-set' \
  -g '*.el' -g '!elpa/**' -g '!eln-cache/**' -g '!core/dl-faces.el' .
```

should return nothing. It held on 2026-10-08.

## References

- `core/dl-faces.el` header — "single home for face customization".
- Origin: flymake face customization was rejected from `dl-modeline.el`
  ("that's modeline") and moved to the faces file (2026-05-16).
