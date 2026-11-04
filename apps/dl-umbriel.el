;;; dl-umbriel.el --- Talk to umbriel over its socket -*- lexical-binding: t; -*-

;; Umbriel, the Wayland compositor, answers JSON requests on a UNIX
;; socket: one object per line, then `{"ok":…}' or `{"err":…}' back
;; before the server closes the connection.  This file is the only
;; place that talks to it, and it executes no program: no `umbriel'
;; binary to be missing, no dev-shell library path to break.
;;
;; Every request reports one shape, `(:ok VALUE)' or
;; `(:failure KIND DETAIL)', where KIND is one of:
;;
;;   no-path    the socket path cannot be resolved from the environment
;;   absent     no socket at that path
;;   refused    a socket, but nothing accepting (a stale socket)
;;   closed     the connection ended before a reply
;;   rejected   the compositor answered `{"err":…}'
;;   malformed  the reply was not a JSON object
;;
;; Everything is asynchronous: callers pass a callback, nothing blocks.
;; See docs/emacs/umbriel.md.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)

;;;; Socket path

(defun dl-umbriel--present-p (value)
  "Non-nil when VALUE, an environment value, is set and not empty."
  (and value (not (string-empty-p value))))

(defun dl-umbriel-socket-path ()
  "Umbriel's socket path from the environment, or nil.
Mirrors the umbriel CLI: UMBRIEL_SOCKET, else
$XDG_RUNTIME_DIR/umbriel-$WAYLAND_DISPLAY.sock."
  (let ((explicit (getenv "UMBRIEL_SOCKET"))
        (runtime (getenv "XDG_RUNTIME_DIR"))
        (display (getenv "WAYLAND_DISPLAY")))
    (cond ((dl-umbriel--present-p explicit) explicit)
          ((and (dl-umbriel--present-p runtime) (dl-umbriel--present-p display))
           (format "%s/umbriel-%s.sock" runtime display)))))

(defun dl-umbriel--no-path-failure ()
  "The failure for an unresolvable socket path, naming the unset variables."
  (list :failure 'no-path
        (concat (string-join (seq-remove (lambda (name) (dl-umbriel--present-p (getenv name)))
                                         '("UMBRIEL_SOCKET" "XDG_RUNTIME_DIR" "WAYLAND_DISPLAY"))
                             ", ")
                " unset")))

;;;; Request objects

(defun dl-umbriel-query (cmd)
  "The request object for the query CMD, e.g. \"windows\"."
  `((cmd . ,cmd)))

(defun dl-umbriel-action (action &optional fields)
  "The request object for ACTION with FIELDS, an alist of action fields.
Fields whose value is nil are dropped: the compositor rejects empty ones."
  `((cmd . "action") (action . ,action) ,@(seq-filter #'cdr fields)))

(defconst dl-umbriel-subscribe-request
  '((cmd . "subscribe") (events . ["windows" "workspaces"]))
  "The request that opens the windows and workspaces event stream.")

;;;; Parsing and framing

(defun dl-umbriel-parse (line)
  "Parse LINE, one JSON value from umbriel.
Objects become alists, arrays lists, and false and null nil."
  (json-parse-string line :object-type 'alist :array-type 'list
                     :false-object nil :null-object nil))

(defun dl-umbriel--parse-object (line)
  "LINE parsed when it is a JSON object, else nil."
  (let ((value (condition-case nil (dl-umbriel-parse line) (json-error nil))))
    (and (consp value) (consp (car value)) (symbolp (caar value)) value)))

(defun dl-umbriel--malformed (line)
  "The failure for LINE, which is not what umbriel should send."
  (list :failure 'malformed (truncate-string-to-width line 80 nil nil "…")))

(defun dl-umbriel--take-lines (pending chunk)
  "Split PENDING text plus CHUNK into (LINES . REST).
LINES are the complete lines; REST is the unterminated remainder."
  (let ((parts (split-string (concat pending chunk) "\n")))
    (cons (butlast parts) (car (last parts)))))

(defun dl-umbriel--reply-result (line)
  "The result of the reply LINE."
  (let ((reply (dl-umbriel--parse-object line)))
    (cond ((assq 'ok reply) (list :ok (alist-get 'ok reply)))
          ((assq 'err reply) (list :failure 'rejected (format "%s" (alist-get 'err reply))))
          (t (dl-umbriel--malformed line)))))

;;;; Transport

(defun dl-umbriel--connect-failure (err path)
  "The failure for ERR, signalled connecting to PATH."
  (if (eq (car err) 'file-missing)
      (list :failure 'absent path)
    (list :failure 'refused (error-message-string err))))

(defun dl-umbriel--connect (path filter sentinel)
  "Open a connection to the socket at PATH with FILTER and SENTINEL."
  (make-network-process :name "umbriel" :family 'local :service path
                        :coding 'utf-8-unix :noquery t
                        :filter filter :sentinel sentinel))

(defun dl-umbriel-send (request callback)
  "Send REQUEST to umbriel on a fresh connection.
CALLBACK receives the result exactly once, when the connection ends."
  (if-let* ((path (dl-umbriel-socket-path)))
      (let ((pending "") (delivered nil) (process nil))
        (cl-flet ((deliver (result)
                    ;; Flag first: `delete-process' runs the sentinel at once.
                    (unless delivered
                      (setq delivered t)
                      (unwind-protect (funcall callback result)
                        (when process (delete-process process))))))
          (condition-case err
              (setq process
                    (dl-umbriel--connect
                     path
                     (lambda (_process chunk)
                       (pcase-let ((`(,lines . ,rest) (dl-umbriel--take-lines pending chunk)))
                         (setq pending rest)
                         (when lines (deliver (dl-umbriel--reply-result (car lines))))))
                     (lambda (_process event)
                       (deliver (list :failure 'closed (string-trim event))))))
            (file-error (deliver (dl-umbriel--connect-failure err path))))
          (when process
            (condition-case err
                (process-send-string process (concat (json-serialize request) "\n"))
              (error (deliver (list :failure 'closed (error-message-string err))))))))
    (funcall callback (dl-umbriel--no-path-failure))))

(defun dl-umbriel-send-all (requests callback)
  "Send REQUESTS in order, each after the previous one succeeded.
CALLBACK receives the first failure, or the last success."
  (dl-umbriel-send (car requests)
                   (lambda (result)
                     (if (or (eq (car result) :failure) (null (cdr requests)))
                         (funcall callback result)
                       (dl-umbriel-send-all (cdr requests) callback)))))

;;;; Reporting failures

(defconst dl-umbriel--remedies
  '((no-path . "set UMBRIEL_SOCKET")
    (absent . "is umbriel running in this session?")
    (refused . "restart umbriel")
    (closed . "retry; g in *umbriel* reconnects")
    (rejected . "the compositor refused the request")
    (malformed . "unexpected reply; report upstream"))
  "What to do about each failure kind.")

(defun dl-umbriel-failure-message (failure)
  "One sentence describing FAILURE, beginning with its kind."
  (pcase-let ((`(:failure ,kind ,detail) failure))
    (format "umbriel: %s — %s (%s)" kind detail (alist-get kind dl-umbriel--remedies))))

(defun dl-umbriel-echo-failure (result)
  "Echo RESULT when it is a failure; a success is silent."
  (when (eq (car result) :failure)
    (message "%s" (dl-umbriel-failure-message result))))

(provide 'dl-umbriel)
;;; dl-umbriel.el ends here
