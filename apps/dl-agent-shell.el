;;; dl-agent-shell.el --- Agent Shell -*- lexical-binding: t; -*-

;;; Commentary:
;; ACP (Agent Client Protocol) shells.  agent-shell only speaks the protocol;
;; each agent needs its own adapter executable on `exec-path'.  The adapters
;; here come from three package managers — nix (~/.nix-profile/bin), npm
;; global (~/.npm-global/bin) and go (~/go/bin) — and only the first is in
;; the systemd user PATH, so dl-path.el puts the other two on `exec-path'.
;; Without that, agents resolve in a devshell Emacs and fail with
;; "Executable not found" in one launched from sway.

;;; Code:

(use-package agent-shell
  :ensure t
  :config
  ;; codex-acp has no nixpkgs derivation and the codex CLI has no `acp'
  ;; subcommand, so it runs from npm.  It depends on @openai/codex itself,
  ;; so nothing needs `codex' on PATH.  To pin, drop the -y and append
  ;; @VERSION; unpinned tracks latest (1.12.0 as of 2026-09-22).
  (setq agent-shell-openai-codex-acp-command
    '("npx" "-y" "@agentclientprotocol/codex-acp"))

  ;; ChatGPT subscription, not an API key: `codex login status' reports
  ;; "Logged in using ChatGPT" and codex-acp reuses those credentials.  A
  ;; subscription carries no API credits, so the OpenAI key in dl-gptel.el
  ;; is not an alternative here until that account is topped up.  If it is:
  ;;
  ;;   (agent-shell-openai-make-authentication
  ;;     :api-key (lambda () (my/op-key "OPENAI_ALT")))
  ;;
  ;; — but note the filter below builds every agent's client to test it, so
  ;; a key-resolving lambda would hit 1Password each time the picker opens.
  (setq agent-shell-openai-authentication
    (agent-shell-openai-make-authentication :login t))

  ;; Offer only agents whose adapter is installed.  The default list carries
  ;; 21, and choosing an absent one *is* the "Executable not found" error.
  ;; Idiom lifted from the `agent-shell-agent-configs' docstring.
  (setq agent-shell-agent-configs
    (lambda ()
      (seq-filter
        (lambda (maker)
          (when-let* ((config (funcall maker))
                       (client-maker (map-elt config :client-maker))
                       (client (ignore-errors
                                 (funcall client-maker (current-buffer))))
                       (command (map-elt client :command)))
            (executable-find command)))
        (agent-shell-default-agent-config-makers)))))

(provide 'dl-agent-shell)
;;; dl-agent-shell.el ends here
