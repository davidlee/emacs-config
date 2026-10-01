;;; dl-zmx-test.el --- ert tests for zmx sessions -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-zmx RET.

(require 'ert)
(require 'dl-zmx)

(ert-deftest dl-zmx/session-name-joins-project-and-identifier ()
  (should (equal (dl-zmx-session-name "hris" "claude") "hris-claude")))

(ert-deftest dl-zmx/session-name-drops-leading-dots ()
  "Hidden project dirs (`.emacs.d') give readable session names."
  (should (equal (dl-zmx-session-name ".emacs.d" "pi") "emacs.d-pi")))

(ert-deftest dl-zmx/session-name-replaces-label-unsafe-chars ()
  "zmx labels allow only [a-zA-Z0-9._-]; names and labels must agree."
  (should (equal (dl-zmx-session-name "my proj" "a/b") "my-proj-a-b")))

(defmacro dl-zmx-test--with-commands (&rest body)
  "Run BODY with a fixed launcher, zmx command and shell."
  `(let ((dl-zmx-launcher '("systemd-run" "--user" "--scope"))
         (dl-zmx-command "zmx")
         (dl-zmx-shell "nu"))
     ,@body))

(ert-deftest dl-zmx/attach-argv-labels-new-sessions ()
  "New sessions get their own systemd scope, outside Emacs's cgroup."
  (dl-zmx-test--with-commands
   (should (equal (dl-zmx-attach-argv "emacs.d-re-view"
                                      (dl-zmx-labels ".emacs.d" "re view"))
                  '("systemd-run" "--user" "--scope"
                    "zmx" "attach" "--labels" "project=emacs.d id=re-view"
                    "emacs.d-re-view" "nu")))))

(ert-deftest dl-zmx/attach-argv-reattach-without-labels ()
  (dl-zmx-test--with-commands
   (should (equal (dl-zmx-attach-argv "dev")
                  '("systemd-run" "--user" "--scope" "zmx" "attach" "dev" "nu")))))

(ert-deftest dl-zmx/buffer-name-is-term-prefixed ()
  (should (equal (dl-zmx-buffer-name "hris-claude") "term-hris-claude")))

(ert-deftest dl-zmx/parse-sessions-skips-ended ()
  "`zmx list' keeps exited sessions around, marked with `ended='."
  (should
   (equal
    (mapcar (lambda (session) (alist-get 'name session))
            (dl-zmx--parse-sessions
             (concat
              "  name=ls\tpid=1\tclients=0\tcreated=1\tcwd=file://h/x\n"
              "  name=sh\tpid=2\tclients=0\tcwd=file://h/x\tended=1\texit_code=0\n"
              "  name=hris-claude\tpid=3\tclients=1\tcwd=file://h/y\n")))
    '("ls" "hris-claude"))))

(ert-deftest dl-zmx/parse-sessions-keeps-labels ()
  "Labels are listed as ordinary fields after the built-in ones."
  (should (equal (dl-zmx--parse-sessions
                  "  name=a\tclients=1\tcwd=file://h/srv/x\tid=b\tproject=foo\n")
                 '(((name . "a") (clients . "1") (cwd . "file://h/srv/x")
                    (id . "b") (project . "foo"))))))

(ert-deftest dl-zmx/parse-sessions-empty-output ()
  (should (null (dl-zmx--parse-sessions ""))))

(ert-deftest dl-zmx/sessions-ignore-stderr ()
  "With no sessions, `zmx list' explains itself on stderr."
  (let ((dl-zmx-command (make-temp-file "zmx-stub")))
    (unwind-protect
        (progn
          (with-temp-file dl-zmx-command
            (insert "#!/bin/sh\necho 'no sessions found in /run/zmx' >&2\n"))
          (set-file-modes dl-zmx-command #o700)
          (should (null (dl-zmx-sessions))))
      (delete-file dl-zmx-command))))

(ert-deftest dl-zmx/session-dir-from-cwd-url ()
  (should (equal (dl-zmx--session-dir '((cwd . "file://h/srv/my%20dir")))
                 "/srv/my dir/"))
  (should (null (dl-zmx--session-dir '((name . "a"))))))

(ert-deftest dl-zmx/annotation-shows-project-clients-dir ()
  (should (equal (dl-zmx--annotation
                  '((name . "a") (clients . "1") (cwd . "file://h/srv/x")
                    (project . "foo")))
                 "  foo  1 attached  /srv/x/"))
  (should (equal (dl-zmx--annotation '((name . "a") (clients . "0")))
                 "  0 attached")))

(ert-deftest dl-zmx/project-identifiers-from-sessions ()
  "Only this project's sessions, by identifier."
  (should (equal (dl-zmx-project-identifiers
                  ".emacs.d" '("emacs.d-claude" "hris-pi" "emacs.d-build" "ls"))
                 '("claude" "build"))))

(ert-deftest dl-zmx/ghostel-exec-callable-before-ghostel-loads ()
  "ghostel is lazy-loaded and doesn't autoload `ghostel-exec' itself."
  (should (fboundp 'ghostel-exec)))

(ert-deftest dl-zmx/offered-on-project-switch ()
  "`project-switch-project' menu offers zmx on `z'."
  (should (equal (assq 'my/zmx-project project-switch-commands)
                 '(my/zmx-project "zmx" "z"))))

(provide 'dl-zmx-test)
;;; dl-zmx-test.el ends here
