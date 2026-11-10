# IDE-007: Publish the umbriel package (push ~/dev/umbriel.el to origin)

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`~/dev/umbriel.el` has origin `git@github.com:davidlee/umbriel.el.git` set but
never pushed (DEC-038: pushing is the user's act). Publishing would let other
hosts `git clone` the checkout that `core/dl-dirs.el` expects; without it a
host shows the `dl-umbriel` warning and runs without umbriel.

Before pushing: review the import commit (`c315b3b`) and the headers
(`Keywords: comm, tools`, `Maintainer:` were added during SL-018 PHASE-01).
Later: a package archive recipe, if wanted.
