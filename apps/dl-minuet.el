;;; dl-minuet.el --- Minuet -*- lexical-binding: t; -*-
(use-package minuet
  :config
  (setq minuet-provider 'openai-compatible)
  (setq minuet-request-timeout 2.5)
  (setq minuet-auto-suggestion-throttle-delay 1.5) ;; Increase to reduce costs and avoid rate limits
  (setq minuet-auto-suggestion-debounce-delay 0.6) ;; Increase to reduce costs and avoid rate limits

  (plist-put minuet-openai-compatible-options :end-point "https://openrouter.ai/api/v1/chat/completions")
  (plist-put minuet-openai-compatible-options :api-key (lambda () (my/op-read-env "OPENROUTER_API_KEY")))
  (plist-put minuet-openai-compatible-options :model "deepseek/deepseek-v4-flash")


  ;; Prioritize throughput for faster completion
  (minuet-set-optional-options minuet-openai-compatible-options :provider '(:sort "throughput"))
  ;; Disable thinking to avoid first token latency
  (minuet-set-optional-options minuet-openai-compatible-options :reasoning_effort "none")
  (minuet-set-optional-options minuet-openai-compatible-options :max_tokens 56)
  (minuet-set-optional-options minuet-openai-compatible-options :top_p 0.9))

(provide 'dl-minuet)
;;; dl-minuet.el ends here
