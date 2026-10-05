# IMP-018: Typst authoring ergonomics: tinymist LSP, tempel templates, outline folding

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Context

doctrine.engineering moved its entry bodies from Slim to Typst
(`~/dev/www/doctrine.engineering/.src/articles/*.typ`). We weighed org-mode as
the authoring format and rejected it: org has no inline extension point that
carries a slug, options and multi-paragraph content with links inside, which
the site's margin notes need. So keep Typst, and close the Emacs ergonomics
gap with org instead.

Today `lang/dl-typst.el` configures only `typst-ts-mode`.

## Work

1. **LSP: tinymist via eglot.** Add `tinymist` to the nix packages (it is not
   on PATH yet), and register it in `dev/dl-eglot.el` for `typst-ts-mode`.
   This gives completion, diagnostics, and jump-to-definition for the
   prelude's `note` / `note-p`. Live preview (`tinymist preview`) is optional.
2. **Templates: tempel** (`editing/dl-snippets.el`), scoped to
   `typst-ts-mode`. These match the most frequent constructs in the site's
   entries:
   - `note`: `#note("slug")[…]`, plus a `left: true` variant
   - `note-p`: `#note-p[…]`
   - `link`: `#link("url")[…]`, filling the url from the kill ring when it
     holds a URL
   - `more`: the `// more` teaser sentinel
3. **Folding.** Add `typst-ts-mode` to the `outline-minor-mode` hook in
   `editing/dl-fold.el`, with an `outline-regexp` for `=` headings, so kirigami's
   `C-c z` folds Typst the way it folds org. Alternatively use the
   `treesit-fold` hook, if its parser table supports typst.

## Done when

- Opening a `.typ` entry starts eglot with tinymist and shows diagnostics.
- The tempel templates expand in `typst-ts-mode`.
- `C-c z` folds by heading in a Typst buffer.
