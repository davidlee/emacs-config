;;; dl-gptel.el --- gptel - minimalist agent chat harness -*- lexical-binding: t; -*-
(defvar openrouter-models nil)


(use-package gptel-openrouter
  :ensure nil
  :vc (:url "https://github.com/darcamo/gptel-openrouter.git")
  :after gptel
  :config
  (setq openrouter-models (gptel-make-openai "openrouter"
                            :host "openrouter.ai"
                            :endpoint "/api/v1/chat/completions"
                            :key (lambda () (my/op-read-env "OPENROUTER_API_KEY"))
                            :stream t
                            ;;  cat ~/.emacs.d/.cache/gptel-openrouter/models.json| jq '.data[].id' | sort
                            :models (gptel-openrouter-get-annotated-models
                                      '(
                                         deepseek/deepseek-v4-flash
                                         deepseek/deepseek-v4-flash:free
                                         deepseek/deepseek-v4-pro

                                         tencent/hy3-preview
                                         qwen/qwen-plus
                                         qwen/qwen-3-coder
                                         qwen/qwen-3.6-flash
                                         qwen/qwen-3.7-max
                                         qwen/qwen-3.5-27b

                                         openrouter/auto
                                         openrouter/free
                                         openrouter/pareto-code

                                         openai/o4-mini
                                         openai/o4-mini-high

                                         openai/gpt-5-mini
                                         openai/gpt-5-codex
                                         openai/gpt-5.5
                                         openai/gpt-5.5-pro)))))



(use-package gptel
  :config

  (setq gptel-backend openrouter-models))

;; (setq  ;gptel-model
;;   gptel-backend
;;   (gptel-make-openai "OpenRouter"
;;     :host "openrouter.ai"
;;     :endpoint "/api/v1/chat/completions"
;;     ;; Resolve from 1Password at request time via the op:// ref in
;;     ;; $OPENROUTER_API_KEY. `dl-secret' parses ~/.config/zsh/env.zsh at
;;     ;; startup so this works for both terminal- and sway-launched Emacs.
;;     :key (lambda () (my/op-read-env "OPENROUTER_API_KEY"))
;;     :stream t))



(provide 'dl-gptel)
;;; dl-gptel.el ends here
