;;; dl-gptel.el --- gptel - minimalist agent chat harness -*- lexical-binding: t; -*-

;;; Commentary:
;; Three providers: OpenAI direct, DeepSeek direct, and OpenRouter as the
;; catch-all router.  Every backend resolves its key through `my/op-key'
;; (see dl-secret.el) at request time, so no plaintext lands on disk or in
;; `process-environment'.  gptel sends requests via `curl --config -' over
;; stdin, so the Authorization header never reaches /proc/<pid>/cmdline
;; either — do not add a backend `:curl-args' that passes it as `-H'.

;;; Code:

(require 'dl-secret)

(defvar dl-gptel-openrouter nil
  "The OpenRouter backend, or nil before `gptel-openrouter' has loaded.")

(defun dl-gptel-openai-key ()
  "Return the OpenAI API key: the alt credential, not $OPENAI_API_KEY.
Also the value of `gptel-api-key', so gptel's built-in OpenAI backend
uses the same account rather than falling through to auth-source."
  (my/op-key "OPENAI_ALT"))

(use-package gptel
  :config
  ;; Responses (/v1/responses), not chat completions: every frontier model
  ;; in `gptel--openai-models' carries the `responses-api' capability, and
  ;; that default list already tracks the live catalogue — nothing to
  ;; hand-maintain here.
  ;;(gptel-make-openai-responses "_openai-api-key"
  ;;  :key #'dl-gptel-openai-key
  ;;  :stream t)
  ;;(setq gptel-api-key #'dl-gptel-openai-key)



  ;; Models default to gptel's own DeepSeek list, which carries the
  ;; capability/cost metadata the menu needs.  Two of its ids are labelled
  ;; DEPRECATED upstream and no longer appear in /v1/models; the live pair
  ;; is deepseek-flash and deepseek-v4-pro.
  (gptel-make-deepseek "deepseek"
    :key (lambda () (my/op-key "DEEPSEEK"))
    :stream t)

  (setq gptel-model 'gpt-5.6-terra
    gptel-backend (gptel-make-openai-oauth "openai-sub")))

(use-package gptel-openrouter
  :ensure nil
  :vc (:url "https://github.com/darcamo/gptel-openrouter.git")
  :after gptel
  :config
  ;; The default backend, set below: OpenRouter routes everything, and its
  ;; own key is the one with credit on it.
  ;;
  ;; OpenRouter is the router, so its model list is hand-picked — the
  ;; upstream catalogue is thousands long.  `openai/*' entries are
  ;; deliberately absent: GPT models belong on the direct backend above,
  ;; which bills the alt key.
  (setq dl-gptel-openrouter
    (gptel-make-openai "openrouter"
      :host "openrouter.ai"
      :endpoint "/api/v1/chat/completions"
      :key (lambda () (my/op-key "OPENROUTER"))
      :stream t
      ;;  cat ~/.emacs.d/.cache/gptel-openrouter/models.json| jq '.data[].id' | sort
      :models (gptel-openrouter-get-annotated-models
                '(
                   deepseek/deepseek-flash
                   ~deepseek/deepseek-flash-latest
                   ~deepseek/deepseek-pro-latest
                   deepseek/deepseek-v4.1-flash

                   openrouter/auto
                   openrouter/free
                   openrouter/pareto-code

                   qwen/qwen-3.8-flash
                   z-ai/glm-5.3-flash
                   ~z-ai/glm-flash-latest
                   ~z-ai/glm-latest

                   google/gemini-3.8-flash
                   google/gemini-3-flash-preview

                   xiaomi/mimo-v2.6-pro
                   xiaomi/mimo-v2.6-flash

                   ;;
                   ))))
  ;; (setq gptel-backend dl-gptel-openrouter)
  ;; Pinned only to stop gptel warning on first send: a nil `gptel-model'
  ;; falls back to (car models) anyway, but does it via `display-warning'.
  ;;(setq gptel-model 'deepseek/deepseek-flash)

  )

(provide 'dl-gptel)
;;; dl-gptel.el ends here
