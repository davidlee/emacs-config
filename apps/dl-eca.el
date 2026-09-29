;;; dl-eca.el --- ECA coding agents -*- lexical-binding: t; -*-

;; https://github.com/editor-code-assistant/eca-emacs
;; TODO keybindings

;; The server runs sandboxed as `jailed-eca' (bubblewrap, via `op run' for
;; API keys), built from the pinned llm-agents package in
;; ~/flakes/modules/home/linux/eca.nix.  The jail binds its cwd, so start it
;; from the first workspace root; roots added later are not visible to it.
;; The jail has its own pid namespace, so Emacs' pid is invisible to the
;; server's parent-liveness probe (it would exit at once); bwrap's
;; --die-with-parent covers orphan cleanup instead.
;;
;; Fallback (unjailed): M-x eca-install-server downloads the release binary
;; to `eca-server-install-path' (~/.emacs.d/eca/eca, gitignored), then set
;; `eca-custom-command' to ("op" "run" "--" <that path> "server").

(defun dl-eca--run-in-first-root (command roots)
  "Return COMMAND prefixed to run from the first of ROOTS.
Without ROOTS, run from `default-directory'.  Signal `user-error' if
that directory contains ~: the jail binds it read-write, which would
expose all of home."
  (let ((root (or (car roots) default-directory)))
    (when (file-in-directory-p "~" root)
      (user-error "Refusing to jail eca with %s as workspace; start it from a project"
                  root))
    (when (cdr roots)
      (display-warning 'eca (format "jailed-eca binds only %s" root)))
    (append (list "env" "-C" (expand-file-name root)) command)))

(use-package eca
  :ensure t
  :defer t
  :custom
  (eca-custom-command '("jailed-eca" "server"))
  (eca-process-wrapper-function #'dl-eca--run-in-first-root)
  (eca-send-process-id nil)
  :vc (:url "https://github.com/editor-code-assistant/eca-emacs" :rev :newest))

(provide 'dl-eca)
;;; dl-eca.el ends here
