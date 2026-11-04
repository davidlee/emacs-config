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
  "One faked connection: what was opened, written and deleted."
  args sent (connections 0) (deleted 0) connect-error write-error)

(defconst dl-umbriel-test--socket "/run/test/umbriel-wayland-9.sock")

(defmacro dl-umbriel-test--with-net (net &rest body)
  "Run BODY with the network faked and the socket path resolvable.
NET is bound to a `dl-umbriel-test--net'.  Like Emacs, the fake
`delete-process' runs the sentinel synchronously with \"deleted\\n\"."
  (declare (indent 1))
  `(let ((,net (dl-umbriel-test--net-create))
         (process-environment (list (concat "UMBRIEL_SOCKET=" dl-umbriel-test--socket))))
     (cl-letf (((symbol-function 'make-network-process)
                (lambda (&rest args)
                  (when-let* ((err (dl-umbriel-test--net-connect-error ,net)))
                    (signal (car err) (cdr err)))
                  (cl-incf (dl-umbriel-test--net-connections ,net))
                  (setf (dl-umbriel-test--net-args ,net) args)
                  'fake-process))
               ((symbol-function 'process-send-string)
                (lambda (_process string)
                  (when-let* ((err (dl-umbriel-test--net-write-error ,net)))
                    (signal (car err) (cdr err)))
                  (push string (dl-umbriel-test--net-sent ,net))))
               ((symbol-function 'delete-process)
                (lambda (_process)
                  (cl-incf (dl-umbriel-test--net-deleted ,net))
                  (dl-umbriel-test--close ,net "deleted\n"))))
       ,@body)))

(defun dl-umbriel-test--feed (net chunk)
  "Deliver CHUNK to NET's process filter."
  (funcall (plist-get (dl-umbriel-test--net-args net) :filter) 'fake-process chunk))

(defun dl-umbriel-test--close (net event)
  "Deliver EVENT to NET's process sentinel."
  (funcall (plist-get (dl-umbriel-test--net-args net) :sentinel) 'fake-process event))

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

(provide 'dl-umbriel-test)
;;; dl-umbriel-test.el ends here
