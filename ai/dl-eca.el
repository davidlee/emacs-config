;;; dl-eca.el --- ECA coding agents -*- lexical-binding: t; -*-

;; https://github.com/editor-code-assistant/eca-emacs
;; TODO keybindings

;; The server runs sandboxed as `jailed-eca' (bubblewrap), defined in
;; ~/flakes/features/agents.nix.  It reaches models through the local
;; LLM gateway on its own key, which `jailed-eca' reads from
;; ~/.config/llm-gateway/keys/eca; Emacs holds no eca key.
;;
;; The jail binds its cwd, so start it from the first workspace root;
;; roots added later are not visible to it.  The jail has its own pid
;; namespace, so Emacs' pid is invisible to the server's parent-liveness
;; probe (it would exit at once); bwrap's --die-with-parent covers orphan
;; cleanup instead.

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
  :vc (:url "https://github.com/editor-code-assistant/eca-emacs" :rev :newest)
  :custom
  ;; Run sandboxed; see the commentary.
  (eca-custom-command '("jailed-eca" "server"))
  (eca-process-wrapper-function #'dl-eca--run-in-first-root)
  (eca-send-process-id nil)
  ;; Pin the model client-side: an unmatched server `defaultModel' silently
  ;; falls back to eca's built-in default (Anthropic, at API rates).
  (eca-chat-custom-model "deepseek/deepseek-flash"))

(provide 'dl-eca)
;;; dl-eca.el ends here
