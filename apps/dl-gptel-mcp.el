;;; dl-gptel-mcp.el --- MCP servers as gptel tools, via mcp.el -*- lexical-binding: t; -*-

;;; Commentary:
;; gptel's MCP client is `gptel-mcp-connect' (gptel-integrations) over
;; mcp.el's hub; each server's tools join gptel category "mcp-NAME".
;;
;; org-mcp runs inside this Emacs: mcp.el spawns mcp-server-lib's stdio
;; script, which relays each JSON-RPC line back in through emacsclient.
;; A synchronous connect is safe -- Emacs serves emacsclient while it
;; waits on the script.
;;
;;   gptel ─▶ mcp.el ─stdio─▶ emacs-mcp-stdio.sh ─emacsclient─▶ org-mcp
;;                                                  (this Emacs)
;;
;; mcp.el drops MCP's readOnlyHint, so every tool would run unprompted;
;; `dl-gptel-mcp-connect' makes those not marked read-only ask first.

;;; Code:

(require 'gptel-integrations)
(require 'mcp-hub)
(require 'mcp-server-lib-commands)
(require 'org-mcp)
(require 'server)

(defun dl-gptel-mcp-org-server ()
  "Return the `mcp-hub-servers' entry for org-mcp, served by this Emacs.
Built at connect time: the script lives in the Nix store, which moves
with every rebuild, and the socket is whichever this Emacs serves."
  `("org-mcp"
    :command ,(expand-file-name "emacs-mcp-stdio.sh"
                                (file-name-directory
                                 (locate-library "mcp-server-lib")))
    :args (,(concat "--socket=" (expand-file-name server-name server-socket-dir))
           ;; Explicit: the script would derive "org" from the init function.
           "--server-id=org-mcp"
           "--init-function=org-mcp-enable"
           "--stop-function=org-mcp-disable")))

(defun dl-gptel-mcp--confirm-writes (server)
  "Make the gptel tools of MCP SERVER not marked read-only ask first."
  (when-let* ((connection (gethash server mcp-server-connections)))
    (seq-doseq (tool (mcp--tools connection))
      (unless (eq (plist-get (plist-get tool :annotations) :readOnlyHint) t)
        (setf (gptel-tool-confirm
               (gptel-get-tool (list (concat "mcp-" server)
                                     (plist-get tool :name))))
              t)))))

(defun dl-gptel-mcp-connect (server)
  "Connect gptel to MCP SERVER, waiting for its tools.
Tools the server does not mark read-only ask before running.
The tools are registered, not activated: `gptel-mcp-connect' would push
them onto the global `gptel-tools', enabling them in every gptel buffer.
Presets choose the active tools."
  (let ((gptel-tools gptel-tools))
    (gptel-mcp-connect (list server) 'sync))
  (dl-gptel-mcp--confirm-writes server))

(defun dl-gptel-mcp-org-connect ()
  "Connect gptel to org-mcp, scoped to the current agenda files."
  (setq org-mcp-allowed-files (org-agenda-files))
  (unless mcp-server-lib--running (mcp-server-lib-start))
  (setf (alist-get "org-mcp" mcp-hub-servers nil nil #'equal)
        (cdr (dl-gptel-mcp-org-server)))
  (dl-gptel-mcp-connect "org-mcp"))

(provide 'dl-gptel-mcp)
;;; dl-gptel-mcp.el ends here
