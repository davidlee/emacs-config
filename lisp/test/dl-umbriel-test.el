;;; dl-umbriel-test.el --- ert tests for the umbriel socket client -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-umbriel/ RET.
;;
;; No test reaches a real compositor: path tests bind `process-environment',
;; and transport tests fake the network with `dl-umbriel-test--with-net'.

(require 'ert)
(require 'cl-lib)
(require 'dl-umbriel)

;;;; Fake network

(cl-defstruct (dl-umbriel-test--net (:constructor dl-umbriel-test--net-create))
  "The faked network: what was opened, written and deleted.
ARGS are the latest connection's; PROCESSES maps each handle to its
args, newest first; DEAD lists the deleted handles."
  args sent (connections 0) (deleted 0) connect-error write-error
  processes dead)

(defconst dl-umbriel-test--socket "/run/test/umbriel-wayland-9.sock")

(defmacro dl-umbriel-test--with-net (net &rest body)
  "Run BODY with the network faked and the socket path resolvable.
NET is bound to a `dl-umbriel-test--net'.  Each connection gets its own
handle.  Like Emacs, the fake `delete-process' runs that connection's
sentinel synchronously with \"deleted\\n\" (once), and writing to a
deleted connection signals."
  (declare (indent 1))
  `(let ((,net (dl-umbriel-test--net-create))
         (process-environment (list (concat "UMBRIEL_SOCKET=" dl-umbriel-test--socket))))
     (cl-letf (((symbol-function 'make-network-process)
                (lambda (&rest args)
                  (when-let* ((err (dl-umbriel-test--net-connect-error ,net)))
                    (signal (car err) (cdr err)))
                  (let ((process (cons 'fake-process
                                       (cl-incf (dl-umbriel-test--net-connections ,net)))))
                    (push (cons process args) (dl-umbriel-test--net-processes ,net))
                    (setf (dl-umbriel-test--net-args ,net) args)
                    process)))
               ((symbol-function 'process-send-string)
                (lambda (process string)
                  (when (member process (dl-umbriel-test--net-dead ,net))
                    (error "Process %S not running" process))
                  (when-let* ((err (dl-umbriel-test--net-write-error ,net)))
                    (signal (car err) (cdr err)))
                  (push string (dl-umbriel-test--net-sent ,net))))
               ((symbol-function 'delete-process)
                (lambda (process)
                  (unless (member process (dl-umbriel-test--net-dead ,net))
                    (cl-incf (dl-umbriel-test--net-deleted ,net))
                    (push process (dl-umbriel-test--net-dead ,net))
                    (funcall (plist-get (alist-get process (dl-umbriel-test--net-processes ,net)
                                                   nil nil #'equal)
                                        :sentinel)
                             process "deleted\n")))))
       ,@body)))

(defun dl-umbriel-test--latest (net)
  "NET's newest connection handle."
  (car (car (dl-umbriel-test--net-processes net))))

(defun dl-umbriel-test--feed (net chunk)
  "Deliver CHUNK to the filter of NET's newest connection."
  (funcall (plist-get (dl-umbriel-test--net-args net) :filter)
           (dl-umbriel-test--latest net) chunk))

(defun dl-umbriel-test--close (net event)
  "Deliver EVENT to the sentinel of NET's newest connection."
  (funcall (plist-get (dl-umbriel-test--net-args net) :sentinel)
           (dl-umbriel-test--latest net) event))

(defmacro dl-umbriel-test--results (form)
  "Evaluate FORM with `deliver' bound to a recording callback.
Return a function answering the results recorded so far, oldest first."
  (declare (indent 0))
  `(let ((results nil))
     (let ((deliver (lambda (result) (push result results))))
       ,form)
     (lambda () (reverse results))))

;;;; Socket path

(ert-deftest dl-umbriel/socket-path-explicit-wins ()
  (let ((process-environment '("UMBRIEL_SOCKET=/s.sock" "XDG_RUNTIME_DIR=/run/u"
                               "WAYLAND_DISPLAY=wayland-1")))
    (should (equal (dl-umbriel-socket-path) "/s.sock"))))

(ert-deftest dl-umbriel/socket-path-composes-runtime-and-display ()
  (let ((process-environment '("XDG_RUNTIME_DIR=/run/u" "WAYLAND_DISPLAY=wayland-1")))
    (should (equal (dl-umbriel-socket-path) "/run/u/umbriel-wayland-1.sock"))))

(ert-deftest dl-umbriel/socket-path-empty-counts-as-unset ()
  (let ((process-environment '("UMBRIEL_SOCKET=" "XDG_RUNTIME_DIR=/run/u"
                               "WAYLAND_DISPLAY=wayland-1")))
    (should (equal (dl-umbriel-socket-path) "/run/u/umbriel-wayland-1.sock")))
  (let ((process-environment '("XDG_RUNTIME_DIR=/run/u" "WAYLAND_DISPLAY=")))
    (should-not (dl-umbriel-socket-path))))

(ert-deftest dl-umbriel/no-path-names-the-unset-variables ()
  (let ((process-environment '("XDG_RUNTIME_DIR=/run/u")))
    (cl-letf (((symbol-function 'make-network-process)
               (lambda (&rest _) (ert-fail "connected without a socket path"))))
      (let ((results (dl-umbriel-test--results
                       (dl-umbriel-send (dl-umbriel-query "windows") deliver))))
        (pcase (funcall results)
          (`((:failure no-path ,detail))
           (should (string-match-p "UMBRIEL_SOCKET" detail))
           (should (string-match-p "WAYLAND_DISPLAY" detail))
           (should-not (string-match-p "XDG_RUNTIME_DIR" detail)))
          (other (ert-fail (list 'unexpected other))))))))

;;;; Request objects

(ert-deftest dl-umbriel/query-request ()
  (should (equal (dl-umbriel-query "windows") '((cmd . "windows")))))

(ert-deftest dl-umbriel/action-drops-nil-fields ()
  (should (equal (dl-umbriel-action "window-focus" '((window . "w-1") (output)))
                 '((cmd . "action") (action . "window-focus") (window . "w-1"))))
  (should (equal (dl-umbriel-action "layout-scroll-left")
                 '((cmd . "action") (action . "layout-scroll-left")))))

(ert-deftest dl-umbriel/action-keeps-index-number-and-digit-name-string ()
  "A workspace position is a JSON number; a workspace named \"2\" is a string."
  (should (equal (json-serialize (dl-umbriel-action "workspace-switch"
                                                    '((workspace . 2) (output . "DP-1"))))
                 "{\"cmd\":\"action\",\"action\":\"workspace-switch\",\"workspace\":2,\"output\":\"DP-1\"}"))
  (should (string-match-p "\"workspace\":\"2\""
                          (json-serialize (dl-umbriel-action "workspace-switch"
                                                             '((workspace . "2")))))))

(ert-deftest dl-umbriel/subscribe-events-serialise-as-array ()
  (should (equal (json-serialize dl-umbriel-subscribe-request)
                 "{\"cmd\":\"subscribe\",\"events\":[\"windows\",\"workspaces\"]}")))

;;;; Parsing and framing

(ert-deftest dl-umbriel/parse-false-and-null-are-nil ()
  (should (equal (dl-umbriel-parse "{\"floating\":false,\"urgent\":null,\"focused\":true}")
                 '((floating) (urgent) (focused . t)))))

(ert-deftest dl-umbriel/take-lines-joins-a-line-split-across-chunks ()
  (should (equal (dl-umbriel--take-lines "{\"ok\"" ":null}\n") '(("{\"ok\":null}") . ""))))

(ert-deftest dl-umbriel/take-lines-splits-several-lines ()
  (should (equal (dl-umbriel--take-lines "" "a\nb\nc") '(("a" "b") . "c"))))

(ert-deftest dl-umbriel/take-lines-keeps-an-unterminated-remainder ()
  (should (equal (dl-umbriel--take-lines "a" "b") '(nil . "ab"))))

(ert-deftest dl-umbriel/reply-result-kinds ()
  (should (equal (dl-umbriel--reply-result "{\"ok\":null}") '(:ok nil)))
  (should (equal (dl-umbriel--reply-result "{\"ok\":[{\"id\":\"w\"}]}") '(:ok (((id . "w"))))))
  (should (equal (dl-umbriel--reply-result "{\"err\":\"no such window\"}")
                 '(:failure rejected "no such window")))
  (should (eq (cadr (dl-umbriel--reply-result "[1,2]")) 'malformed))
  (should (eq (cadr (dl-umbriel--reply-result "not json")) 'malformed)))

;;;; Transport

(ert-deftest dl-umbriel/send-writes-the-request-on-connect ()
  (dl-umbriel-test--with-net net
    (dl-umbriel-send (dl-umbriel-query "windows") #'ignore)
    (should (equal (dl-umbriel-test--net-sent net) '("{\"cmd\":\"windows\"}\n")))
    (let ((args (dl-umbriel-test--net-args net)))
      (should (eq (plist-get args :family) 'local))
      (should (equal (plist-get args :service) dl-umbriel-test--socket))
      (should (eq (plist-get args :coding) 'utf-8-unix))
      (should (eq (plist-get args :noquery) t)))))

(ert-deftest dl-umbriel/send-delivers-one-reply-once ()
  "RV-018 F-9: the synchronous sentinel run by `delete-process' delivers nothing."
  (dl-umbriel-test--with-net net
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send (dl-umbriel-query "windows") deliver))))
      (dl-umbriel-test--feed net "{\"ok\":")
      (should-not (funcall results))
      (dl-umbriel-test--feed net "[]}\n")
      (should (equal (funcall results) '((:ok nil))))
      (should (= (dl-umbriel-test--net-deleted net) 1))
      (dl-umbriel-test--close net "connection broken by remote peer\n")
      (should (equal (funcall results) '((:ok nil)))))))

(ert-deftest dl-umbriel/send-signalling-write-is-closed ()
  "RV-018 F-8: a write on a connection the server closed reports closed once."
  (dl-umbriel-test--with-net net
    (setf (dl-umbriel-test--net-write-error net) '(error "Process umbriel not running"))
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send (dl-umbriel-query "windows") deliver))))
      (pcase (funcall results)
        (`((:failure closed ,_)) t)
        (other (ert-fail (list 'unexpected other)))))))

(ert-deftest dl-umbriel/send-close-after-partial-line-is-closed ()
  "RV-018 F-8: text without a newline at close is not a reply."
  (dl-umbriel-test--with-net net
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send (dl-umbriel-query "windows") deliver))))
      (dl-umbriel-test--feed net "{\"ok\":[")
      (dl-umbriel-test--close net "connection broken by remote peer\n")
      (should (equal (funcall results)
                     '((:failure closed "connection broken by remote peer")))))))

(ert-deftest dl-umbriel/send-missing-socket-is-absent ()
  (dl-umbriel-test--with-net net
    (setf (dl-umbriel-test--net-connect-error net)
          '(file-missing "make client process failed" "No such file or directory"))
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send (dl-umbriel-query "windows") deliver))))
      (should (equal (funcall results) `((:failure absent ,dl-umbriel-test--socket)))))))

(ert-deftest dl-umbriel/send-refused-socket-is-refused ()
  (dl-umbriel-test--with-net net
    (setf (dl-umbriel-test--net-connect-error net)
          '(file-error "make client process failed" "Connection refused"))
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send (dl-umbriel-query "windows") deliver))))
      (pcase (funcall results)
        (`((:failure refused ,detail)) (should (string-match-p "Connection refused" detail)))
        (other (ert-fail (list 'unexpected other)))))))

;;;; Sequencing

(defmacro dl-umbriel-test--with-replies (replies sent &rest body)
  "Run BODY with `dl-umbriel-send' answering REPLIES in order.
SENT is bound to a function answering the requests sent so far, oldest first."
  (declare (indent 2))
  `(let ((queue ,replies) (requests nil))
     (cl-letf (((symbol-function 'dl-umbriel-send)
                (lambda (request callback)
                  (push request requests)
                  (funcall callback (pop queue)))))
       (let ((,sent (lambda () (reverse requests))))
         ,@body))))

(ert-deftest dl-umbriel/send-all-reports-the-last-success ()
  (dl-umbriel-test--with-replies '((:ok nil) (:ok 2)) sent
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send-all (list (dl-umbriel-query "a") (dl-umbriel-query "b"))
                                          deliver))))
      (should (equal (funcall results) '((:ok 2))))
      (should (= (length (funcall sent)) 2)))))

(ert-deftest dl-umbriel/send-all-stops-at-the-first-failure ()
  (dl-umbriel-test--with-replies '((:failure rejected "no") (:ok nil)) sent
    (let ((results (dl-umbriel-test--results
                     (dl-umbriel-send-all (list (dl-umbriel-query "a") (dl-umbriel-query "b"))
                                          deliver))))
      (should (equal (funcall results) '((:failure rejected "no"))))
      (should (equal (funcall sent) (list (dl-umbriel-query "a")))))))

;;;; Reporting failures

(ert-deftest dl-umbriel/failure-message-names-each-kind ()
  (dolist (kind '(no-path absent refused closed rejected malformed))
    (should (string-prefix-p (format "umbriel: %s" kind)
                             (dl-umbriel-failure-message (list :failure kind "detail"))))))

(ert-deftest dl-umbriel/echo-failure-is-silent-on-success ()
  (let (messages)
    (cl-letf (((symbol-function 'message)
               (lambda (fmt &rest args) (push (apply #'format fmt args) messages))))
      (dl-umbriel-echo-failure '(:ok nil))
      (should-not messages)
      (dl-umbriel-echo-failure '(:failure absent "/s.sock"))
      (should (equal messages (list (dl-umbriel-failure-message '(:failure absent "/s.sock"))))))))

;;;; Held state

(defmacro dl-umbriel-test--with-state (&rest body)
  "Run BODY with the client's held state fresh and isolated.
Binds the private state record, the waiter list and the stream handle
(all `defvar's in `dl-umbriel') to fresh values, and
`dl-umbriel-state-changed-hook' to nil, so a test opts in to the hook and
no test inherits an `open' stream or a leftover waiter from another."
  (declare (indent 0))
  `(let ((dl-umbriel--state nil)
         (dl-umbriel--waiters nil)
         (dl-umbriel--stream nil)
         (dl-umbriel-state-changed-hook nil))
     ,@body))

(defun dl-umbriel-test--holds-window-p (state id)
  "Non-nil when STATE holds a window whose opaque id is ID."
  (and (cl-some (lambda (window) (equal (alist-get 'id window) id))
                (plist-get state :windows))
       t))

(ert-deftest dl-umbriel/set-family-replaces-wholesale-and-is-readable ()
  "EX-1: a family is replaced, never merged, and the readers see it."
  (dl-umbriel-test--with-state
    (dl-umbriel--set-family 'windows '(((id . "w-1")) ((id . "w-2"))))
    (should (equal (dl-umbriel-windows) '(((id . "w-1")) ((id . "w-2")))))
    ;; wholesale: the earlier element is gone, not merged
    (dl-umbriel--set-family 'windows '(((id . "w-3"))))
    (should (equal (dl-umbriel-windows) '(((id . "w-3")))))
    ;; one family never disturbs another
    (dl-umbriel--set-family 'workspaces '(((id . "1"))))
    (should (equal (dl-umbriel-windows) '(((id . "w-3")))))
    (should (equal (dl-umbriel-workspaces) '(((id . "1")))))))

(ert-deftest dl-umbriel/set-family-fires-the-change-hook ()
  "The no-argument hook runs after every write, seeing the new value."
  (dl-umbriel-test--with-state
    (let ((runs 0) (last-windows nil) (last-workspaces nil))
      ;; the state is mutated before `run-hooks'; a hook that reads it sees
      ;; the snapshot that has just landed, not the previous one
      (let ((dl-umbriel-state-changed-hook
             (list (lambda ()
                     (cl-incf runs)
                     (setq last-windows (dl-umbriel-windows)
                           last-workspaces (dl-umbriel-workspaces))))))
        (dl-umbriel--set-family 'windows '(((id . "w-1"))))
        (should (= runs 1))
        (should (equal last-windows '(((id . "w-1")))))
        (should-not last-workspaces)
        (dl-umbriel--set-family 'workspaces '(((id . "1"))))
        (should (= runs 2))
        (should (equal last-workspaces '(((id . "1")))))
        (should (equal last-windows '(((id . "w-1")))))))))

(ert-deftest dl-umbriel/state-is-a-plist-of-four-parts ()
  "`dl-umbriel-state' is the plist waiters receive: all four parts, no more."
  (dl-umbriel-test--with-state
    (dl-umbriel--set-family 'windows '(((id . "w-1"))))
    (dl-umbriel--set-family 'workspaces '(((id . "1"))))
    (let ((state (dl-umbriel-state)))
      (should (equal (plist-get state :windows) '(((id . "w-1")))))
      (should (equal (plist-get state :workspaces) '(((id . "1")))))
      (should (eq (plist-get state :status) 'never))
      (should (= (plist-get state :skipped) 0))
      (should (equal (sort (cl-loop for (key _value) on state by #'cddr
                                    collect key)
                           (lambda (a b) (string< (symbol-name a) (symbol-name b))))
                     '(:skipped :status :windows :workspaces))))))

(ert-deftest dl-umbriel/window-lookup-by-id-and-unknown-id ()
  "A window's opaque `id' is its key; an absent id reads as nil."
  (dl-umbriel-test--with-state
    (should-not (dl-umbriel-window "w-1"))
    (dl-umbriel--set-family 'windows '(((id . "w-1") (title . "shell"))
                                       ((id . "w-2") (title . "editor"))))
    (should (equal (dl-umbriel-window "w-2") '((id . "w-2") (title . "editor"))))
    (should-not (dl-umbriel-window "w-9"))
    ;; replacement, not accumulation: an id dropped by a new snapshot is gone
    (dl-umbriel--set-family 'windows '(((id . "w-2") (title . "editor"))))
    (should-not (dl-umbriel-window "w-1"))))

;;;; Stream lines

(ert-deftest dl-umbriel/stream-line-windows-replace-held-state-and-run-hook ()
  "A windows event is a full snapshot: set through the one setter, hook run."
  (dl-umbriel-test--with-state
    (dl-umbriel--set-family 'windows '(((id . "old"))))
    (let ((runs 0) (seen nil))
      (let ((dl-umbriel-state-changed-hook
             (list (lambda () (cl-incf runs) (push (dl-umbriel-windows) seen)))))
        (dl-umbriel--stream-line
         "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\",\"title\":\"a\"}]}")
        (should (equal (dl-umbriel-windows) '(((id . "w-1") (title . "a")))))
        (should (= runs 1))
        ;; the hook saw the new snapshot, once
        (should (equal (car seen) '(((id . "w-1") (title . "a")))))
        (should (= (length seen) 1))
        (should-not (dl-umbriel-workspaces))
        (should (= (dl-umbriel-skipped) 0))
        (should (eq (dl-umbriel-stream-status) 'never))))))

(ert-deftest dl-umbriel/stream-line-workspaces-replace-held-state ()
  (dl-umbriel-test--with-state
    (dl-umbriel--set-family 'workspaces '(((id . "old"))))
    (dl-umbriel--stream-line
     "{\"event\":\"workspaces\",\"data\":[{\"id\":\"1\",\"name\":\"one\"}]}")
    (should (equal (dl-umbriel-workspaces) '(((id . "1") (name . "one")))))
    (should-not (dl-umbriel-windows))
    (should (= (dl-umbriel-skipped) 0))))

(ert-deftest dl-umbriel/stream-line-unrequested-family-bumps-skipped ()
  "A family we did not subscribe to is counted, never fatal (VT-1)."
  (dl-umbriel-test--with-state
    (let ((runs 0))
      (let ((dl-umbriel-state-changed-hook (list (lambda () (cl-incf runs)))))
        (dl-umbriel--stream-line "{\"event\":\"theme\",\"data\":{\"name\":\"dark\"}}")
        (should (= (dl-umbriel-skipped) 1))
        ;; the skipped count is a write: the hook runs for it too
        (should (= runs 1))
        (should-not (dl-umbriel-windows))
        (should-not (dl-umbriel-workspaces))
        (should (eq (dl-umbriel-stream-status) 'never))))))

(ert-deftest dl-umbriel/stream-line-malformed-bumps-skipped-without-error ()
  "A line that is not what we expect is counted and skipped; a signal would
fail this test, and C-4 puts a reply-shaped object in the same bucket."
  (dl-umbriel-test--with-state
    (dl-umbriel--stream-line "not json at all")
    (should (= (dl-umbriel-skipped) 1))
    (dl-umbriel--stream-line "[1,2]")
    (should (= (dl-umbriel-skipped) 2))
    (dl-umbriel--stream-line "{\"ok\":null}")
    (should (= (dl-umbriel-skipped) 3))
    (should (eq (dl-umbriel-stream-status) 'never))
    (should-not (dl-umbriel-windows))))

(ert-deftest dl-umbriel/stream-line-err-line-is-rejected ()
  "C-1: the err line sets `rejected' *before* closing, so the close's own
sentinel cannot overwrite it with `closed'."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--feed net "{\"err\":\"unknown subscription event: theme\"}\n")
      (should (equal (dl-umbriel-stream-status)
                     '(:failure rejected "unknown subscription event: theme")))
      (should (>= (dl-umbriel-test--net-deleted net) 1))
      ;; the fake sentinel ran with "deleted\n" during that delete
      (should (eq (car (dl-umbriel-stream-status)) :failure))
      (should (eq (cadr (dl-umbriel-stream-status)) 'rejected)))))

;;;; Stream lifecycle

(ert-deftest dl-umbriel/stream-status-is-never-before-open ()
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (should (eq (dl-umbriel-stream-status) 'never))
      (should (= (dl-umbriel-test--net-connections net) 0)))))

(ert-deftest dl-umbriel/stream-open-subscribes-once-and-is-open ()
  "The one subscription is written on the one connection, then snapshots flow."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (should (eq (dl-umbriel-stream-status) 'open))
      (should (= (dl-umbriel-test--net-connections net) 1))
      (should (equal (dl-umbriel-test--net-sent net)
                     '("{\"cmd\":\"subscribe\",\"events\":[\"windows\",\"workspaces\"]}\n")))
      (let ((args (dl-umbriel-test--net-args net)))
        (should (eq (plist-get args :family) 'local))
        (should (equal (plist-get args :service) dl-umbriel-test--socket))
        (should (eq (plist-get args :coding) 'utf-8-unix))
        (should (eq (plist-get args :noquery) t)))
      ;; no {"ok"} ack: the first lines are the snapshots themselves
      (dl-umbriel-test--feed net "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\"}]}\n")
      (should (equal (dl-umbriel-windows) '(((id . "w-1")))))
      (should (eq (dl-umbriel-stream-status) 'open)))))

(ert-deftest dl-umbriel/stream-open-twice-makes-one-connection ()
  "RV-019 F-2: opening an open stream is a no-op, not a second subscriber."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-stream-open)
      (should (= (dl-umbriel-test--net-connections net) 1))
      (should (= (length (dl-umbriel-test--net-sent net)) 1))
      (should (eq (dl-umbriel-stream-status) 'open)))))

(ert-deftest dl-umbriel/stream-sentinel-closes-and-keeps-snapshots ()
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--feed net "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\"}]}\n")
      (dl-umbriel-test--close net "connection broken by remote peer\n")
      (should (equal (dl-umbriel-stream-status)
                     '(:failure closed "connection broken by remote peer")))
      ;; the buffer still shows them, under a header that says why they are stale
      (should (equal (dl-umbriel-windows) '(((id . "w-1"))))))))

(ert-deftest dl-umbriel/stream-close-returns-to-never ()
  "Nothing went wrong, so the close lands in `never', not in `failed'."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--feed net "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\"}]}\n")
      (dl-umbriel-stream-close)
      (should (= (dl-umbriel-test--net-deleted net) 1))
      ;; the fake `delete-process' has already run the sentinel with "deleted\n"
      (should (eq (dl-umbriel-stream-status) 'never))
      (should (equal (dl-umbriel-windows) '(((id . "w-1"))))))))

(ert-deftest dl-umbriel/stream-close-after-a-failure-returns-to-never ()
  "Design: failed --> never on stream-close, though no process is left."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--close net "connection broken by remote peer\n")
      (dl-umbriel-stream-close)
      (should (eq (dl-umbriel-stream-status) 'never))
      (should (= (dl-umbriel-test--net-connections net) 1)))))

(defun dl-umbriel-test--reconnect-on-failure ()
  "Register a waiter whose failure callback reopens the stream, as `g' would."
  (dl-umbriel-await #'ignore (lambda (_result) (dl-umbriel-stream-open))))

(ert-deftest dl-umbriel/stream-close-detaches-before-announcing ()
  "A reconnect from inside the close's announcement keeps its connection."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--reconnect-on-failure)
      (dl-umbriel-stream-close)
      (should (eq (dl-umbriel-stream-status) 'open))
      (should (equal dl-umbriel--stream (dl-umbriel-test--latest net)))
      (should-not (member dl-umbriel--stream (dl-umbriel-test--net-dead net))))))

(ert-deftest dl-umbriel/stream-rejected-detaches-before-announcing ()
  "A reconnect from inside the rejection's announcement keeps its connection."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--reconnect-on-failure)
      (dl-umbriel-test--feed net "{\"err\":\"no\"}\n")
      (should (eq (dl-umbriel-stream-status) 'open))
      (should (= (dl-umbriel-test--net-connections net) 2))
      (should (equal dl-umbriel--stream (dl-umbriel-test--latest net)))
      (should-not (member dl-umbriel--stream (dl-umbriel-test--net-dead net))))))

(ert-deftest dl-umbriel/stream-open-subscribes-before-announcing ()
  "A close from inside the open's announcement wins: the stream is `never'."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (let ((dl-umbriel-state-changed-hook
             (list (lambda ()
                     (when (eq (dl-umbriel-stream-status) 'open)
                       (dl-umbriel-stream-close))))))
        (dl-umbriel-stream-open)
        (should (eq (dl-umbriel-stream-status) 'never))
        (should (= (length (dl-umbriel-test--net-sent net)) 1))
        (should-not dl-umbriel--stream)))))

(ert-deftest dl-umbriel/stream-line-event-without-data-is-skipped ()
  "Design: a format change is counted, not silently taken as an empty desktop."
  (dl-umbriel-test--with-state
    (dl-umbriel--set-family 'windows '(((id . "w-1"))))
    (dl-umbriel--stream-line "{\"event\":\"windows\",\"payload\":[]}")
    (should (= (dl-umbriel-skipped) 1))
    (should (equal (dl-umbriel-windows) '(((id . "w-1")))))))

(ert-deftest dl-umbriel/stream-open-resets-skipped ()
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--feed net "{\"event\":\"theme\",\"data\":{}}\n")
      (dl-umbriel-test--feed net "nonsense\n")
      (should (= (dl-umbriel-skipped) 2))
      (dl-umbriel-stream-close)
      (dl-umbriel-stream-open)
      (should (= (dl-umbriel-skipped) 0))
      (should (eq (dl-umbriel-stream-status) 'open)))))

(ert-deftest dl-umbriel/stream-open-failure-reports-absent-without-a-socket ()
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (setf (dl-umbriel-test--net-connect-error net)
            '(file-missing "make client process failed" "No such file or directory"))
      (dl-umbriel-stream-open)
      (should (equal (dl-umbriel-stream-status)
                     `(:failure absent ,dl-umbriel-test--socket)))
      ;; nothing was sent: there was no connection to send on
      (should-not (dl-umbriel-test--net-sent net)))))

(ert-deftest dl-umbriel/no-auto-reconnect-after-a-serverside-close ()
  "RV-019 F-2 / DEC-018: nothing reconnects by itself; `g' is the reconnect."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--close net "connection broken by remote peer\n")
      (should (equal (dl-umbriel-stream-status)
                     '(:failure closed "connection broken by remote peer")))
      (should (= (dl-umbriel-test--net-connections net) 1))
      (should (= (length (dl-umbriel-test--net-sent net)) 1))
      ;; a later change does not sneak a subscription in either
      (dl-umbriel--set-family 'windows '(((id . "w-1"))))
      (should (= (dl-umbriel-test--net-connections net) 1)))))

;;;; Waiters

(ert-deftest dl-umbriel/await-fires-at-registration-when-the-predicate-holds ()
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel--set-family 'windows '(((id . "w-1"))))
      (let ((results (dl-umbriel-test--results
                       (dl-umbriel-await (lambda (state)
                                           (dl-umbriel-test--holds-window-p state "w-1"))
                                         deliver))))
        (pcase (funcall results)
          (`((:ok ,state))
           (should (equal (plist-get state :windows) '(((id . "w-1"))))))
          (other (ert-fail (list 'unexpected other))))))))

(ert-deftest dl-umbriel/await-fires-once-on-the-change-that-makes-it-hold ()
  "One-shot: the waiter is dropped when it fires, a later change adds nothing."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (let ((results (dl-umbriel-test--results
                       (dl-umbriel-await (lambda (state)
                                           (dl-umbriel-test--holds-window-p state "w-1"))
                                         deliver))))
        (should-not (funcall results))
        (dl-umbriel-test--feed net "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\"}]}\n")
        (pcase (funcall results)
          (`((:ok ,state))
           (should (equal (plist-get state :windows) '(((id . "w-1"))))))
          (other (ert-fail (list 'unexpected other))))
        (dl-umbriel-test--feed net (concat "{\"event\":\"windows\",\"data\":"
                                           "[{\"id\":\"w-1\"},{\"id\":\"w-2\"}]}\n"))
        (should (= (length (funcall results)) 1))))))

(ert-deftest dl-umbriel/await-fails-when-the-stream-closes ()
  "No waiter outlives the stream, and it fires only the once."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (let ((results (dl-umbriel-test--results
                       (dl-umbriel-await (lambda (state)
                                           (dl-umbriel-test--holds-window-p state "w-1"))
                                         deliver))))
        (should-not (funcall results))
        (dl-umbriel-test--close net "connection broken by remote peer\n")
        (pcase (funcall results)
          (`((:failure closed ,_)) t)
          (other (ert-fail (list 'unexpected other))))
        (dl-umbriel--set-family 'windows '(((id . "w-1"))))
        (should (= (length (funcall results)) 1))))))

(ert-deftest dl-umbriel/await-fails-at-once-when-the-stream-is-not-open ()
  "C-3: registering while not open fails at once, without running the
predicate; a failed stream hands over the failure it already has."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (let ((predicate-called nil))
        (let ((results (dl-umbriel-test--results
                         (dl-umbriel-await (lambda (_state) (setq predicate-called t))
                                           deliver))))
          (should-not predicate-called)
          (pcase (funcall results)
            (`((:failure closed ,detail)) (should (string-match-p "not open" detail)))
            (other (ert-fail (list 'unexpected other))))))))
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel-test--close net "connection broken by remote peer\n")
      (let ((results (dl-umbriel-test--results
                       (dl-umbriel-await (lambda (_state) t) deliver))))
        (pcase (funcall results)
          (`((:failure closed "connection broken by remote peer")) t)
          (other (ert-fail (list 'unexpected other))))))))

(ert-deftest dl-umbriel/waiter-signalling-predicate-drops-only-its-own-waiter ()
  "A predicate that signals drops its own waiter, at registration and on a
later change; the hook and the other waiter are untouched."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (let ((at-registration 0) (on-change 0) (fired nil) (runs 0))
        (let ((dl-umbriel-state-changed-hook (list (lambda () (cl-incf runs)))))
          ;; signals while it is evaluated at registration
          (dl-umbriel-await (lambda (_state)
                              (cl-incf at-registration)
                              (error "predicate boom"))
                            #'ignore)
          ;; nil for now, signals on the change that gives it a window: this is
          ;; the notify path, not the registration path
          (dl-umbriel-await (lambda (state)
                              (when (plist-get state :windows)
                                (cl-incf on-change)
                                (error "late predicate boom")))
                            #'ignore)
          ;; a well-behaved waiter on that same change
          (dl-umbriel-await (lambda (state)
                              (dl-umbriel-test--holds-window-p state "w-1"))
                            (lambda (result) (push result fired)))
          (should (= at-registration 1))
          (should (= on-change 0))
          (dl-umbriel-test--feed net "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\"}]}\n")
          (should (= at-registration 1)) ; dropped at registration
          (should (= on-change 1))       ; consulted, signalled, dropped
          (should (pcase fired (`((:ok ,_)) t) (_ nil)))
          (should (= runs 1))
          ;; dropped, so the next change must not consult it again (and nothing
          ;; may signal out of the filter)
          (dl-umbriel-test--feed net (concat "{\"event\":\"windows\",\"data\":"
                                             "[{\"id\":\"w-1\"},{\"id\":\"w-2\"}]}\n"))
          (should (= on-change 1))
          (should (= runs 2)))))))

(ert-deftest dl-umbriel/waiter-signalling-callback-drops-only-its-own-waiter ()
  "A callback that signals drops its own waiter *before* being called -- at
registration and on a later change -- so it cannot fire twice and cannot
stop the hook or a waiter that becomes true on the same change."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (dl-umbriel--set-family 'windows '(((id . "w-1"))))
      (let ((bad-calls 0) (late-calls 0) (other-calls 0) (runs 0))
        ;; this one's predicate already holds: it fires during registration,
        ;; writes once more from inside the callback, then signals
        (dl-umbriel-await (lambda (state) (dl-umbriel-test--holds-window-p state "w-1"))
                          (lambda (_result)
                            (cl-incf bad-calls)
                            (when (= bad-calls 1)
                              (dl-umbriel--set-family 'windows '(((id . "w-1")))))
                            (error "callback boom")))
        ;; these two only become true on a later change and signal from their
        ;; callback there; the well-behaved one sits between them, so a
        ;; signalling callback comes before it in one notification order and
        ;; after it in the other
        (dl-umbriel-await (lambda (state) (dl-umbriel-test--holds-window-p state "w-3"))
                          (lambda (_result) (cl-incf late-calls) (error "late boom")))
        (dl-umbriel-await (lambda (state) (dl-umbriel-test--holds-window-p state "w-2"))
                          (lambda (_result) (cl-incf other-calls)))
        (dl-umbriel-await (lambda (state) (dl-umbriel-test--holds-window-p state "w-4"))
                          (lambda (_result) (cl-incf late-calls) (error "late boom")))
        ;; dropped before the call: the write it made did not fire it again
        (should (= bad-calls 1))
        (should (= late-calls 0))
        (should (= other-calls 0))
        (let ((dl-umbriel-state-changed-hook (list (lambda () (cl-incf runs)))))
          (dl-umbriel-test--feed net (concat "{\"event\":\"windows\",\"data\":"
                                             "[{\"id\":\"w-1\"},{\"id\":\"w-2\"},"
                                             "{\"id\":\"w-3\"},{\"id\":\"w-4\"}]}\n"))
          (should (= bad-calls 1))   ; gone for good
          (should (= late-calls 2))  ; both signalling callbacks ran, once each
          (should (= other-calls 1)) ; neither of them stopped this one
          (should (= runs 1))        ; nor the hook
          ;; a further change does not reach any of the dropped callbacks
          (dl-umbriel-test--feed net (concat "{\"event\":\"windows\",\"data\":"
                                             "[{\"id\":\"w-1\"},{\"id\":\"w-2\"},"
                                             "{\"id\":\"w-3\"},{\"id\":\"w-4\"}]}\n"))
          (should (= bad-calls 1))
          (should (= late-calls 2))
          (should (= other-calls 1))
          (should (= runs 2)))))))

(ert-deftest dl-umbriel/waiters-run-after-the-hook ()
  "The buffer repaints from the hook before any waiter's callback runs."
  (dl-umbriel-test--with-state
    (dl-umbriel-test--with-net net
      (dl-umbriel-stream-open)
      (let ((order nil))
        (let ((dl-umbriel-state-changed-hook (list (lambda () (push 'hook order)))))
          (dl-umbriel-await (lambda (state)
                              (dl-umbriel-test--holds-window-p state "w-1"))
                            (lambda (_result) (push 'waiter order)))
          (dl-umbriel-test--feed net "{\"event\":\"windows\",\"data\":[{\"id\":\"w-1\"}]}\n")
          (should (equal (reverse order) '(hook waiter))))))))

;;;; Refresh

(ert-deftest dl-umbriel/refresh-writes-both-families-through-the-setter ()
  "VT-4: two queries, both `(:ok DATA)' replies routed through the setter."
  (dl-umbriel-test--with-state
    (let ((runs 0))
      (let ((dl-umbriel-state-changed-hook (list (lambda () (cl-incf runs)))))
        (dl-umbriel-test--with-replies '((:ok (((id . "w-1") (title . "a"))))
                                         (:ok (((id . "1") (name . "one")))))
          sent
          (let ((results (dl-umbriel-test--results (dl-umbriel-refresh deliver))))
            (should (equal (funcall sent) (list (dl-umbriel-query "windows")
                                                (dl-umbriel-query "workspaces"))))
            (should (equal (dl-umbriel-windows) '(((id . "w-1") (title . "a")))))
            (should (equal (dl-umbriel-workspaces) '(((id . "1") (name . "one")))))
            (should (= runs 2))
            ;; refresh never speaks for the stream
            (should (eq (dl-umbriel-stream-status) 'never))
            (pcase (funcall results)
              (`((:ok ,_)) t)
              (other (ert-fail (list 'unexpected other))))))))))

(ert-deftest dl-umbriel/refresh-reports-the-first-failure-without-touching-state ()
  "A failure leaves the held snapshots alone and stops the pair of queries."
  (dl-umbriel-test--with-state
    (dl-umbriel--set-family 'windows '(((id . "old"))))
    (let ((runs 0))
      (let ((dl-umbriel-state-changed-hook (list (lambda () (cl-incf runs)))))
        (dl-umbriel-test--with-replies '((:failure rejected "no")
                                         (:ok (((id . "1") (name . "one")))))
          sent
          (let ((results (dl-umbriel-test--results (dl-umbriel-refresh deliver))))
            (should (equal (funcall results) '((:failure rejected "no"))))
            (should (equal (dl-umbriel-windows) '(((id . "old")))))
            (should-not (dl-umbriel-workspaces))
            (should (= runs 0))
            (should (equal (funcall sent) (list (dl-umbriel-query "windows"))))))))))

(provide 'dl-umbriel-test)
;;; dl-umbriel-test.el ends here
