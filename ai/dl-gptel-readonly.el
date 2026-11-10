;;; dl-gptel-readonly.el --- recognise read-only shell commands -*- lexical-binding: t; -*-

;;; Commentary:
;; A `:confirm' predicate for gptel-agent's Bash tool: reference commands
;; (rg, fd, git log, ...) run without asking, anything else asks.
;;
;; Conservative by construction: a command is read-only only if it is a
;; pipeline of allowlisted programs, with no other shell syntax (sequencing,
;; redirection, substitution, expansion) and none of the options that make
;; an allowlisted program write or execute.  A false negative costs one
;; confirmation prompt; the checks lean that way wherever they are unsure.
;;
;;   "rg -l 'a b' | head"  ─parse─▶  (("rg" "-l" "a b") ("head"))
;;                         ─each stage─▶ program allowlisted? options clean?

;;; Code:

(require 'cl-lib)
(require 'seq)

(defconst dl-gptel-readonly-commands
  '(("rg" "--pre")
    ("fd" "-x" "-X" "--exec" "--exec-batch")
    ("find" "-exec" "-execdir" "-ok" "-okdir" "-delete"
     "-fprint" "-fprint0" "-fprintf" "-fls")
    ("git" "--output" "-O" "--open-files-in-pager")
    ("grep") ("ls") ("tree" "-o") ("cat") ("head") ("tail" "-f" "-F" "--follow")
    ("wc") ("file" "-C" "--compile") ("stat") ("du") ("diff")
    ("realpath") ("readlink") ("basename") ("dirname") ("pwd") ("which")
    ("echo") ("sort" "-o" "--output" "--compress-program")
    ("cut") ("tr") ("nl") ("jq"))
  "Programs that only read, each with the options that make it write or execute.
An option is matched as the shell tool would parse it: \"--long\" also
matches its abbreviations, \"-x\" also matches inside a cluster such as
\"-Hx\", and anything else (find's \"-exec\") must match exactly.")

(defconst dl-gptel-readonly-git-subcommands
  '("status" "log" "show" "diff" "blame" "grep" "shortlog" "describe"
    "ls-files" "ls-tree" "rev-parse" "show-ref" "cat-file")
  "Git subcommands that only read the repository.")

(defun dl-gptel-readonly--parse (command)
  "Parse COMMAND into pipeline stages: lists of words as bash sees them.
Return nil if COMMAND needs any shell syntax beyond quoting, escaping and
`|': sequencing, redirection, substitution, variable or brace expansion,
globbing, line continuation, or an unterminated quote.
Words are built here, not by `split-string-shell-command', which
splits on quoted `;' and `|'."
  (catch 'unsafe
    (let ((chars (append command nil))
          stages words word in-word quote-char)
      (cl-flet ((add (c) (setq in-word t) (push c word))
                (end-word ()
                  (when in-word
                    (push (concat (nreverse word)) words)
                    (setq word nil in-word nil))))
        (while chars
          (let ((c (pop chars)))
            (cond
             ((eq quote-char ?') (if (eq c ?') (setq quote-char nil) (add c)))
             ((memq c '(?$ ?`)) (throw 'unsafe nil))
             ((and (eq c ?\\) (memq (car chars) '(nil ?\n))) (throw 'unsafe nil))
             ((eq quote-char ?\")
              (cond ((eq c ?\") (setq quote-char nil))
                    ((and (eq c ?\\) (memq (car chars) '(?\\ ?\" ?$ ?`)))
                     (add (pop chars)))
                    (t (add c))))
             ((eq c ?\\) (add (pop chars)))
             ((memq c '(?' ?\")) (setq quote-char c in-word t))
             ((memq c '(?\s ?\t)) (end-word))
             ((eq c ?|) (end-word) (push (nreverse words) stages) (setq words nil))
             ((memq c '(?\; ?& ?> ?< ?\( ?\) ?\n ?* ?? ?\[ ?{)) (throw 'unsafe nil))
             (t (add c)))))
        (unless quote-char
          (end-word)
          (nreverse (cons (nreverse words) stages)))))))

(defun dl-gptel-readonly--option-matches-p (arg option)
  "Return non-nil if ARG invokes OPTION.
See `dl-gptel-readonly-commands' for how OPTION is matched."
  (cond
   ((string-prefix-p "--" option)
    (let ((name (car (split-string arg "="))))
      (and (string-prefix-p "--" name)
           (> (length name) 2)
           (string-prefix-p name option))))
   ((= (length option) 2)
    (and (string-match-p "\\`-[^-]" arg)
         (seq-contains-p (substring arg 1) (aref option 1))))
   (t (equal arg option))))

(defun dl-gptel-readonly--git-args-p (args)
  "Return non-nil if git ARGS name a read-only subcommand.
Only --no-pager, -P and -C DIR may precede it: other global options,
such as -c, can reconfigure git to run programs."
  (while (member (car args) '("--no-pager" "-P" "-C"))
    (setq args (if (equal (car args) "-C") (cddr args) (cdr args))))
  (member (car args) dl-gptel-readonly-git-subcommands))

(defun dl-gptel-readonly--stage-p (words)
  "Return non-nil if pipeline stage WORDS runs a listed program read-only.
WORDS is the program followed by its arguments."
  (pcase-let ((`(,program . ,args) words))
    (when-let* ((entry (assoc program dl-gptel-readonly-commands)))
      (and (not (seq-some (lambda (arg)
                            (seq-some (apply-partially
                                       #'dl-gptel-readonly--option-matches-p arg)
                                      (cdr entry)))
                          args))
           (or (not (equal program "git"))
               (dl-gptel-readonly--git-args-p args))))))

(defun dl-gptel-readonly-command-p (command)
  "Return non-nil if shell COMMAND only reads.
See the commentary of this library for what that means."
  (when-let* ((stages (dl-gptel-readonly--parse command)))
    (seq-every-p #'dl-gptel-readonly--stage-p stages)))

(defun dl-gptel-bash-needs-confirm-p (command)
  "Return non-nil unless COMMAND is read-only.
A `:confirm' predicate for gptel-agent's Bash tool."
  (not (dl-gptel-readonly-command-p command)))

(defun dl-gptel-readonly-system-note ()
  "Return a system-prompt note naming the commands that run unprompted.
gptel-agent's Bash description steers the model away from searching with
the shell; this tells it read-only reference commands are cheap."
  (format "Read-only Bash commands run without asking the user: prefer them \
for exploration.  Allowed: %s; git %s.  Pipes (|) between them are fine; \
anything else (;, &&, redirection, $, globs, braces) asks for confirmation."
          (string-join (mapcar #'car dl-gptel-readonly-commands) ", ")
          (string-join dl-gptel-readonly-git-subcommands "/")))

(provide 'dl-gptel-readonly)
;;; dl-gptel-readonly.el ends here
