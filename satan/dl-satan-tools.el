;;; dl-satan-tools.el --- Tool registry + dispatch -*- lexical-binding: t; -*-

;; The broker holds a registry of tool-specs.  A tool-spec carries
;; mechanism only — name, risk, schema, mode allowlist, handler:
;;
;;   (:name        "org_read_context"
;;    :risk        read|low|medium|high
;;    :args-schema (KEY (:type symbol :required bool :enum (...)))*
;;    :modes       ("morning" "motd" ...)
;;    :handler     dl-satan-tool/org-read-context)
;;
;; The model-facing description for each tool lives outside dotfiles,
;; under `dl-satan-tools-descriptions-dir' (default
;; `~/notes/satan/tools/<name>.md').  See `dl-satan-tool-json-schema'.
;;
;; `dl-satan-tool-dispatch' performs lookup, allowlist check, schema
;; validation, and invokes the handler.  Handler returns (ok . RESULT) or
;; (error . MESSAGE).

(require 'cl-lib)
(require 'subr-x)
(require 'dl-notes-paths)

(defcustom dl-satan-tools-descriptions-dir
  (expand-file-name "satan/tools/" dl-notes-root)
  "Directory holding model-facing tool description files.
One markdown file per tool, named `<tool-name>.md'.  Canonical
behavioural text for each tool lives here; the elisp tool-spec
carries only mechanism (schema, capability, handler)."
  :type 'directory :group 'dl-satan)

(defvar dl-satan-tools nil
  "Alist of (NAME . SPEC) tool registrations.")

