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
(require 'dl-gptel-readonly)

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

;;
;; LOAD GPTEL
;;
(use-package gptel
  :config
  (gptel-make-deepseek "deepseek"
    :key (lambda () (my/op-key "DEEPSEEK"))
    :stream t)

  (setq gptel-model 'gpt-5.6-terra
    gptel-backend (gptel-make-openai-oauth "openai-sub")))

(require 'dl-gptel-presets)

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
