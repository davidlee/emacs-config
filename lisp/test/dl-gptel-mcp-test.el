;;; dl-gptel-mcp-test.el --- ert tests for gptel's MCP servers -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gptel-mcp RET.
;; Needs mcp.el (the `mcp' package); skipped when it is not installed.

;;; Code:

(require 'ert)
(when (locate-library "mcp-hub") (require 'dl-gptel-mcp))

(declare-function dl-gptel-mcp-org-connect "dl-gptel-mcp")
(declare-function dl-gptel-mcp-org-server "dl-gptel-mcp")

(defmacro dl-gptel-mcp-test--with-org-server (agenda-file &rest body)
  "Run BODY with gptel connected to org-mcp over AGENDA-FILE, then tear down.
Serves this Emacs on a private socket for the stdio script's emacsclient
calls, and isolates gptel's tool registry and the MCP hub."
  (declare (indent 1))
  `(let ((server-name (format "dl-gptel-mcp-test-%d" (emacs-pid)))
         (org-agenda-files (list ,agenda-file))
         (org-mcp-allowed-files nil)
         (mcp-hub-servers nil)
         (gptel-tools nil)
         (gptel--known-tools nil))
     (server-start)
     (unwind-protect
         (progn (dl-gptel-mcp-org-connect) ,@body)
       (when (gethash "org-mcp" mcp-server-connections)
         (mcp-stop-server "org-mcp"))
       (when mcp-server-lib--running (mcp-server-lib-stop))
       (server-force-delete))))

(defun dl-gptel-mcp-test--tool (name)
  "Return org-mcp's gptel tool NAME."
  (gptel-get-tool (list "mcp-org-mcp" name)))

(defun dl-gptel-mcp-test--call (name &rest args)
  "Call org-mcp's gptel tool NAME with ARGS; wait for and return its result."
  (let ((result 'pending))
    (apply (gptel-tool-function (dl-gptel-mcp-test--tool name))
           (lambda (r) (setq result r))
           args)
    (with-timeout (10 (error "Tool %s did not answer" name))
      (while (eq result 'pending) (accept-process-output nil 0.05)))
    result))

(ert-deftest dl-gptel-mcp/org-server-relays-into-this-emacs ()
  "The org-mcp entry runs mcp-server-lib's stdio script against our socket."
  (skip-unless (locate-library "mcp-hub"))
  (pcase-let ((`(,name :command ,command :args ,args) (dl-gptel-mcp-org-server)))
    (should (equal name "org-mcp"))
    (should (file-executable-p command))
    (should (member (concat "--socket=" (expand-file-name server-name server-socket-dir))
                    args))
    (should (member "--server-id=org-mcp" args))
    (should (member "--init-function=org-mcp-enable" args))))

(ert-deftest dl-gptel-mcp/org-tools-reach-gptel-and-writes-confirm ()
  "Connecting registers org-mcp's tools; only read-only ones run unprompted."
  (skip-unless (locate-library "mcp-hub"))
  (let ((agenda (make-temp-file "dl-gptel-mcp-test" nil ".org" "* TODO Test task\n")))
    (unwind-protect
        (dl-gptel-mcp-test--with-org-server agenda
          ;; Registered, not activated: presets choose the active tools.
          (should-not gptel-tools)
          (should-not (gptel-tool-confirm (dl-gptel-mcp-test--tool "org-read-outline")))
          (should (gptel-tool-confirm (dl-gptel-mcp-test--tool "org-add-todo")))
          (should (gptel-tool-confirm (dl-gptel-mcp-test--tool "org-refile-headline")))
          (should (string-match-p (regexp-quote agenda)
                                  (dl-gptel-mcp-test--call "org-get-allowed-files"))))
      (delete-file agenda))))

(provide 'dl-gptel-mcp-test)
;;; dl-gptel-mcp-test.el ends here