(defun dl-satan-tool-register (spec)
  "Register or replace tool SPEC keyed by its `:name'."
  (let ((name (plist-get spec :name)))
    (setq dl-satan-tools
          (cons (cons name spec)
                (cl-remove name dl-satan-tools :key #'car :test #'equal)))))

(defun dl-satan-tool-lookup (name)
  (cdr (assoc name dl-satan-tools)))

(defun dl-satan-tool-allowed-p (name mode-tools)
  "Return non-nil if NAME is present in MODE-TOOLS (mode's :tools allowlist)."
  (and mode-tools (member name mode-tools) t))

(defun dl-satan-tool--plist-like-p (val)
  "Return non-nil if VAL is a (possibly empty) plist whose keys are keywords."
  (and (listp val)
       (or (null val)
           (and (keywordp (car val))
                (= (mod (length val) 2) 0)))))

(defun dl-satan-tool--validate-arg (args key constraints)
  "Validate ARGS[KEY] against CONSTRAINTS plist.
Return nil on success, or an error string.

Supported constraints:
  :type       string|integer|boolean|number|object
  :required   bool
  :enum       (list-of-values)
  :pattern    REGEXP  (string types only)
  :shape      ARGS-SCHEMA  (object types only; recursive)"
  (let* ((sym (intern (concat ":" (symbol-name key))))
         (val (plist-get args sym))
         (type     (plist-get constraints :type))
         (required (plist-get constraints :required))
         (enum     (plist-get constraints :enum))
         (pattern  (plist-get constraints :pattern))
         (shape    (plist-get constraints :shape)))
    (cond
     ((and required (null val))
      (format "missing required arg: %s" key))
     ((null val) nil)
     ((and (eq type 'string) (not (stringp val)))
      (format "arg %s must be string" key))
     ((and (eq type 'integer) (not (integerp val)))
      (format "arg %s must be integer" key))
     ((and (eq type 'number) (not (numberp val)))
      (format "arg %s must be number" key))
     ((and (eq type 'object) (not (dl-satan-tool--plist-like-p val)))
      (format "arg %s must be object" key))
     ((and enum (not (member val enum)))
      (format "arg %s must be one of %S" key enum))
     ((and pattern (stringp val) (not (string-match-p pattern val)))
      (format "arg %s must match %s" key pattern))
     ((and (eq type 'object) shape)
      (let ((cursor shape) err)
        (while (and cursor (null err))
          (setq err (dl-satan-tool--validate-arg val (car cursor) (cadr cursor)))
          (setq cursor (cddr cursor)))
        err))
     (t nil))))

(defun dl-satan-tool-validate-args (spec args)
  "Return nil if ARGS conform to SPEC `:args-schema', else error string."
  (let ((schema (plist-get spec :args-schema))
        err)
    (while (and schema (null err))
      (let ((key (car schema))
            (constraints (cadr schema)))
        (setq err (dl-satan-tool--validate-arg args key constraints))
        (setq schema (cddr schema))))
    err))

(defun dl-satan-tool-dispatch (call mode-tools run-ctx)
  "Dispatch a `tool_call' plist CALL.  Return a `tool_result' plist.
MODE-TOOLS is the current mode's allowlist.  RUN-CTX is passed to the handler."
  (let* ((id   (plist-get call :id))
         (name (plist-get call :name))
         (args (plist-get call :args))
         (spec (dl-satan-tool-lookup name)))
    (cond
     ((null spec)
      (list :type "tool_result" :id id :ok :false
            :error (format "unknown tool: %s" name)))
     ((not (dl-satan-tool-allowed-p name mode-tools))
      (list :type "tool_result" :id id :ok :false
            :error (format "tool not allowed in this mode: %s" name)))
     (t
      (let ((schema-err (dl-satan-tool-validate-args spec args)))
        (if schema-err
            (list :type "tool_result" :id id :ok :false :error schema-err)
          (condition-case err
              (let ((res (funcall (plist-get spec :handler) args run-ctx)))
                (if (eq (car-safe res) 'ok)
                    (list :type "tool_result" :id id :ok t :result (cdr res))
                  (list :type "tool_result" :id id :ok :false
                        :error (format "%s" (cdr res)))))
            (error
             (list :type "tool_result" :id id :ok :false
                   :error (error-message-string err))))))))))

;; ---------- Model-facing schema (manifest assembly) ----------
;;
;; The broker writes the full OpenAI-tools JSON Schema for every allowed
;; tool into `manifest.json'.  Schemas are assembled from two sources:
;;
;;   - mechanical (this file + elisp tool-spec): `:args-schema',
;;     types/required/enum, tool name.
;;   - model-facing (notes): description text under
;;     `dl-satan-tools-descriptions-dir'.
;;
;; The harness reads schemas verbatim from the manifest; no canonical
;; descriptions live in dotfiles.

(defun dl-satan-tool--description (name)
  "Return the model-facing description for tool NAME.
Reads `<dl-satan-tools-descriptions-dir>/<name>.md'; signals if
missing — a tool without a description is a misconfiguration."
  (let ((path (expand-file-name (concat name ".md")
                                dl-satan-tools-descriptions-dir)))
    (unless (file-readable-p path)
      (error "SATAN: tool description missing: %s" path))
    (with-temp-buffer
      (let ((coding-system-for-read 'utf-8))
        (insert-file-contents path))
      (string-trim (buffer-string)))))

(defun dl-satan-tool--jsonschema-type (sym)
  "Map an `:args-schema' type symbol to its JSON Schema name."
  (pcase sym
    ('string  "string")
    ('integer "integer")
    ('boolean "boolean")
    ('number  "number")
    ('object  "object")
    ('array   "array")
    (_ (error "SATAN: unsupported arg type: %S" sym))))

(defun dl-satan-tool--args-schema-to-jsonschema (args-schema)
  "Convert an elisp `:args-schema' plist into a JSON Schema parameters dict.
Returns a plist: (:type \"object\" :properties (...) :required [...]).
Recurses into `:shape' for nested object args."
  (let ((props nil)
        (required nil)
        (cursor args-schema))
    (while cursor
      (let* ((key (car cursor))
             (constraints (cadr cursor))
             (type (plist-get constraints :type))
             (enum (plist-get constraints :enum))
             (pattern (plist-get constraints :pattern))
             (shape (plist-get constraints :shape))
             (items (plist-get constraints :items))
             (req  (plist-get constraints :required))
             (prop (cond
                    ((and (eq type 'object) shape)
                     (dl-satan-tool--args-schema-to-jsonschema shape))
                    ((eq type 'array)
                     (let ((p (list :type "array")))
                       (when items
                         (setq p (plist-put p :items
                                            (list :type
                                                  (dl-satan-tool--jsonschema-type
                                                   items)))))
                       p))
                    (t (list :type (dl-satan-tool--jsonschema-type type))))))
        (when enum
          (setq prop (plist-put prop :enum (vconcat enum))))
        (when pattern
          (setq prop (plist-put prop :pattern pattern)))
        (push (cons (intern (concat ":" (symbol-name key))) prop) props)
        (when req
          (push (symbol-name key) required)))
      (setq cursor (cddr cursor)))
    (let ((properties (apply #'append
                             (mapcar (lambda (kv)
                                       (list (car kv) (cdr kv)))
                                     (nreverse props)))))
      (list :type "object"
            :properties properties
            :required (vconcat (nreverse required))))))

(defun dl-satan-tool-json-schema (tool-spec)
  "Return the OpenAI-tools dict for TOOL-SPEC, ready for the manifest.
Description is loaded from `dl-satan-tools-descriptions-dir'."
  (let* ((name (plist-get tool-spec :name))
         (desc (dl-satan-tool--description name))
         (params (dl-satan-tool--args-schema-to-jsonschema
                  (plist-get tool-spec :args-schema))))
    (list :type "function"
          :function (list :name name
                          :description desc
                          :parameters params))))

(defun dl-satan-tool-final-schema ()
  "Return the synthetic `satan_final' tool schema.
`satan_final' is harness-emitted (terminal signal) but its description
is canonical here so every adapter sees the same text."
  (let ((desc (dl-satan-tool--description "satan_final")))
    (list :type "function"
          :function
          (list :name "satan_final"
                :description desc
                :parameters
                (list :type "object"
                      :properties
                      (list :summary (list :type "string")
                            :actions
                            (list :type "array"
                                  :items
                                  (list :type "object"
                                        :properties
                                        (list :type (list :type "string")
                                              :args (list :type "object"))
                                        :required (vector "type"))))
                      :required (vector "summary"))))))

(provide 'dl-satan-tools)
;;; dl-satan-tools.el ends here
