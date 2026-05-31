;;; mcp-smoke.el --- DE-007 Phase 1 transport smoke stub -*- lexical-binding: t; -*-

;; THROWAWAY spike artefact. NOT part of the loaded Emacs config; do not
;; `git add` into a tracked configDir. Purpose: prove the topology
;;
;;     pi.dev (MCP client) → socat STDIO UNIX-CONNECT:<sock> → THIS UDS server
;;
;; works end-to-end BEFORE building the real `dl-satan-mcp.el'. No SATAN
;; deps, no eval path, just enough MCP to answer initialize / tools/list /
;; tools/call / ping with newline-delimited JSON-RPC 2.0.
;;
;; Usage (in the running daemon):
;;   (load-file ".../phases/spike/mcp-smoke.el")
;;   M-x mcp-smoke-start      ; binds the UDS, prints the path
;;   ... wire socat in the jail, point pi's MCP config at it, run pi ...
;;   M-x mcp-smoke-stop
;;
;; Self-test (no pi) from a shell:
;;   printf '%s\n' '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{}}' \
;;     | socat - UNIX-CONNECT:$XDG_RUNTIME_DIR/satan-mcp-smoke.sock

(require 'json)
(require 'subr-x)

(defvar mcp-smoke-socket-path
  (expand-file-name "satan-mcp-smoke.sock"
                    (or (getenv "XDG_RUNTIME_DIR") "/tmp"))
  "Host path of the throwaway smoke UDS. Bind-mount THIS into pi's jail.")

(defvar mcp-smoke--proc nil "The listening server process, if any.")
(defvar mcp-smoke--bufs (make-hash-table :test 'eq)
  "Per-connection line buffer, keyed by the connection process.")

(defconst mcp-smoke--protocol-version "2025-06-18"
  "MCP protocol version this stub advertises. Adjust to match pi if it complains.")

(defun mcp-smoke--send (proc obj)
  "Serialize OBJ as one newline-delimited JSON-RPC message to PROC."
  (let ((line (json-serialize obj :null-object :null :false-object :false)))
    (process-send-string proc (concat line "\n"))))

(defun mcp-smoke--result (id result)
  (list :jsonrpc "2.0" :id id :result result))

(defun mcp-smoke--error (id code message)
  (list :jsonrpc "2.0" :id id
        :error (list :code code :message message)))

(defun mcp-smoke--handle (proc msg)
  "Handle one parsed JSON-RPC MSG (plist) from PROC."
  (let* ((id (plist-get msg :id))
         (method (plist-get msg :method))
         (params (plist-get msg :params)))
    (pcase method
      ;; --- lifecycle ---
      ("initialize"
       (mcp-smoke--send
        proc
        (mcp-smoke--result
         id
         (list :protocolVersion mcp-smoke--protocol-version
               :capabilities (list :tools (make-hash-table :test 'eq))
               :serverInfo (list :name "satan-mcp-smoke" :version "0")))))
      ;; notification: no id, no response
      ("notifications/initialized" nil)
      ("ping" (mcp-smoke--send proc (mcp-smoke--result id (make-hash-table :test 'eq))))
      ;; --- tools ---
      ("tools/list"
       (mcp-smoke--send
        proc
        (mcp-smoke--result
         id
         (list :tools
               (vector
                (list :name "satan_smoke_echo"
                      :description "Echo back the msg argument (smoke test)."
                      :inputSchema
                      (list :type "object"
                            :properties (list :msg (list :type "string"))
                            :required (vector "msg"))))))))
      ("tools/call"
       (let* ((name (plist-get params :name))
              (args (plist-get params :arguments))
              (msg-arg (plist-get args :msg)))
         (if (equal name "satan_smoke_echo")
             (mcp-smoke--send
              proc
              (mcp-smoke--result
               id
               (list :content
                     (vector (list :type "text"
                                   :text (format "echo: %s" msg-arg))))))
           (mcp-smoke--send
            proc
            (mcp-smoke--result
             id
             (list :content (vector (list :type "text"
                                          :text (format "unknown tool: %s" name)))
                   :isError t))))))
      (_
       ;; only respond to requests (have id); ignore unknown notifications
       (when id
         (mcp-smoke--send proc (mcp-smoke--error id -32601
                                                 (format "method not found: %s" method))))))))

(defun mcp-smoke--filter (proc chunk)
  "Accumulate CHUNK, dispatch each complete newline-delimited JSON-RPC line."
  (let* ((buf (concat (gethash proc mcp-smoke--bufs "") chunk))
         (lines (split-string buf "\n")))
    (puthash proc (car (last lines)) mcp-smoke--bufs) ; trailing partial
    (dolist (line (butlast lines))
      (let ((trimmed (string-trim line)))
        (unless (string-empty-p trimmed)
          (condition-case err
              (mcp-smoke--handle
               proc
               (json-parse-string trimmed :object-type 'plist
                                  :array-type 'list :null-object nil
                                  :false-object :false))
            (error
             (message "mcp-smoke: bad line %S: %s" trimmed
                      (error-message-string err)))))))))

(defun mcp-smoke--sentinel (proc event)
  (when (string-match-p "\\(closed\\|deleted\\|finished\\|exited\\|broken\\)" event)
    (remhash proc mcp-smoke--bufs)))

(defun mcp-smoke-start ()
  "Start the throwaway UDS MCP smoke server."
  (interactive)
  (when (and mcp-smoke--proc (process-live-p mcp-smoke--proc))
    (user-error "mcp-smoke already running on %s" mcp-smoke-socket-path))
  (when (file-exists-p mcp-smoke-socket-path)
    (delete-file mcp-smoke-socket-path))
  (setq mcp-smoke--proc
        (make-network-process
         :name "mcp-smoke"
         :server t
         :family 'local
         :service mcp-smoke-socket-path
         :coding 'utf-8
         :noquery t
         :filter #'mcp-smoke--filter
         :sentinel #'mcp-smoke--sentinel))
  (set-file-modes mcp-smoke-socket-path #o600)
  (message "mcp-smoke listening on %s" mcp-smoke-socket-path)
  mcp-smoke-socket-path)

(defun mcp-smoke-stop ()
  "Stop the smoke server and remove the socket."
  (interactive)
  (when (process-live-p mcp-smoke--proc)
    (delete-process mcp-smoke--proc))
  (setq mcp-smoke--proc nil)
  (when (file-exists-p mcp-smoke-socket-path)
    (delete-file mcp-smoke-socket-path))
  (clrhash mcp-smoke--bufs)
  (message "mcp-smoke stopped"))

(provide 'mcp-smoke)
;;; mcp-smoke.el ends here
