;;; dl-claude.el --- Claude IDE -*- lexical-binding: t; -*-

;;; https://github.com/manzaltu/claude-code-ide.el

(require 'web-server)

(unless (fboundp 'ws-process)
  (defun ws-process (obj)
    "Compatibility accessor for web-server objects."
    (oref obj process)))
(use-package claude-code-ide
  :vc (:url "https://github.com/manzaltu/claude-code-ide.el"
        :rev :newest)
  :custom
  (claude-code-ide-cli-path "/home/david/.local/bin/claude")
  :bind ("C-c '" . claude-code-ide-menu)
  :config
  (require 'web-server)
  (unless (fboundp 'ws-process)
    (defun ws-process (obj)
      "Compatibility accessor for web-server objects."
      (oref obj process)))
  (claude-code-ide-cli-path "/home/david/.local/bin/claude")
  (claude-code-ide-terminal-backend 'vterm)
  (claude-code-ide-emacs-tools-setup))

;; (use-package claude-code-ide
;;   :vc (:url "https://github.com/manzaltu/claude-code-ide.el"
;;         :rev :newest)
;;   :bind ("C-c '" . claude-code-ide-menu)
;;   :custom
;;   (claude-code-ide-cli-path "/home/david/.local/bin/claude")
;;   (claude-code-ide-terminal-backend 'vterm)
;;                                         ;:config
;;                                         ;(claude-code-ide-emacs-tools-setup)
;;   )

(provide 'dl-claude)
;;; dl-claude.el ends here
