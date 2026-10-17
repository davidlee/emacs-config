;;; dl-gptel.el --- gptel - minimalist agent chat harness -*- lexical-binding: t; -*-

;;; Commentary:
;; Four providers: OpenAI on its OAuth backend, DeepSeek through the
;; local LLM gateway (see dl-llm-gateway.el) on gptel's own gateway key,
;; Fireworks direct (fast, cheap open-weight models), and OpenRouter as
;; the catch-all router.  Fireworks and OpenRouter still resolve their keys
;; through `my/op-key' (see dl-secret.el) until they move to the gateway.
;; Every key is read at request time, so no plaintext lands in
;; `process-environment'.  gptel sends requests via `curl --config -' over
;; stdin, so the Authorization header never reaches /proc/<pid>/cmdline
;; either — do not add a backend `:curl-args' that passes it as `-H'.

;;; Code:

(require 'url-parse)
(require 'dl-secret)
(require 'dl-llm-gateway)
(require 'dl-gptel-readonly)
(require 'dl-gptel-shape)

(use-package macher
  :custom
  ;; The org UI has structured conversations and nice content folding.
  (macher-action-buffer-ui 'org)

  :hook
  ;; Set up action buffer behavior to your liking.  Alternately, do
  ;; this more generally in your `gptel-mode-hook'.
  (macher-action-buffer-setup
    . (lambda  ()
        ;; Auto-scroll responses.
        (setq-local window-point-insertion-type t)
        ;; Wrap lines.
        (visual-line-mode 1)))

  :config
  ;; Recommended - register macher tools and presets with gptel.
  (macher-install)

  ;; Recommended - enable macher infrastructure for tools/prompts in
  ;; any buffer.  (Actions and presets will still work without this.)
  (macher-enable)

  ;; Adjust buffer positioning to taste.
  ;; (add-to-list
  ;;  'display-buffer-alist
  ;;  '("\\*macher:.*\\*"
  ;;    (display-buffer-in-side-window)
  ;;    (side . bottom)))
  ;; (add-to-list
  ;;  'display-buffer-alist
  ;;  '("\\*macher-patch:.*\\*"
  ;;    (display-buffer-in-side-window)
  ;;    (side . right)))
  )

(use-package gptel
  :config
  ;; Optional - set up macher as soon as gptel is loaded.
  (require 'macher))

(defvar dl-gptel-openrouter nil
  "The OpenRouter backend, or nil before `gptel-openrouter' has loaded.")

(defun dl-gptel-openai-key ()
  "Return the OpenAI API key: the alt credential, not $OPENAI_API_KEY.
Also the value of `gptel-api-key', so gptel's built-in OpenAI backend
uses the same account rather than falling through to auth-source."
  (my/op-key "OPENAI_ALT"))

(defun dl-gptel--gateway ()
  "Return gptel connection args for `dl-llm-gateway-url'.
A plist of :protocol, :host (with its port, as gptel builds the URL
from protocol, host and endpoint only) and :endpoint (chat completions)."
  (let* ((url (url-generic-parse-url dl-llm-gateway-url))
         (port (url-portspec url)))
    (list :protocol (url-type url)
          :host (if port (format "%s:%s" (url-host url) port) (url-host url))
          :endpoint (concat (string-remove-suffix "/" (url-filename url))
                            "/chat/completions"))))

;;
;; LOAD GPTEL
;;
(use-package gptel
  :config
  ;; Through the gateway.  The model list is explicit: gptel's default
  ;; also names models the gateway does not serve.
  (apply #'gptel-make-deepseek "deepseek"
         :key (lambda () (dl-llm-gateway-key "gptel"))
         :stream t
         :models '((deepseek-flash
                    :capabilities (media tool-use reasoning url)
                    :mime-types ("image/jpeg" "image/png" "image/gif" "image/webp")
                    :context-window 1000))
         (dl-gptel--gateway))

  ;; OpenAI-compatible; model ids are Fireworks' full resource paths.
  (gptel-make-openai "fireworks"
    :host "api.fireworks.ai"
    :endpoint "/inference/v1/chat/completions"
    :key (lambda () (my/op-key "FIREWORKS"))
    :stream t
    :models '(accounts/fireworks/models/nemotron-lightning-3p5-30b-a3b))

  (setq gptel-model 'gpt-5.6-terra
    gptel-backend (gptel-make-openai-oauth "openai-sub")))

(require 'dl-gptel-presets)
(add-hook 'gptel-mode-hook #'dl-gptel-source-name-setup)

;; LLM notes on a buffer as Flymake diagnostics: M-x gptel-annotate, or
;; @gptel-annotate "file" in a prompt.  Needs structured output, which
;; DeepSeek and GLM don't reliably give; use @gpt.
(use-package gptel-annotate
  :vc ( :url "https://github.com/karthink/gptel-annotate"
        :rev :newest)
  :after gptel)

(use-package gptel-openrouter
  :ensure nil
  :vc (:url "https://github.com/darcamo/gptel-openrouter.git")
  :after gptel
  :config
  (require 'macher)
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
      ;;  cat ~/.config/emacs/.cache/gptel-openrouter/models.json| jq '.data[].id' | sort
      :models (gptel-openrouter-get-annotated-models
                '(
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
                   )))))

;;
;; Tools
;;

(use-package gptel-agent
  :vc ( :url "https://github.com/karthink/gptel-agent"
        :rev :newest)
  :config
  (setq gptel-agent-dirs
    (cons (expand-file-name "agents/" user-emacs-directory)
      gptel-agent-dirs))
  (gptel-agent-update)
  (require 'gptel-agent-tools-introspection)
  (require 'dl-gptel-emcp)
  (dolist (tool dl-gptel-emcp-tools)
    (apply #'gptel-make-tool (dl-gptel-emcp-tool-spec tool)))
  ;; Bash asks before every command by default; read-only ones needn't.
  (setf (gptel-tool-confirm (gptel-get-tool "Bash"))
    #'dl-gptel-bash-needs-confirm-p))

(provide 'dl-gptel)
;;; dl-gptel.el ends here
