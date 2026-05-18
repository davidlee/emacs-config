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
      :key 'gptel-api-key-from-auth-source
      :stream t)))

(provide 'dl-gptel)
;;; dl-gptel.el ends here
