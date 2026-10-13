`use-package :custom` writes through `custom-theme-set-variables 'use-package`
and `enable-theme 'use-package`. Every later `:custom` (e.g. a deferred
package loading on first file visit) re-enables that theme, re-applying
**all** its values. So a plain `setq` on a `:custom`-managed variable is
silently reverted the next time any `:custom` runs.

Bit a mutation test: `(setq flycheck-disabled-checkers nil)` reverted on
`find-file-noselect`. To mutate such a value in tests, edit the source
form (or `let`-bind around the code that reads it), not `setq`.
