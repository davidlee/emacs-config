;;; dl-zmx-test.el --- ert tests for zmx sessions -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-zmx RET.

(require 'ert)
(require 'cl-lib)
(require 'dl-zmx)

(ert-deftest dl-zmx/session-name-joins-project-and-identifier ()
  (should (equal (dl-zmx-session-name "hris" "claude") "hris.claude")))

(ert-deftest dl-zmx/session-name-folds-dots-in-the-project ()
  "The wrapper refuses a second dot, so a dotted project folds to `_', as zp's."
  (should (equal (dl-zmx-session-name "my.repo" "1") "my_repo.1")))

(ert-deftest dl-zmx/session-name-drops-leading-dots ()
  "Hidden project dirs (`.hidden.d') give readable session names."
  (should (equal (dl-zmx-session-name ".hidden.d" "pi") "hidden_d.pi")))

(ert-deftest dl-zmx/session-name-replaces-label-unsafe-chars ()
  (should (equal (dl-zmx-session-name "my proj" "a/b") "my-proj.a-b")))

(ert-deftest dl-zmx/creatable-name-has-one-dot-and-both-parts ()
  "The names the wrapper will create a session under."
  (should (dl-zmx-creatable-name-p "hris.claude"))
  (should-not (dl-zmx-creatable-name-p "doctrine.v0.1"))
  (should-not (dl-zmx-creatable-name-p ".1"))
  (should-not (dl-zmx-creatable-name-p "p.")))

(ert-deftest dl-zmx/attach-argv-asks-for-nothing-but-the-name ()
  "Labels and the scope are the wrapper's, so the argv is bare attach."
  (let ((dl-zmx-command "zmx")
        (dl-zmx-shell "nu"))
    (should (equal (dl-zmx-attach-argv "hris.claude")
                   '("zmx" "attach" "hris.claude" "nu")))))

(ert-deftest dl-zmx/buffer-name-is-term-prefixed ()
  (should (equal (dl-zmx-buffer-name "hris.claude") "term-hris.claude")))

(ert-deftest dl-zmx/parse-sessions-keeps-a-session-whose-task-ended ()
  "`ended=' reports the last `zmx run' task; the session and its shell live on."
  (should
   (equal
    (mapcar (lambda (session) (alist-get 'name session))
            (dl-zmx--parse-sessions
             (concat
              "  name=ls\tpid=1\tclients=0\tcreated=1\tcwd=file://h/x\n"
              "  name=sh\tpid=2\tclients=0\tcwd=file://h/x\tended=1\texit_code=0\n"
              "  name=hris.claude\tpid=3\tclients=1\tcwd=file://h/y\n")))
    '("ls" "sh" "hris.claude"))))

(ert-deftest dl-zmx/parse-sessions-keeps-labels ()
  "Labels are listed as ordinary fields after the built-in ones."
  (should (equal (dl-zmx--parse-sessions
                  "  name=a\tclients=1\tcwd=file://h/srv/x\tid=b\tproject=foo\n")
                 '(((name . "a") (clients . "1") (cwd . "file://h/srv/x")
                    (id . "b") (project . "foo"))))))

(ert-deftest dl-zmx/parse-sessions-keeps-a-command-with-spaces ()
  "Fields are tab-separated, and `cmd' holds the session's whole command."
  (should (equal (dl-zmx--parse-sessions "  name=a\tcmd=sh -c 'sleep 5'\tid=b\n")
                 '(((name . "a") (cmd . "sh -c 'sleep 5'") (id . "b"))))))

(ert-deftest dl-zmx/parse-sessions-empty-output ()
  (should (null (dl-zmx--parse-sessions ""))))

(defmacro dl-zmx-test--with-zmx (body &rest script)
  "Run BODY with `dl-zmx-command' bound to a stub running SCRIPT."
  (declare (indent 1))
  `(let ((dl-zmx-command (make-temp-file "zmx-stub")))
     (unwind-protect
         (progn
           (with-temp-file dl-zmx-command
             (insert "#!/bin/sh\n" ,@script))
           (set-file-modes dl-zmx-command #o700)
           ,body)
       (delete-file dl-zmx-command))))

(ert-deftest dl-zmx/sessions-ignore-stderr ()
  "With no sessions, `zmx list' explains itself on stderr."
  (dl-zmx-test--with-zmx
   (should (null (dl-zmx-sessions)))
   "echo 'no sessions found in /run/zmx' >&2\n"))

(ert-deftest dl-zmx/session-dir-from-cwd-url ()
  (should (equal (dl-zmx--session-dir '((cwd . "file://h/srv/my%20dir")))
                 "/srv/my dir/"))
  (should (null (dl-zmx--session-dir '((name . "a"))))))

(ert-deftest dl-zmx/session-dir-from-verbatim-kitty-url ()
  "Ghostel's bash and zsh integrations report the path unencoded."
  (should (equal (dl-zmx--session-dir
                  '((cwd . "kitty-shell-cwd://Sleipnir/srv/100%20dir")))
                 "/srv/100%20dir/")))

(ert-deftest dl-zmx/annotation-shows-state-project-clients-dir ()
  (should (equal (dl-zmx--annotation
                  '((name . "a") (clients . "1") (cwd . "file://h/srv/x")
                    (project . "foo") (state . "working")))
                 "  ◐  foo  1 attached  /srv/x/"))
  (should (equal (dl-zmx--annotation '((name . "a") (clients . "0")))
                 "  ·  0 attached")))

(ert-deftest dl-zmx/annotation-adds-labels-as-pairs ()
  "`id' is in the name and `role' in the candidate; zmx's own fields aren't labels."
  (should (equal (dl-zmx--annotation
                  '((name . "p.1") (pid . "1") (clients . "0") (created . "2")
                    (cwd . "file://h/x") (ended . "3") (exit_code . "0")
                    (cmd . "sh") (id . "1") (note . "wip") (owner . "me")
                    (project . "p") (role . "tests")))
                 "  ·  p  0 attached  /x/  note:wip  owner:me")))

(ert-deftest dl-zmx/annotation-shows-the-exit-code-beside-a-state ()
  "`state' is a claim and `exit_code' a fact: a reader believes neither alone."
  (should (equal (dl-zmx--annotation
                  '((name . "a") (clients . "0") (ended . "3") (exit_code . "1")
                    (state . "done")))
                 "  ●  0 attached  exit_code:1")))

(ert-deftest dl-zmx/annotation-keeps-its-face-beside-a-coloured-icon ()
  "A completion UI leaves an annotation with any face of its own as it is."
  (let ((annotation (dl-zmx--annotation '((name . "a") (clients . "0")))))
    (should (eq (get-text-property (1- (length annotation)) 'face annotation)
                'completions-annotations))))

(ert-deftest dl-zmx/state-icon-tells-the-states-apart ()
  (should (equal (mapcar #'dl-zmx--state-icon
                         '("done" "working" "blocked" "failed" nil "other"))
                 '("●" "◐" "◌" "⊘" "·" "*"))))

(ert-deftest dl-zmx/state-icon-is-coloured ()
  (should (eq (get-text-property 0 'face (dl-zmx--state-icon "failed")) 'error)))

(ert-deftest dl-zmx/candidates-put-a-role-after-the-aligned-name ()
  "In the candidate, not the annotation, so that a role can be searched."
  (let ((one '((name . "docs.1")))
        (two '((name . "docs.22") (role . "tests"))))
    (should (equal (dl-zmx--candidates (list one two))
                   `(("docs.1" . ,one) ("docs.22  tests" . ,two))))))

(ert-deftest dl-zmx/read-session-maps-a-role-candidate-to-its-session ()
  (cl-letf (((symbol-function 'completing-read)
             (lambda (_prompt collection &rest _)
               (caar (last collection)))))
    (dl-zmx-test--with-zmx
     (should (equal (alist-get 'name (dl-zmx--read-session "zmx: ")) "p.2"))
     "printf '  name=p.1\\tclients=0\\n  name=p.2\\tclients=0\\trole=tests\\n'")))

(ert-deftest dl-zmx/read-session-aligns-annotations ()
  "Every row's annotation starts in one column, so the state icons line up."
  (let (columns)
    (cl-letf (((symbol-function 'completing-read)
               (lambda (_prompt collection &rest _)
                 (let ((annotate (plist-get completion-extra-properties
                                            :annotation-function)))
                   (setq columns
                         (mapcar (lambda (row)
                                   (string-search
                                    "·" (concat (car row)
                                                (funcall annotate (car row)))))
                                 collection)))
                 (caar collection))))
      (dl-zmx-test--with-zmx
       (dl-zmx--read-session "zmx: ")
       "printf '  name=p.1\\tclients=0\\n  name=p.22\\tclients=0\\trole=tests\\n'"))
    (should (numberp (car columns)))
    (should (equal (length (delete-dups columns)) 1))))

(ert-deftest dl-zmx/project-identifiers-from-sessions ()
  "Only this project's sessions, by identifier."
  (should (equal (dl-zmx-project-identifiers
                  ".hidden.d" '("hidden_d.claude" "hris.pi" "hidden_d.build" "ls"))
                 '("claude" "build"))))

(ert-deftest dl-zmx/project-identifiers-leave-out-old-hyphen-names ()
  "An old `P-ID' session is reached through `my/zmx-switch', not by project."
  (should (null (dl-zmx-project-identifiers "hris" '("hris-claude")))))

(ert-deftest dl-zmx/next-name-goes-one-above-the-highest-number ()
  "As zp's: word identifiers and other projects don't count."
  (should (equal (dl-zmx-next-name
                  "zmux" '("zmux.1" "zmux.3" "zmux.tests" "other.9"))
                 "zmux.4")))

(ert-deftest dl-zmx/next-name-starts-at-one ()
  (should (equal (dl-zmx-next-name "zmux" '("other.9")) "zmux.1")))

(ert-deftest dl-zmx/next-name-folds-the-project ()
  (should (equal (dl-zmx-next-name "my.repo" '("my_repo.2")) "my_repo.3")))

(ert-deftest dl-zmx/latest-session-is-the-newest-with-the-project-label ()
  "Grouped by label, so an older `P-ID' session with one is found too."
  (should (equal (alist-get 'name
                            (dl-zmx-latest-session
                             "p" '(((name . "p.1") (created . "10") (project . "p"))
                                   ((name . "p-old") (created . "30") (project . "p"))
                                   ((name . "q.1") (created . "40") (project . "q"))
                                   ((name . "bare") (created . "50")))))
                 "p-old")))

(ert-deftest dl-zmx/latest-session-is-nil-without-one ()
  (should (null (dl-zmx-latest-session "p" '(((name . "bare") (created . "1")))))))

(ert-deftest dl-zmx/scope-name-is-the-project-name-in-a-project ()
  (cl-letf (((symbol-function 'project-current) (lambda (&rest _) 'a-project))
            ((symbol-function 'project-name) (lambda (_) "zmux")))
    (should (equal (dl-zmx--scope-name) "zmux"))))

(ert-deftest dl-zmx/scope-name-is-the-directory-outside-a-project ()
  (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil)))
    (let ((default-directory "/tmp/Downloads/"))
      (should (equal (dl-zmx--scope-name) "Downloads")))))

(ert-deftest dl-zmx/scope-name-is-empty-at-the-filesystem-root ()
  (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil)))
    (let ((default-directory "/"))
      (should (equal (dl-zmx--scope-name) "")))))

(defmacro dl-zmx-test--capturing-open (&rest body)
  "Run BODY in project p, with `dl-zmx--open' recording its session in `opened'."
  (declare (indent 0))
  `(let (opened)
     (cl-letf (((symbol-function 'dl-zmx--open)
                (lambda (session _argv) (setq opened session)))
               ((symbol-function 'dl-zmx--scope-name) (lambda () "p"))
               ((symbol-function 'project-current) (lambda (&rest _) 'a-project))
               ((symbol-function 'project-name) (lambda (_) "p"))
               ((symbol-function 'project-root) (lambda (_) "/tmp/")))
       ,@body)))

(ert-deftest dl-zmx/new-counts-a-session-whose-task-ended ()
  "A finished task leaves the session, so its name stays taken."
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (progn (my/zmx-new)
            (should (equal opened "p.2")))
     "printf '  name=p.1\\tclients=0\\tended=1\\texit_code=0\\n'")))

(ert-deftest dl-zmx/new-refuses-a-name-with-no-project ()
  "At `/' the name would be `.1': the wrapper's refusal would close the buffer."
  (dl-zmx-test--capturing-open
    (cl-letf (((symbol-function 'dl-zmx--scope-name) (lambda () "")))
      (dl-zmx-test--with-zmx
       (should (string-search ".1" (cadr (should-error (my/zmx-new)
                                                       :type 'user-error))))
       "exit 0\n"))
    (should (null opened))))

(ert-deftest dl-zmx/new-stays-plain-ghostel-on-a-remote-directory ()
  "zmx is local; a TRAMP terminal is a remote shell."
  (let ((default-directory "/ssh:host:/srv/")
        ghostel-arg)
    (dl-zmx-test--capturing-open
      (cl-letf (((symbol-function 'ghostel)
                 (lambda (&optional arg) (setq ghostel-arg arg))))
        (my/zmx-new))
      (should (equal ghostel-arg '(4)))
      (should (null opened)))))

(ert-deftest dl-zmx/resume-reattaches-the-latest-session ()
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (progn (my/zmx-resume)
            (should (equal opened "p.2")))
     "printf '  name=p.1\\tclients=0\\tcreated=1\\tproject=p\\n"
     "  name=p.2\\tclients=0\\tcreated=2\\tproject=p\\n'")))

(ert-deftest dl-zmx/resume-reaches-a-session-whose-task-ended ()
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (progn (my/zmx-resume)
            (should (equal opened "p.2")))
     "printf '  name=p.1\\tclients=0\\tcreated=1\\tproject=p\\n"
     "  name=p.2\\tclients=0\\tcreated=2\\tended=3\\tproject=p\\n'")))

(ert-deftest dl-zmx/resume-creates-when-there-is-no-session ()
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (progn (my/zmx-resume)
            (should (equal opened "p.1")))
     "exit 0\n")))

(ert-deftest dl-zmx/project-opens-a-new-plain-identifier ()
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (progn (my/zmx-project "tests")
            (should (equal opened "p.tests")))
     "exit 0\n")))

(ert-deftest dl-zmx/project-refuses-a-new-dotted-identifier ()
  "Told at the prompt: the wrapper's refusal would close the buffer unread."
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (should (string-search "p.v0.1" (cadr (should-error (my/zmx-project "v0.1")
                                                         :type 'user-error))))
     "printf '  name=p.1\\tclients=0\\n'")
    (should (null opened))))

(ert-deftest dl-zmx/project-reaches-a-running-dotted-session ()
  (dl-zmx-test--capturing-open
    (dl-zmx-test--with-zmx
     (progn (my/zmx-project "v0.1")
            (should (equal opened "p.v0.1")))
     "printf '  name=p.v0.1\\tclients=0\\n'")))

(ert-deftest dl-zmx/kill-asks-zmx-to-kill-the-chosen-session ()
  (let (argv)
    (cl-letf (((symbol-function 'dl-zmx--read-session)
               (lambda (_prompt) '((name . "p.1"))))
              ((symbol-function 'y-or-n-p) (lambda (_prompt) t))
              ((symbol-function 'call-process)
               (lambda (&rest args) (setq argv args) 0)))
      (let ((dl-zmx-command "zmx"))
        (call-interactively #'my/zmx-kill)))
    (should (equal argv '("zmx" nil nil nil "kill" "p.1")))))

(ert-deftest dl-zmx/kill-does-nothing-when-declined ()
  (let (called)
    (cl-letf (((symbol-function 'dl-zmx--read-session)
               (lambda (_prompt) '((name . "p.1"))))
              ((symbol-function 'y-or-n-p) (lambda (_prompt) nil))
              ((symbol-function 'call-process)
               (lambda (&rest _) (setq called t) 0)))
      (call-interactively #'my/zmx-kill))
    (should-not called)))

(ert-deftest dl-zmx/parse-sessions-reads-the-current-session ()
  "Inside a session, `zmx list' marks that session's line with an arrow."
  (should (equal (alist-get 'name (car (dl-zmx--parse-sessions
                                        "→ name=emacs.4\tpid=1\tclients=1\n")))
                 "emacs.4")))

(ert-deftest dl-zmx/sessions-survive-a-deleted-directory ()
  "A buffer whose directory has gone can still list sessions."
  (let ((dl-zmx-command "true")
        (default-directory "/no/such/directory/"))
    (should-not (dl-zmx-sessions))))

(defconst dl-zmx-test--open-session
  '((name . "hris.1") (clients . "1"))
  "A session with a live terminal in `dl-zmx-test--with-consult-items'.")

(defconst dl-zmx-test--unopened-session
  '((name . "hris.2") (role . "tests") (clients . "0"))
  "A session with no terminal in `dl-zmx-test--with-consult-items'.")

(defmacro dl-zmx-test--with-consult-items (sessions &rest body)
  "Run BODY with `items' bound to the consult source's items for SESSIONS.
Of the sessions, only `dl-zmx-test--open-session' has a live terminal."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'dl-zmx-sessions) (lambda () ,sessions))
             ((symbol-function 'dl-zmx--terminal-live-p)
              (lambda (session) (eq session dl-zmx-test--open-session))))
     (let ((items (funcall (plist-get dl-zmx-consult-source :items))))
       ,@body)))

(ert-deftest dl-zmx/consult-offers-sessions-without-a-terminal ()
  "Live terminals are `consult-ghostel's; this source offers the rest."
  (dl-zmx-test--with-consult-items
      (list dl-zmx-test--open-session dl-zmx-test--unopened-session)
    (should (equal (mapcar #'substring-no-properties items) '("hris.2  tests")))))

(ert-deftest dl-zmx/consult-offers-nothing-without-sessions ()
  "No session to offer is an empty group, not an error in `consult-buffer'."
  (dl-zmx-test--with-consult-items (list dl-zmx-test--open-session)
    (should-not items))
  (dl-zmx-test--with-consult-items nil
    (should-not items)))

(ert-deftest dl-zmx/consult-annotates-as-the-session-picker-does ()
  (dl-zmx-test--with-consult-items (list dl-zmx-test--unopened-session)
    (should (equal (funcall (plist-get dl-zmx-consult-source :annotate) (car items))
                   (dl-zmx--annotation dl-zmx-test--unopened-session)))))

(ert-deftest dl-zmx/consult-reattaches-the-chosen-session ()
  (dl-zmx-test--with-consult-items (list dl-zmx-test--unopened-session)
    (cl-letf* ((reattached nil)
               ((symbol-function 'dl-zmx--reattach)
                (lambda (session) (setq reattached session))))
      (funcall (plist-get dl-zmx-consult-source :action) (car items))
      (should (eq reattached dl-zmx-test--unopened-session)))))

(ert-deftest dl-zmx/consult-source-needs-zmx ()
  "Without zmx, `consult-buffer' goes on without the source."
  (let ((enabled (plist-get dl-zmx-consult-source :enabled))
        (dl-zmx-command "no-such-zmx-command"))
    (should-not (funcall enabled))))

(ert-deftest dl-zmx/consult-buffer-offers-sessions ()
  "`consult-buffer' reaches the source, narrowed by `z' and otherwise hidden."
  (skip-unless (require 'consult nil t))
  (should (memq 'dl-zmx-consult-source consult-buffer-sources))
  (should (plist-get dl-zmx-consult-source :hidden))
  (should (equal (plist-get dl-zmx-consult-source :narrow) '(?z . "zmx"))))

(ert-deftest dl-zmx/ghostel-exec-callable-before-ghostel-loads ()
  "ghostel is lazy-loaded and doesn't autoload `ghostel-exec' itself."
  (should (fboundp 'ghostel-exec)))

(ert-deftest dl-zmx/offered-on-project-switch ()
  "`project-switch-project' menu offers zmx on `z'."
  (should (equal (assq 'my/zmx-project project-switch-commands)
                 '(my/zmx-project "zmx" "z"))))

(provide 'dl-zmx-test)
;;; dl-zmx-test.el ends here
