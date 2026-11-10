# IDE-006: Extract umbriel modules as a standalone package

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

## Idea

Umbriel support (`apps/dl-umbriel*.el`: 5 modules, about 2k lines, of which
`dl-umbriel-buffer.el` is 1089; plus 5 test files) is the biggest
self-contained family in the config. Like SATAN (SL-012), it could become a
standalone package with its own repo and tests, loaded by `use-package`.

## For

- It has a clear boundary: a client for the umbriel compositor's IPC socket.
- It would let others use it, and lets it keep its own release history.

## Against / open

- POL-001's test for staying in the config is "does it use the editor as an
  editor?" Umbriel partly passes it: its buffer is an Emacs UI.
- Worth doing only if umbriel is meant to be used outside this config.
- Extraction cost: self-location (`satan--root`-style), defcustoms for
  config couplings, a Nix package input. SL-012 is the worked example.

Related: IDE-003 (umbriel frame identity). Raised in a file-structure review
(2026-11-10).
