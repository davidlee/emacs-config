;;; dl-satan-tools.el --- Tool registry + dispatch -*- lexical-binding: t; -*-

;; The broker holds a registry of tool-specs.  A tool-spec is a plist:
;;
;;   (:name        "org.read_context"
;;    :description "..."
;;    :risk        read|low|medium|high
;;    :args-schema (KEY (:type symbol :required bool :enum (...)))*
;;    :modes       ("morning" "motd" ...)
;;    :handler     dl-satan-tool/org-read-context)
;;
;; `dl-satan-tool-dispatch' performs lookup, allowlist check, schema
;; validation, and invokes the handler.  Handler returns (ok . RESULT) or
;; (error . MESSAGE).

(require 'cl-lib)
(require 'subr-x)

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

(defun dl-satan-tool--validate-arg (args key constraints)
  "Validate ARGS[KEY] against CONSTRAINTS plist.
Return nil on success, or an error string."
  (let* ((sym (intern (concat ":" (symbol-name key))))
         (val (plist-get args sym))
         (type     (plist-get constraints :type))
         (required (plist-get constraints :required))
         (enum     (plist-get constraints :enum)))
    (cond
     ((and required (null val))
      (format "missing required arg: %s" key))
     ((null val) nil)
     ((and (eq type 'string) (not (stringp val)))
      (format "arg %s must be string" key))
     ((and (eq type 'integer) (not (integerp val)))
      (format "arg %s must be integer" key))
     ((and enum (not (member val enum)))
      (format "arg %s must be one of %S" key enum))
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

(provide 'dl-satan-tools)
;;; dl-satan-tools.el ends here
