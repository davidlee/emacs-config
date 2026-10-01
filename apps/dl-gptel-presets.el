;;; dl-gptel-presets.el --- gptel presets: roles, models and mixins -*- lexical-binding: t; -*-

;;; Commentary:
;; Presets compose.  Most are meant as per-turn @cookies in a prompt, so
;; their names are short words:
;;
;;   role     @default @lib       sets the system prompt (and a toolset)
;;   tools    @org @ro @web       appends or filters tools
;;   context  @see                adds the buffers on screen
;;   model    @gpt @deep @glm @gem
;;   effort   @quick @think       merges reasoning effort into the request
;;
;; Only roles set :system, so mixins stack on any role:
;;
;;   @lib @deep @think where did I put the cordage notes?
;;
;; Long role prompts are notes: `dl-gptel-prompt-dir'/NAME.org, read
;; whenever the preset is applied, so edits take effect on the next turn.

;;; Code:

(require 'gptel)
(require 'dl-notes-paths)
(require 'dl-gptel-readonly)

;; Autoloaded: mcp.el loads, and org-mcp's server starts, on first use.
(autoload 'dl-gptel-mcp-org-connect "dl-gptel-mcp")

(defvar dl-gptel-prompt-dir (my/notes-path "prompts" "gptel")
  "Directory of role prompts, one NAME.org per prompt.")

(defun dl-gptel-prompt (name)
  "Return role prompt NAME from `dl-gptel-prompt-dir', without #+keyword lines."
  (let ((file (expand-file-name (concat name ".org") dl-gptel-prompt-dir)))
    (unless (file-readable-p file)
      (user-error "gptel prompt %s: no file %s" name file))
    (with-temp-buffer
      (insert-file-contents file)
      (flush-lines "^#\\+[[:alnum:]_-]+:")
      (string-trim (buffer-string)))))

(defconst dl-gptel-writing-tools '("Insert" "Edit" "Write" "Mkdir" "Eval" "Bash")
  "Tools that change files or run code; @ro removes them.")

(defun dl-gptel-without-writes (tools)
  "Return TOOLS without `dl-gptel-writing-tools'."
  (seq-remove (lambda (tool) (member (gptel-tool-name tool) dl-gptel-writing-tools))
              tools))

(defun dl-gptel-with-visible-buffers (context)
  "Return CONTEXT plus the buffers on screen, leaving out gptel chats."
  (seq-union context
             (seq-remove (lambda (buffer) (buffer-local-value 'gptel-mode buffer))
                         (mapcar #'window-buffer (window-list)))))

(defconst dl-gptel-presets
  `((gpt :description "model: GPT 5.6 terra, ChatGPT subscription"
         :backend "openai-sub" :model gpt-5.6-terra)
    (deep :description "model: DeepSeek flash, OpenRouter"
          :backend "openrouter" :model ~deepseek/deepseek-flash-latest)
    (glm :description "model: GLM, OpenRouter"
         :backend "openrouter" :model ~z-ai/glm-latest)
    (gem :description "model: Gemini flash, OpenRouter"
         :backend "openrouter" :model google/gemini-3.8-flash)

    (quick :description "effort: low reasoning"
           :request-params (:merge (:reasoning (:effort "low"))))
    (think :description "effort: high reasoning"
           :request-params (:merge (:reasoning (:effort "high"))))

    (default :description "general emacs assistant"
             :parents gpt
             :system ,(concat "you're an advanced assistant for emacs knowledge work and coding. Stay in a tight, iterative loop with the user: concise responses, bounded tasks, not autonomous agentic execution.\n\n"
                              (dl-gptel-readonly-system-note))
             :tools ("Glob" "Grep" "Read" "Insert" "Edit" "Write" "Eval" "Bash"
                     "introspection"))
    (org :description "tools: + org-mcp over ~/notes (bar archives)"
         :parents default
         :pre dl-gptel-mcp-org-connect
         :tools (:append ("mcp-org-mcp")))
    (ro :description "tools: - anything that writes files or runs code"
        :tools (:function dl-gptel-without-writes))
    (web :description "tools: + web search and fetch"
         :tools (:append ("WebSearch" "WebFetch")))
    (see :description "context: + the buffers on screen"
         :context (:function dl-gptel-with-visible-buffers))

    (lib :description "librarian: does what's asked in ~/notes, nothing more"
         :parents (org ro)
         :system (:eval (dl-gptel-prompt "lib"))))
  "gptel presets, as (NAME . KEYS) for `gptel-make-preset'.")

(pcase-dolist (`(,name . ,keys) dl-gptel-presets)
  (apply #'gptel-make-preset name keys))

(provide 'dl-gptel-presets)
;;; dl-gptel-presets.el ends here
