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
