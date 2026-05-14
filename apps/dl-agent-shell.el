;;; dl-agent-shell.el --- Agent Shell -*- lexical-binding: t; -*-
(use-package agent-shell
  :ensure t
  :ensure-system-package
  ;; Add agent installation configs here
  (
                                        ;(claude . "brew install claude-code")
    (claude-agent-acp . "npm install -g @agentclientprotocol/claude-agent-acp")))

(provide 'dl-agent-shell)
;;; dl-agent-shell.el ends here
