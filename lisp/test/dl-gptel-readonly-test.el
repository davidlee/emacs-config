;;; dl-gptel-readonly-test.el --- ert tests for read-only shell detection -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gptel-readonly RET.

(require 'ert)
(require 'dl-gptel-readonly)

(defun dl-gptel-readonly-test--all (pred commands)
  "Assert PRED holds of `dl-gptel-readonly-command-p' for every one of COMMANDS."
  (dolist (command commands)
    (should (equal (list command (funcall pred (dl-gptel-readonly-command-p command)))
                   (list command t)))))

(ert-deftest dl-gptel-readonly/allows-reference-commands ()
  "Plain searches, listings and git history reads need no confirmation."
  (dl-gptel-readonly-test--all
   #'identity
   '("rg -n 'defun foo' lisp/"
     "fd -e el . apps"
     "ls -la"
     "wc -l init.el"
     "git log --oneline -20"
     "git -C ~/dev/satan diff HEAD~1"
     "git --no-pager show HEAD:init.el")))

(ert-deftest dl-gptel-readonly/allows-pipelines-of-readonly-commands ()
  "Each pipeline stage is checked on its own."
  (dl-gptel-readonly-test--all
   #'identity
   '("rg -l foo | head -5"
     "fd -e el | wc -l"
     "git log --format=%an | sort | head")))

(ert-deftest dl-gptel-readonly/quoted-metacharacters-are-literal ()
  "Regex syntax inside single quotes is not shell syntax."
  (dl-gptel-readonly-test--all
   #'identity
   '("rg 'foo$|bar;baz' ."
     "rg 'a > b' ."
     "rg \"a | b\" .")))

(ert-deftest dl-gptel-readonly/rejects-shell-control ()
  "Sequencing, redirection and substitution can do anything."
  (dl-gptel-readonly-test--all
   #'not
   '("ls; rm -rf x"
     "ls && touch x"
     "ls & sleep 1"
     "rg foo > out.txt"
     "cat < /etc/passwd"
     "ls $(touch x)"
     "ls `touch x`"
     "echo \"$HOME\""
     "ls ||touch x"
     "ls |"
     "ls\ntouch x"
     "rg 'unterminated"
     "ls trailing\\")))

(ert-deftest dl-gptel-readonly/rejects-words-bash-would-rewrite ()
  "Globs can expand to a file named like an option, and backslash-newline
joins words, so what bash runs could differ from what was checked."
  (dl-gptel-readonly-test--all
   #'not
   '("rg foo *"
     "ls ?"
     "ls [a-z]"
     "rg --p{re,x}=sh foo"
     "rg --pr\\\ne=sh foo"
     "rg \"--pr\\\ne=sh\" foo"))
  (dl-gptel-readonly-test--all
   #'identity
   '("rg 'foo*' ."
     "rg \"a\\\"b\" ."
     "fd \\*.el")))

(ert-deftest dl-gptel-readonly/options-are-checked-after-unquoting ()
  "Quoting cannot hide a forbidden option."
  (dl-gptel-readonly-test--all
   #'not
   '("rg '--pr''e'=sh foo"
     "rg \"--pre\"=sh foo"
     "rg --p\\re=sh foo"
     "fd -e el '-x' rm")))

(ert-deftest dl-gptel-readonly/rejects-unlisted-commands ()
  "Anything not on the allowlist asks, wherever it sits in a pipeline."
  (dl-gptel-readonly-test--all
   #'not
   '("rm -rf x"
     "rg foo | xargs rm"
     "sed -i s/a/b/ f"
     "env rm x"
     "")))

(ert-deftest dl-gptel-readonly/rejects-side-effecting-options ()
  "Options that execute programs or write files ask, abbreviated or clustered."
  (dl-gptel-readonly-test--all
   #'not
   '("fd -e el -x rm"
     "fd -Hx rm"
     "fd --exec-batch rm"
     "rg --pre=sh foo"
     "rg --pre sh foo"
     "find . -delete"
     "find . -exec rm {} ;"
     "sort -o out f"
     "sort --out=out f"
     "sort --compress-program=sh f"
     "tail -f log"
     "git diff --output=x"
     "git diff --out=x"
     "git grep -O foo")))

(ert-deftest dl-gptel-readonly/git-needs-listed-subcommand ()
  "Only history and tree reads; no global options that set config."
  (dl-gptel-readonly-test--all
   #'not
   '("git commit -m x"
     "git branch new"
     "git -c core.pager=sh log"
     "git"
     "git -C")))

(ert-deftest dl-gptel-readonly/confirm-predicate-inverts ()
  "The Bash tool asks exactly when the command is not read-only."
  (should-not (dl-gptel-bash-needs-confirm-p "ls"))
  (should (dl-gptel-bash-needs-confirm-p "rm x")))

(ert-deftest dl-gptel-readonly/system-note-names-the-allowlist ()
  "The model is told which commands skip confirmation, so it prefers them."
  (let ((note (dl-gptel-readonly-system-note)))
    (dolist (name (append (mapcar #'car dl-gptel-readonly-commands)
                          dl-gptel-readonly-git-subcommands))
      (should (string-match-p (regexp-quote name) note)))))

;;; dl-gptel-readonly-test.el ends here
