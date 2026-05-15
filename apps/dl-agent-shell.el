;;; dl-agent-shell.el --- Agent Shell -*- lexical-binding: t; -*-
(use-package agent-shell
  :ensure t)

;; To enforce system deps, add to the use-package form above:
;;   :ensure-system-package
;;   ((claude-agent-acp . "npm install -g @agentclientprotocol/claude-agent-acp &2>1"))

(provide 'dl-agent-shell)
;;; dl-agent-shell.el ends here
