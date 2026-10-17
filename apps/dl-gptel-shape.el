;;; dl-gptel-shape.el --- per-backend request body shaping for gptel -*- lexical-binding: t; -*-

;;; Commentary:
;; Presets speak one dialect: effort is (:reasoning (:effort E)), as the
;; Responses API and OpenRouter take it.  Providers that want something
;; else get a shaper here, applied when gptel builds the request body —
;; after every @cookie, so the backend is final whatever their order.
;; DeepSeek gets its own shaper because its effort is only on or off.
;;
;; Hooks `gptel--request-data', which is internal: if a gptel update
;; changes it, dl-gptel-presets-test fails rather than requests going
;; out malformed.

;;; Code:

(require 'map)
(require 'gptel-openai)

(defun dl-gptel-flat-reasoning-effort (data)
  "Return request DATA with (:reasoning (:effort E)) as :reasoning_effort E.
For OpenAI chat-completions providers, such as Fireworks, that reject
the nested form."
  (if-let* ((effort (plist-get (plist-get data :reasoning) :effort)))
      (plist-put (map-delete (copy-sequence data) :reasoning)
                 :reasoning_effort effort)
    data))

(defun dl-gptel-deepseek-thinking (data)
  "Return request DATA flattened, with effort \"low\" sent as \"none\".
DeepSeek's thinking is on or off; LiteLLM disables it only for \"none\"."
  (let ((flat (dl-gptel-flat-reasoning-effort data)))
    (if (equal (plist-get flat :reasoning_effort) "low")
        (plist-put flat :reasoning_effort "none")
      flat)))

(defvar dl-gptel-request-shapers
  '(("deepseek" . dl-gptel-deepseek-thinking)
    ("fireworks" . dl-gptel-flat-reasoning-effort))
  "Alist of backend name to a function that reshapes its request body.")

(cl-defmethod gptel--request-data :around ((backend gptel-openai) _prompts)
  "Reshape the request body by BACKEND's entry in `dl-gptel-request-shapers'."
  (let ((data (cl-call-next-method)))
    (if-let* ((shape (alist-get (gptel-backend-name backend)
                                dl-gptel-request-shapers nil nil #'equal)))
        (funcall shape data)
      data)))

(provide 'dl-gptel-shape)
;;; dl-gptel-shape.el ends here
