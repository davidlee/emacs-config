;;; dl-path.el --- Load & Exec Paths -*- lexical-binding: t; -*-
(defvar my/lisp-dirs
  '("lisp" "core" "editing" "completion" "apps" "org" "dev" "lang")
  "My own Lisp directories, relative to `user-emacs-directory'.")

(defvar my/checkout-lisp-dirs
  '("checkout" "elpa/org-timeblock" "~/dev/satan/satan")
  "External checkout Lisp directories, relative to `user-emacs-directory'.")

(defun my/expand-emacs-dir (dir)
  "Expand DIR relative to `user-emacs-directory' as a directory path.
Returned path is abbreviated (\"~/...\") so it matches what
`trusted-content-p' compares against."
  (file-name-as-directory
    (abbreviate-file-name
      (expand-file-name dir user-emacs-directory))))

(defun my/add-load-path-dir (dir)
  "Add DIR under `user-emacs-directory' to `load-path'."
  (add-to-list 'load-path (my/expand-emacs-dir dir)))

(defun my/trust-lisp-dir (dir)
  "Add DIR under `user-emacs-directory' to `trusted-content'."
  (add-to-list 'trusted-content (my/expand-emacs-dir dir)))

;; Load both my code and external checkouts.
(mapc #'my/add-load-path-dir
  (append my/lisp-dirs my/checkout-lisp-dirs))

;; Trust only my own code.
(mapc #'my/trust-lisp-dir my/lisp-dirs)

;; NIX path
;; (use-package exec-path-from-shell
;;   :if (memq window-system '(mac ns x pgtk))
;;   :config
;;   (exec-path-from-shell-initialize))

(defvar my/exec-dirs
  '("~/.nix-profile/bin"
     "/run/current-system/sw/bin"
     "~/.local/bin"
     ;; The systemd user environment carries none of the below, and a
     ;; sway-launched Emacs runs no shell init — so the `path add' lines in
     ;; ~/nushell/config.nu and the exports in ~/.config/zsh/env.zsh reach
     ;; an Emacs started from a terminal and nothing else. Same shape as the
     ;; problem `dl-secret.el' solves for env vars. ACP adapters for
     ;; agent-shell live here (claude-agent-acp, opencode under npm; goose,
     ;; crush under go); the symptom when they are missing is
     ;; `agent-shell--start: Executable "X" not found'.
     "~/.npm-global/bin"
     "~/go/bin")
  "Directories to prepend to `exec-path' and $PATH, in priority order.")

;; `exec-path' keeps the "~/..." form — Emacs expands it, and abbreviated
;; entries stay readable. $PATH cannot: `call-process' and every child
;; process treat a leading tilde literally, so an unexpanded entry there is
;; dead weight. One list, both consumers, no drift.
(dolist (dir (reverse my/exec-dirs))
  (add-to-list 'exec-path dir))

(setenv "PATH" (string-join (append (mapcar #'expand-file-name my/exec-dirs)
                              (list (getenv "PATH")))
                 path-separator))

;; Pin the subprocess shell to a POSIX shell. `shell-file-name' defaults to
;; $SHELL, which is now nushell; nushell ships builtin `find'/`grep' that
;; shadow the POSIX tools and reject their flags (e.g. `find -H'), breaking
;; `project--files-in-directory', `grep', `compile', and any
;; `shell-command'. Nushell can still be the interactive login shell — Emacs
;; only needs POSIX syntax for the strings it shells out.
(setq shell-file-name (or (executable-find "bash") "/bin/sh"))

(require 'use-package-ensure-system-package)

;;(use-package direnv
;;  :config
;; (direnv-mode))

;; `envrc-async' defaults to nil: block until direnv finishes. A stale
;; flake (nix rebuild) then freezes the main thread for minutes. Wait
;; briefly so fast envs still land before mode hooks (eglot etc.), then
;; let direnv finish in the background.
(use-package envrc
  :custom
  (envrc-async 3)
  :config
  (envrc-global-mode))

(provide 'dl-path)
;;; dl-path.el ends here
