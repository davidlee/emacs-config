;;; dl-minuet.el --- Minuet -*- lexical-binding: t; -*-
(require 'dl-llm-gateway)

(use-package minuet
  :config
  (setq minuet-provider 'openai-compatible)
  (setq minuet-request-timeout 2.5)
  (setq minuet-auto-suggestion-throttle-delay 1.5) ;; Increase to reduce costs and avoid rate limits
  (setq minuet-auto-suggestion-debounce-delay 0.6) ;; Increase to reduce costs and avoid rate limits

  ;; Local LLM gateway, on minuet's own key (one key per consumer).
  (plist-put minuet-openai-compatible-options :end-point
             (concat dl-llm-gateway-url "/chat/completions"))
  (plist-put minuet-openai-compatible-options :api-key
             (lambda () (dl-llm-gateway-key "minuet")))
  (plist-put minuet-openai-compatible-options :model "deepseek-flash")

  ;; Thinking off, for first-token latency: LiteLLM maps "none" to
  ;; DeepSeek's thinking: disabled.
  (minuet-set-optional-options minuet-openai-compatible-options :reasoning_effort "none")
  (minuet-set-optional-options minuet-openai-compatible-options :max_tokens 56)
  (minuet-set-optional-options minuet-openai-compatible-options :top_p 0.9))

(provide 'dl-minuet)
;;; dl-minuet.el ends here
