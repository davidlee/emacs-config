To verify keybindings / load order against the real config in a fresh Emacs
(no server, no display):

```elisp
;;; va.el -*- lexical-binding: t; -*-
(advice-add 'atomic-chrome-start-server :override #'ignore) ; port held by live Emacs
(unwind-protect
    (condition-case err
        (progn (load (expand-file-name "early-init.el" user-emacs-directory) nil t)
               (load (expand-file-name "init.el" user-emacs-directory) nil t))
      (error (princ (format "INIT-ERROR %S\n" err))))
  (setq kill-emacs-hook nil))   ; else exit hooks rewrite state files
;; … checks, e.g. (keymap-lookup global-map "C-:") …
(kill-emacs 0)
```

Run: `SATAN_DB_HOST=127.0.0.1 emacs --batch --init-directory=$HOME/.emacs.d -l va.el`.

Traps:
- In batch `user-init-file` is nil and `early-init.el` is not loaded —
  `(load user-init-file)` fails with `(wrong-type-argument stringp nil)`.
- Without clearing `kill-emacs-hook`, exit writes `~/.emacs.d/project-window-list`
  (and other persisted state) from the scratch session.
- `Error loading autoloads: (void-function define-compilation-mode)` on stderr
  is a pre-existing batch artefact of early-init, not a regression.
