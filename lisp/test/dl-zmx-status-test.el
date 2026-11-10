;;; dl-zmx-status-test.el --- ert tests for zmx states in the mode line -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-zmx-status RET.

(require 'ert)
(require 'cl-lib)
(require 'dl-zmx-status)
(require 'dl-zmx-test)                  ; `dl-zmx-test--with-zmx'

;; On the path before `dl-zmx-status' wraps it; absent outside a provisioned config.
(let ((ghostel-dir (expand-file-name "elpa/ghostel/lisp" user-emacs-directory)))
  (when (file-directory-p ghostel-dir)
    (add-to-list 'load-path ghostel-dir)
    (require 'ghostel)))

;; ghostel joins the load path only at load time, so the compiler cannot see it.
(declare-function ghostel-status--indicator-text "ghostel-status")
(declare-function ghostel-status-buffers "ghostel-status")
(defvar ghostel-program-status)

(defun dl-zmx-status-test--session (name state)
  "Return a session record NAME, with a `state' label of STATE unless nil."
  `((name . ,name) ,@(and state `((state . ,state)))))

(ert-deftest dl-zmx-status/text-counts-sessions-most-urgent-first ()
  (should (equal (substring-no-properties
                  (dl-zmx-status-text
                   (list (dl-zmx-status-test--session "a.1" "working")
                         (dl-zmx-status-test--session "a.2" "blocked")
                         (dl-zmx-status-test--session "a.3" "blocked")
                         (dl-zmx-status-test--session "a.4" nil))))
                 "🔔×2 ◐×1")))

(ert-deftest dl-zmx-status/text-is-nil-without-states ()
  "A session no harness labels says nothing, so neither does the mode line."
  (should-not (dl-zmx-status-text (list (dl-zmx-status-test--session "a.1" nil))))
  (should-not (dl-zmx-status-text nil)))

(ert-deftest dl-zmx-status/text-carries-the-picker-faces ()
  (should (eq (get-text-property
               0 'face (dl-zmx-status-text
                        (list (dl-zmx-status-test--session "a.1" "blocked"))))
              'warning)))

(defun dl-zmx-status-test--wait ()
  "Wait for the running poll's sentinel, which kills the poll's buffer."
  (let ((deadline (+ (float-time) 5)))
    (while (and (buffer-live-p (process-buffer dl-zmx-status--process))
                (< (float-time) deadline))
      (accept-process-output nil 0.05))))

(defmacro dl-zmx-status-test--polling (script &rest body)
  "Run BODY after one poll of a stub zmx running SCRIPT, with fresh state."
  (declare (indent 1))
  `(let ((dl-zmx-status--text nil)
         (dl-zmx-status--process nil))
     (dl-zmx-test--with-zmx
      (progn (dl-zmx-status--poll)
             (dl-zmx-status-test--wait)
             ,@body)
      ,script)))

(ert-deftest dl-zmx-status/poll-shows-what-zmx-lists ()
  (dl-zmx-status-test--polling
      "printf 'name=a.1\\tstate=blocked\\nname=a.2\\tstate=working\\n'\n"
    (should (equal (substring-no-properties dl-zmx-status--text) "🔔×1 ◐×1"))))

(ert-deftest dl-zmx-status/poll-ignores-stderr ()
  "With no sessions, zmx says so on stderr and fails: nothing to show."
  (dl-zmx-status-test--polling
      "echo 'no sessions found in /run/zmx' >&2\nexit 1\n"
    (should-not dl-zmx-status--text)))

(ert-deftest dl-zmx-status/poll-leaves-no-buffers ()
  (dl-zmx-status-test--polling "exit 0\n"
    (should-not (seq-filter (lambda (buffer)
                              (string-prefix-p " *zmx-status" (buffer-name buffer)))
                            (buffer-list)))))

(ert-deftest dl-zmx-status/poll-waits-for-the-last ()
  "A slow zmx gets one poll at a time, not one per tick."
  (let ((dl-zmx-status--process nil))
    (dl-zmx-test--with-zmx
     (progn (dl-zmx-status--poll)
            (let ((first dl-zmx-status--process))
              (dl-zmx-status--poll)
              (should (eq dl-zmx-status--process first))
              (delete-process first)
              (dl-zmx-status-test--wait)))
     "sleep 2\n")))

(ert-deftest dl-zmx-status/segment-shows-in-the-active-window-only ()
  (let ((dl-zmx-status--text "🔔1"))
    (cl-letf (((symbol-function 'dl-modeline-window-active-p) (lambda () t)))
      (should (equal (dl-zmx-status--segment) " 🔔1")))
    (cl-letf (((symbol-function 'dl-modeline-window-active-p) (lambda () nil)))
      (should-not (dl-zmx-status--segment)))))

(defmacro dl-zmx-status-test--with-terminals (&rest body)
  "Run BODY with a blocked zmx terminal and a blocked plain one."
  (declare (indent 0))
  `(let ((zmx-terminal (get-buffer-create (dl-zmx-buffer-name "a.1")))
         (plain-terminal (get-buffer-create "*ghostel*")))
     (unwind-protect
         (progn
           (dolist (buffer (list zmx-terminal plain-terminal))
             (with-current-buffer buffer
               (ghostel-mode)
               (setq ghostel-program-status `(("" :state blocked)))))
           ,@body)
       (kill-buffer zmx-terminal)
       (kill-buffer plain-terminal))))

(ert-deftest dl-zmx-status/ghostel-indicator-leaves-out-zmx-terminals ()
  "Their state is counted from zmx, so ghostel's indicator would count it twice."
  (skip-unless (featurep 'ghostel))
  (dl-zmx-status-test--with-terminals
    (let ((dl-zmx-status-mode nil))
      (should (equal (substring-no-properties (ghostel-status--indicator-text))
                     " ✋2")))
    (unwind-protect
        (progn
          (cl-letf (((symbol-function 'dl-zmx-status--poll) #'ignore))
            (dl-zmx-status-mode 1))
          (should (equal (substring-no-properties (ghostel-status--indicator-text))
                         " ✋"))
          (should (equal (ghostel-status-buffers) (list plain-terminal zmx-terminal))))
      (dl-zmx-status-mode -1))))

(ert-deftest dl-zmx-status/mode-off-stops-and-clears ()
  (cl-letf (((symbol-function 'dl-zmx-status--poll) #'ignore))
    (dl-zmx-status-mode 1)
    (should (memq #'dl-zmx-status--segment dl-modeline-segments))
    (setq dl-zmx-status--text "🔔1")
    (dl-zmx-status-mode -1)
    (should-not (memq #'dl-zmx-status--segment dl-modeline-segments))
    (should-not dl-zmx-status--text)
    (should-not dl-zmx-status--timer)))

(provide 'dl-zmx-status-test)
;;; dl-zmx-status-test.el ends here
