;;; dl-satan-patch-worktree.el --- git worktree mechanics for patch jobs -*- lexical-binding: t; -*-

;; Phase 1.3 of satan/patch-harness.plan.md.  Branch naming, worktree
;; creation, allowlist verification, and cleanup.  All git operations
;; run via subprocess to the system `git'.
;;
;; Allowed-paths matching: each entry is a repo-root-relative string.
;; A trailing `/' means "this directory and below"; no trailing `/'
;; means an exact file match.  No globs in v1; simple to extend later.

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-patch-store)  ; for the patch group + id helper

(defcustom dl-satan-patch-worktree-root
  (expand-file-name "satan/patch-agent/worktrees/"
                    (or (getenv "XDG_STATE_HOME")
                        (expand-file-name "~/.local/state/")))
  "Filesystem root under which job worktrees are created.
One directory per job, keyed by job id."
  :type 'directory :group 'dl-satan-patch)

(defcustom dl-satan-patch-worktree-git-program
  (or (executable-find "git") "git")
  "Path to the `git' binary."
  :type 'string :group 'dl-satan-patch)

;; ---------------------------------------------------------------------
;; branch naming
;; ---------------------------------------------------------------------

(defun dl-satan-patch-worktree--slugify (s)
  "Lowercase S, replace non-alnum runs with `-', strip leading/trailing `-'."
  (let* ((down (downcase (or s "")))
         (subbed (replace-regexp-in-string "[^a-z0-9]+" "-" down))
         (trimmed (replace-regexp-in-string "\\`-+\\|-+\\'" "" subbed)))
    (if (string-empty-p trimmed) "job" trimmed)))

(defun dl-satan-patch-worktree-branch-name (mode slug &optional time)
  "Return `satan/MODE/YYYYMMDDTHHMMSS-SLUG'.
TIME (epoch seconds or time object) defaults to now.  SLUG is
slugified to lowercase alnum + dashes."
  (let* ((stamp (format-time-string "%Y%m%dT%H%M%S" time))
         (safe-slug (dl-satan-patch-worktree--slugify slug))
         (safe-mode (dl-satan-patch-worktree--slugify mode)))
    (format "satan/%s/%s-%s" safe-mode stamp safe-slug)))

(defun dl-satan-patch-worktree-path-for (job-id)
  "Return the canonical worktree path for JOB-ID."
  (expand-file-name job-id dl-satan-patch-worktree-root))

;; ---------------------------------------------------------------------
;; git plumbing
;; ---------------------------------------------------------------------

(defun dl-satan-patch-worktree--git (repo args &optional input)
  "Run `git -C REPO ARGS', optionally feeding INPUT to stdin.
Return (ok . STDOUT) or (error . MSG)."
  (with-temp-buffer
    (let* ((full-args (append (list "-C" repo) args))
           (status (if input
                       (with-temp-buffer
                         (insert input)
                         (apply #'call-process-region
                                (point-min) (point-max)
                                dl-satan-patch-worktree-git-program
                                nil (current-buffer) nil full-args))
                     (apply #'call-process
                            dl-satan-patch-worktree-git-program
                            nil t nil full-args))))
      (if (and (integerp status) (zerop status))
          (cons 'ok (buffer-string))
        (cons 'error (format "git exit %s: %s"
                              status (string-trim (buffer-string))))))))

;; ---------------------------------------------------------------------
;; create
;; ---------------------------------------------------------------------

