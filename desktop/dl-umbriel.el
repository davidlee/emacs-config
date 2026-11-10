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
;;
;; Besides one-off requests there is one long-lived subscribe
;; connection, the stream: the compositor answers a subscription with a
;; snapshot of each requested family and then sends every change.  This
;; file holds the last snapshot it was sent, in one state record with
;; one writer per part, and announces each write through
;; `dl-umbriel-state-changed-hook' and to `dl-umbriel-await' waiters.
;; Only the stream speaks for the stream: nothing reconnects on its own,
;; so a closed stream stays visible instead of going silently stale.
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

;;;; Held state

;; One record, written only by the three functions below.  Kept as a
;; plain plist so it can be `let'-bound; nil reads as the initial state,
;; which is what a fresh Emacs starts from.

(defvar dl-umbriel--state nil
  "The held state: a plist of :windows, :workspaces, :status, :skipped.
Nil reads as the initial state: no snapshots, status `never', nothing
skipped.  Only `dl-umbriel--set-family', `dl-umbriel--set-status' and
`dl-umbriel--note-skipped' write it.")

(defvar dl-umbriel--stream nil
  "The one stream connection, or nil when the stream is not open.")

(defvar dl-umbriel--waiters nil
  "Pending one-shot waiters, each a cons of PREDICATE and CALLBACK.")

(defvar dl-umbriel-state-changed-hook nil
  "Hook run after every write to the held state, with no arguments.
Internal, not an option: the buffer listens here to repaint itself.
Waiters are settled after the hook, so the repaint has already happened
by the time a waiter's callback runs.")

(defun dl-umbriel-windows ()
  "The held windows snapshot, as the compositor sent it, or nil."
  (plist-get dl-umbriel--state :windows))

(defun dl-umbriel-workspaces ()
  "The held workspaces snapshot, as the compositor sent it, or nil."
  (plist-get dl-umbriel--state :workspaces))

(defun dl-umbriel-stream-status ()
  "The stream status: `never', `open', or a `(:failure KIND DETAIL)'."
  (or (plist-get dl-umbriel--state :status) 'never))

(defun dl-umbriel-skipped ()
  "How many stream lines were skipped on the current connection."
  (or (plist-get dl-umbriel--state :skipped) 0))

(defun dl-umbriel-window (id)
  "The held window whose opaque `id' is ID, or nil when none has it."
  (seq-find (lambda (window) (equal (alist-get 'id window) id))
            (dl-umbriel-windows)))

(defun dl-umbriel-state ()
  "The held state as a plist of :windows, :workspaces, :status, :skipped.
This is the STATE a waiter's predicate and callback receive."
  (list :windows (dl-umbriel-windows)
        :workspaces (dl-umbriel-workspaces)
        :status (dl-umbriel-stream-status)
        :skipped (dl-umbriel-skipped)))

;;;; Announcing change

(defun dl-umbriel--announce ()
  "Run the change hook, then settle the waiters against the new state.
The state has been written before this is called, so a hook entry that
reads it sees the write that just landed."
  (run-hooks 'dl-umbriel-state-changed-hook)
  (dl-umbriel--notify-waiters))

(defun dl-umbriel--set-family (family data)
  "Replace the held FAMILY snapshot with DATA, then announce the change.
FAMILY is `windows' or `workspaces'.  Stream events and refresh replies
are full snapshots, so nothing is merged; this is the only writer of the
snapshots."
  (setq dl-umbriel--state (plist-put dl-umbriel--state
                                     (intern (concat ":" (symbol-name family)))
                                     data))
  (dl-umbriel--announce))

(defun dl-umbriel--set-status (status)
  "Record STATUS as the stream status, then announce it.
The only writer of the status.  A new status starts or ends the stream,
so pending waiters are settled here rather than consulted: a failure
hands them that failure, `never' the closing one, and `open' -- the only
status a waiter may outlive -- consults their predicates."
  (setq dl-umbriel--state (plist-put dl-umbriel--state :status status))
  (run-hooks 'dl-umbriel-state-changed-hook)
  (pcase status
    ('open (dl-umbriel--notify-waiters))
    ('never (dl-umbriel--fail-waiters (list :failure 'closed "stream closed")))
    (_ (dl-umbriel--fail-waiters status))))

(defun dl-umbriel--note-skipped (&optional count)
  "Write COUNT as the number of skipped stream lines, then announce it.
COUNT nil counts one more line; `dl-umbriel-stream-open' passes 0 to
start a connection with nothing skipped.  The only writer of the counter."
  (setq dl-umbriel--state (plist-put dl-umbriel--state :skipped
                                     (or count (1+ (dl-umbriel-skipped)))))
  (dl-umbriel--announce))

;;;; Waiters

(defun dl-umbriel--quietly (function &rest args)
  "Call FUNCTION with ARGS, demoting a signal to nil.
Answers (t . VALUE) for the call's value, and nil when it signalled: a
waiter that fails must not stop the hook or the other waiters."
  (condition-case err
      (cons t (apply function args))
    (error (message "dl-umbriel: waiter signalled: %s" (error-message-string err))
           nil)))

(defun dl-umbriel--notify-waiters ()
  "Settle every pending waiter against the current state.
A waiter whose predicate holds, or signals, is dropped; one whose
predicate holds also gets CALLBACK with `(:ok STATE)'.  The list is
walked over a snapshot, and a waiter is dropped before its callback
runs, so a callback that writes state or registers a waiter can neither
make a waiter fire twice nor corrupt the walk."
  (let ((state (dl-umbriel-state)))
    (dolist (waiter (copy-sequence dl-umbriel--waiters))
      (when (memq waiter dl-umbriel--waiters)
        (let ((outcome (dl-umbriel--quietly (car waiter) state)))
          (cond ((null outcome)         ; the predicate signalled
                 (setq dl-umbriel--waiters (delq waiter dl-umbriel--waiters)))
                ((cdr outcome)
                 (setq dl-umbriel--waiters (delq waiter dl-umbriel--waiters))
                 (dl-umbriel--quietly (cdr waiter) (list :ok state)))))))))

(defun dl-umbriel--fail-waiters (failure)
  "Hand FAILURE to every pending waiter and forget them all.
The list is cleared before any callback runs, so a callback that
registers a waiter does not resurrect a dead stream's waiters."
  (let ((waiters dl-umbriel--waiters))
    (setq dl-umbriel--waiters nil)
    (dolist (waiter waiters)
      (dl-umbriel--quietly (cdr waiter) failure))))

(defun dl-umbriel--not-open-failure ()
  "The failure for a waiter registered while the stream is not open."
  (let ((status (dl-umbriel-stream-status)))
    (if (eq (car-safe status) :failure)
        status
      (list :failure 'closed "stream not open"))))

(defun dl-umbriel-await (predicate callback)
  "Call CALLBACK once, when PREDICATE holds of the held state.
PREDICATE is called with the state (`dl-umbriel-state') at registration
and after each change; when it holds, CALLBACK gets `(:ok STATE)' and
the waiter is dropped.  Registering while the stream is not open calls
CALLBACK at once with the current failure, without consulting PREDICATE:
the stream is what keeps a waiter alive, so no waiter outlives it.  A
predicate or a callback that signals drops its own waiter."
  (if (eq (dl-umbriel-stream-status) 'open)
      (progn
        (push (cons predicate callback) dl-umbriel--waiters)
        (dl-umbriel--notify-waiters))
    (dl-umbriel--quietly callback (dl-umbriel--not-open-failure))))

;;;; Stream lines

(defun dl-umbriel--stream-line (line)
  "Handle one complete LINE from the stream; never signal.
A `windows' or `workspaces' event carrying `data' replaces that family
through the one setter.  An `err' line is the compositor refusing the
subscription: answer `(:failure rejected MSG)' for the filter to record
once the connection is gone.  Anything else -- an unrequested family,
an event without `data', a reply-shaped object, or no JSON object at
all -- is counted and skipped.  No I/O here: the filter owns the process."
  (let* ((event (dl-umbriel--parse-object line))
         (family (alist-get 'event event)))
    (cond
     ((and (member family '("windows" "workspaces")) (assq 'data event))
      (dl-umbriel--set-family (intern family) (alist-get 'data event))
      nil)
     ((assq 'err event)
      (list :failure 'rejected (format "%s" (alist-get 'err event))))
     (t
      (dl-umbriel--note-skipped)
      nil))))

;;;; The stream connection

(defun dl-umbriel--forget-process ()
  "Forget the stream handle, then delete the process.
Detaching first keeps the delete's own sentinel event from being taken
for a close by the server.  Callers detach before they announce the new
status, so a hook or waiter that reconnects keeps its new connection."
  (when-let* ((process dl-umbriel--stream))
    (setq dl-umbriel--stream nil)
    (delete-process process)))

(defun dl-umbriel--subscribe (process)
  "Make PROCESS the stream and write the subscription on it.
Answer non-nil on success; on a failed write, forget PROCESS and record
the failure."
  (setq dl-umbriel--stream process)
  (condition-case err
      (progn (process-send-string
              process (concat (json-serialize dl-umbriel-subscribe-request) "\n"))
             t)
    (error (dl-umbriel--forget-process)
           (dl-umbriel--set-status (list :failure 'closed (error-message-string err)))
           nil)))

(defun dl-umbriel-stream-open ()
  "Open the one stream connection, unless the stream is already open.
The subscription is written as soon as the connection exists; the
compositor then sends a snapshot of each requested family, without an
acknowledgement.  A connect that fails leaves the status at `(:failure
KIND DETAIL)'; nothing retries on its own -- `g' reconnects."
  (unless (eq (dl-umbriel-stream-status) 'open)
    (if-let* ((path (dl-umbriel-socket-path)))
        (let ((pending "") (process nil))
          (condition-case err
              (setq process
                    (dl-umbriel--connect
                     path
                     (lambda (_process chunk)
                       (pcase-let ((`(,lines . ,rest)
                                    (dl-umbriel--take-lines pending chunk)))
                         (setq pending rest)
                         (catch 'closed
                           (dolist (line lines)
                             (when-let* ((failure (dl-umbriel--stream-line line)))
                               (dl-umbriel--forget-process)
                               (dl-umbriel--set-status failure)
                               (throw 'closed nil))))))
                     (lambda (process event)
                       (when (eq process dl-umbriel--stream)
                         (setq dl-umbriel--stream nil)
                         (dl-umbriel--set-status
                          (list :failure 'closed (string-trim event)))))))
            (file-error
             (dl-umbriel--set-status (dl-umbriel--connect-failure err path))))
          (when (and process (dl-umbriel--subscribe process))
            (dl-umbriel--note-skipped 0)
            (dl-umbriel--set-status 'open)))
      (dl-umbriel--set-status (dl-umbriel--no-path-failure)))))

(defun dl-umbriel-stream-close ()
  "Close the stream on request: status back to `never', snapshots kept.
Nothing went wrong, so this does not land in `failed'; and because a
waiter never outlives the stream, the pending ones get the closing
failure."
  (dl-umbriel--forget-process)
  (unless (eq (dl-umbriel-stream-status) 'never)
    (dl-umbriel--set-status 'never)))

;;;; Refresh

(defun dl-umbriel--refresh-families (families callback)
  "Fetch each of FAMILIES in turn, writing each reply through the setter.
CALLBACK receives the first failure, or `(:ok nil)' after the last one."
  (if (null families)
      (funcall callback (list :ok nil))
    (dl-umbriel-send
     (dl-umbriel-query (symbol-name (car families)))
     (lambda (result)
       (if (eq (car result) :failure)
           (funcall callback result)
         (dl-umbriel--set-family (car families) (cadr result))
         (dl-umbriel--refresh-families (cdr families) callback))))))

(defun dl-umbriel-refresh (&optional callback)
  "Fetch the windows and workspaces snapshots, one query after the other.
Each `(:ok DATA)' reply is written through `dl-umbriel--set-family', so
the hook sees it exactly as it sees a stream event.  The first failure
stops the pair (a family already fetched stays written) and reaches
CALLBACK, or is echoed when CALLBACK is nil.  The stream status is left
alone: only the stream speaks for the stream."
  (dl-umbriel--refresh-families '(windows workspaces)
                                (or callback #'dl-umbriel-echo-failure)))

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
