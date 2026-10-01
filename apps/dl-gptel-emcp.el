;;; dl-gptel-emcp.el --- emcp tools as in-process gptel tools -*- lexical-binding: t; -*-

;;; Commentary:
;; emcp defines its MCP tools with `emcp-deftool': a function of
;; (SERVER SESSION SEND-RESULT SEND-ERROR ARGS) plus JSON-schema metadata
;; on the symbol's `emcp-tool' property.  This adapts one into a gptel tool
;; spec that calls it in-process -- no emcp server, no transport.
;;
;;   'emcp-tool metadata ─▶ :name :description :args
;;   emcp function       ─▶ async :function (CALLBACK &rest VALUES)
;;
;; Only tools that ignore SERVER and SESSION adapt: eval, send-keys and
;; screenshot use emcp's confirmation buffer or client channel, which need
;; a live session.  Arguments are scalars, as every emcp tool's are.

;;; Code:

(require 'emcp-tools)

(defconst dl-gptel-emcp-tools '(emcp-tools-find-references)
  "The emcp tools registered with gptel.
gptel-agent's introspection tools already cover the rest of emcp's
inspect profile.")

(defun dl-gptel-emcp--args (schema)
  "Return gptel :args for SCHEMA, an MCP input schema from `emcp-deftool'.
Properties not listed as required are optional."
  (let ((required (append (alist-get 'required schema) nil)))
    (mapcar (pcase-lambda (`(,name . ,property))
              `( :name ,(symbol-name name)
                 :type ,(intern (alist-get 'type property))
                 ,@(when-let* ((description (alist-get 'description property)))
                     (list :description description))
                 ,@(unless (member (symbol-name name) required)
                     '(:optional t))))
            (alist-get 'properties schema))))

(defun dl-gptel-emcp--result-text (result)
  "Return the text of MCP tool RESULT, prefixed \"Error: \" if it is one."
  (let ((text (mapconcat (lambda (content) (alist-get 'text content))
                         (alist-get 'content result) "\n")))
    (if (eq (alist-get 'isError result) t)
        (concat "Error: " text)
      text)))

(defun dl-gptel-emcp--function (tool names)
  "Return an async gptel function calling emcp TOOL with arguments NAMES.
gptel passes argument values positionally, nil for an omitted optional
one; those stay out of the arguments table so TOOL's defaults apply.
Every outcome, error or not, answers the callback: a dropped callback
would stall the gptel request."
  (lambda (callback &rest values)
    (let ((args (make-hash-table :test #'equal)))
      (cl-mapc (lambda (name value) (when value (puthash name value args)))
               names values)
      (condition-case err
          (funcall tool nil nil
                   (lambda (result)
                     (funcall callback (dl-gptel-emcp--result-text result)))
                   (lambda (_code message &optional _data)
                     (funcall callback (concat "Error: " message)))
                   args)
        (error (funcall callback
                        (concat "Error: " (error-message-string err))))))))

(defun dl-gptel-emcp-tool-spec (tool)
  "Return `gptel-make-tool' arguments for TOOL, a symbol from `emcp-deftool'.
The tool joins gptel-agent's \"introspection\" category."
  (let-alist (plist-get (get tool 'emcp-tool) :metadata)
    (let ((args (dl-gptel-emcp--args .inputSchema)))
      (list :name .name
            :description .description
            :args args
            :function (dl-gptel-emcp--function
                       tool (mapcar (lambda (arg) (plist-get arg :name)) args))
            :async t
            :include t
            :category "introspection"))))

(provide 'dl-gptel-emcp)
;;; dl-gptel-emcp.el ends here