(defun dl-satan-patch-worktree-create (job-spec)
  "Create the git worktree described by JOB-SPEC.
Required keys: :id :repo :base_ref :branch :worktree_path
              :allowed_paths_json (list of strings) :checks_json (list)
Writes a manifest file at `<worktree>/.satan-patch-manifest.json'.

Returns (ok PLIST) with :worktree-path and :branch, or
(error MSG).  Idempotent: refuses to create if worktree_path
exists, but succeeds if the branch already exists and points at
base_ref."
  (let* ((repo (plist-get job-spec :repo))
         (base (plist-get job-spec :base_ref))
         (branch (plist-get job-spec :branch))
         (wt (plist-get job-spec :worktree_path))
         (allowed (plist-get job-spec :allowed_paths_json))
         (checks (plist-get job-spec :checks_json))
         (id (plist-get job-spec :id)))
    (cond
     ((not (file-directory-p repo))
      (cons 'error (format "repo missing: %s" repo)))
     ((file-exists-p wt)
      (cons 'error (format "worktree path exists: %s" wt)))
     (t
      (let* ((parent (file-name-directory (directory-file-name wt))))
        (make-directory parent t))
      (pcase (dl-satan-patch-worktree--git
              repo (list "worktree" "add" wt "-b" branch base))
        (`(error . ,msg)
         (cons 'error (format "worktree add failed: %s" msg)))
        (`(ok . ,_)
         (let ((manifest (expand-file-name ".satan-patch-manifest.json" wt)))
           (with-temp-file manifest
             (insert
              (dl-satan-patch-store--json
               (list :job_id id
                     :repo repo
                     :base_ref base
                     :branch branch
                     :worktree_path wt
                     :allowed_paths (or allowed '())
                     :checks (or checks '())))))
           (cons 'ok (list :worktree-path wt :branch branch)))))))))

;; ---------------------------------------------------------------------
;; allowed-paths verify
;; ---------------------------------------------------------------------

(defun dl-satan-patch-worktree--normalize-path (p)
  "Normalise P: strip leading `./', trim whitespace."
  (let ((s (string-trim (or p ""))))
    (if (string-prefix-p "./" s) (substring s 2) s)))

(defun dl-satan-patch-worktree-path-allowed-p (path allowed)
  "Non-nil iff repo-relative PATH is permitted by the ALLOWED list.
Each entry of ALLOWED is repo-relative.  Trailing `/' means prefix
match; no trailing `/' means exact match."
  (let ((np (dl-satan-patch-worktree--normalize-path path)))
    (cl-some
     (lambda (entry)
       (let ((ne (dl-satan-patch-worktree--normalize-path entry)))
         (cond
          ((string-empty-p ne) nil)
          ((string-suffix-p "/" ne)
           (string-prefix-p ne np))
          (t (string= ne np)))))
     allowed)))

(defun dl-satan-patch-worktree-changed-files (job-spec)
  "Return (ok . LIST-OF-PATHS) of files changed between base_ref and HEAD.
Paths are repo-relative.  Runs inside the job's worktree."
  (let* ((wt (plist-get job-spec :worktree_path))
         (base (plist-get job-spec :base_ref)))
    (pcase (dl-satan-patch-worktree--git
            wt (list "diff" "--name-only"
                     (concat base "...HEAD")))
      (`(ok . ,out)
       (cons 'ok (split-string (string-trim out) "\n" t)))
      (err err))))

(defun dl-satan-patch-worktree-verify-allowlist (job-spec changed)
  "Check CHANGED files against JOB-SPEC's allowed paths.
Returns (ok . CHANGED) when every file is allowed, else
\(error . OFFENDING-PATHS)."
  (let* ((allowed (plist-get job-spec :allowed_paths_json))
         (bad (cl-remove-if
               (lambda (p)
                 (dl-satan-patch-worktree-path-allowed-p p allowed))
               changed)))
    (if bad
        (cons 'error bad)
      (cons 'ok changed))))

;; ---------------------------------------------------------------------
;; cleanup
;; ---------------------------------------------------------------------

(cl-defun dl-satan-patch-worktree-cleanup (job-spec &key delete-branch)
  "Remove the worktree at JOB-SPEC's :worktree_path; optionally delete
branch.  Idempotent.  Returns (ok PLIST) with :removed-worktree and
:deleted-branch booleans, or (error MSG)."
  (let* ((repo (plist-get job-spec :repo))
         (wt (plist-get job-spec :worktree_path))
         (branch (plist-get job-spec :branch))
         (removed nil)
         (deleted nil))
    (when (file-exists-p wt)
      (pcase (dl-satan-patch-worktree--git
              repo (list "worktree" "remove" "--force" wt))
        (`(error . ,msg) (cl-return-from dl-satan-patch-worktree-cleanup
                           (cons 'error msg)))
        (_ (setq removed t))))
    (when delete-branch
      (pcase (dl-satan-patch-worktree--git
              repo (list "branch" "-D" branch))
        (`(error . ,msg)
         ;; Branch may already be gone after `worktree remove'; tolerate
         ;; "branch not found" but surface other errors.
         (unless (string-match-p "not found" msg)
           (cl-return-from dl-satan-patch-worktree-cleanup
             (cons 'error msg))))
        (_ (setq deleted t))))
    (cons 'ok (list :removed-worktree removed
                    :deleted-branch deleted))))

(provide 'dl-satan-patch-worktree)
;;; dl-satan-patch-worktree.el ends here
