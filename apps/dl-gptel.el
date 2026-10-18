;;; dl-gptel.el --- gptel - minimalist agent chat harness -*- lexical-binding: t; -*-

;;; Commentary:
;; OpenAI on its OAuth backend (`openai-sub'), and three backends through
;; the local LLM gateway (see dl-llm-gateway.el) on gptel's own gateway
;; key: DeepSeek natively, OpenRouter, and Fireworks (fast, cheap
;; open-weight models).  Gateway model names are listed explicitly, as
;; the gateway serves them.  The key is read at request time, so no
;; plaintext lands in `process-environment'.  gptel sends requests via
;; `curl --config -' over stdin, so the Authorization header never
;; reaches /proc/<pid>/cmdline either — do not add a backend
;; `:curl-args' that passes it as `-H'.

;;; Code:

(require 'url-parse)
(require 'dl-llm-gateway)
(require 'dl-gptel-readonly)
(require 'dl-gptel-shape)
(require 'dl-gptel-macher)

(use-package macher
  :custom
  ;; The org UI has structured conversations and nice content folding.
  (macher-action-buffer-ui 'org)
  ;; Not the $HOME repo: see dl-gptel-macher.el.
  (macher-workspace-functions
   '(dl-gptel-macher-workspace-project macher-workspace-file))

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

(defun dl-gptel--key ()
  "Return gptel's key for the LLM gateway, read afresh on every request."
  (dl-llm-gateway-key "gptel"))

;;
;; LOAD GPTEL
;;
(use-package gptel
  :config
  ;; Through the gateway.  The model list is explicit: gptel's default
  ;; also names models the gateway does not serve.
  (apply #'gptel-make-deepseek "deepseek"
         :key #'dl-gptel--key
         :stream t
         :models '((deepseek-flash
                    :capabilities (media tool-use reasoning url)
                    :mime-types ("image/jpeg" "image/png" "image/gif" "image/webp")
                    :context-window 1000))
         (dl-gptel--gateway))

  ;; Gateway names are `openrouter/<OpenRouter id>', so OpenRouter's own
  ;; routers carry a double prefix.  No DeepSeek ids: that is `deepseek'.
  ;; Plain symbols carry no capabilities, so images are not sent.
  (apply #'gptel-make-openai "openrouter"
         :key #'dl-gptel--key
         :stream t
         :models '(openrouter/openrouter/auto
                   openrouter/openrouter/free
                   openrouter/openrouter/pareto-code

                   openrouter/qwen/qwen3.8-flash
                   openrouter/z-ai/glm-5.3-flash
                   openrouter/~z-ai/glm-flash-latest
                   openrouter/~z-ai/glm-latest

                   openrouter/google/gemini-3.8-flash
                   openrouter/google/gemini-3-flash-preview

                   openrouter/xiaomi/mimo-v2.6-pro
                   openrouter/xiaomi/mimo-v2.6-flash)
         (dl-gptel--gateway))

  (apply #'gptel-make-openai "fireworks"
         :key #'dl-gptel--key
         :stream t
         :models '(fireworks/nemotron-lightning-3p5-30b-a3b)
         (dl-gptel--gateway))

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
