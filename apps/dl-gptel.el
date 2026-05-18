;;; dl-gptel.el --- gptel - minimalist agent chat harness -*- lexical-binding: t; -*-

;; (secrets-delete-item "Login" "gptel-api-key")
;; (secrets-create-item "Login" "gptel-api-key"
;;                      "sk-ACTUAL_API_KEY"
;;                      :host "openrouter.ai"
;;                      :user "apikey")

(use-package gptel
  :config
  ;; (gptel-make-deepseek "deepseek")
  (setq gptel-model   'tencent/hy3-preview
    gptel-backend
    (gptel-make-openai "OpenRouter"
      :host "openrouter.ai"
      :endpoint "/api/v1/chat/completions"
      ;; Resolve from 1Password at request time via the op:// ref in
      ;; $OPENROUTER_API_KEY. `dl-secret' parses ~/.config/zsh/env.zsh at
      ;; startup so this works for both terminal- and sway-launched Emacs.
      :key (lambda () (my/op-read-env "OPENROUTER_API_KEY"))
      :stream t)))

(provide 'dl-gptel)
;;; dl-gptel.el ends here
