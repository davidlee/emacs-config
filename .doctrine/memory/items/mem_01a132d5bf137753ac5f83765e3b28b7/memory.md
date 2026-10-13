flyover listens for `flymake-after-update-diagnostics-hook` (or
`flymake-diagnostics-updated-hook`). Flymake 1.4.7 defines neither. flyover
then falls back to a **global** `advice-add` on `flymake--handle-report`
and removes that advice whenever any one buffer disables `flyover-mode` —
freezing inline updates in every other buffer.

`dev/dl-diagnostics.el` (flymake `:config`) defines the hook when unbound
and runs it from an `:after` advice on `flymake--handle-report`, which
runs in the reporting buffer (`flymake-make-report-fn` uses
`with-current-buffer`). flyover then adds itself buffer-locally.

Revisit when Flymake or flyover upgrades: if Flymake ships the hook, the
`boundp` guard skips the shim. Test:
`dl-diagnostics/report-runs-update-hook-in-its-buffer`.
