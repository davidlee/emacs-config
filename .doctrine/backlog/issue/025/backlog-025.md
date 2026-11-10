# ISS-025: umbriel-focus adds server-switch-hook at load; make it opt-in

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

`~/dev/umbriel.el/umbriel/umbriel-focus.el` runs
`(add-hook 'server-switch-hook #'umbriel-focus-frame)` at load. Packages
normally leave global hooks to the user: a minor mode or a setup function the
config calls. SL-018 kept the load-time hook to avoid a behaviour change
during extraction (DEC-035).

Done when: loading `umbriel-focus` changes no global state; the config
(`desktop/dl-umbriel.el`) turns the hook on explicitly; `emacsclient` still
raises the frame.

**Also (user, 2026-11-11, at SL-018 VH-1):** `emacsclient` raising its frame
depends on the umbriel package having loaded. A host without the checkout, or
a failed package load, silently loses the raise, which is a basic desktop
behaviour rather than a umbriel-buffer feature. When making the hook opt-in,
decide where frame-raise lives: keep it in the package and have the config
wire it explicitly (warning when it can't), or have the config own a minimal
raise that doesn't need the package.
