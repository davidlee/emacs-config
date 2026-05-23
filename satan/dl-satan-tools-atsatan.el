;;; dl-satan-tools-atsatan.el --- @satan scan + done tool handlers -*- lexical-binding: t; -*-

;; Scans ~/notes/ for @satan references and returns excerpts with
;; context (`notes_at_satan_scan'); marks a directive done by replacing
;; the @satan token with @satan-was-here on its line and appending a
;; quoted block containing run-id + summary (`notes_at_satan_done').
;;
;; Render shape (org files):
;;
;;   @satan-was-here <preserved trailing text>
;;   #+BEGIN_QUOTE satan <run-id>[,<tag>]
;;   <body>
;;   #+END_QUOTE
;;
;; Render shape (markdown files): a `> ' blockquote in place of the org
;; quote block, same header + body lines.
;;
;; The optional `<tag>' is the part of the `comment' arg before the
;; first colon; the body is the remainder. A comment with no colon
;; renders header-only (run-id) plus the whole comment as body.
;;
;; Risk model:
;;   - notes_at_satan_scan : risk read; no capability required.
;;   - notes_at_satan_done : risk low;  requires 'write-notes capability.

(require 'cl-lib)
(require 'subr-x)
(require 'json)
(require 'dl-notes-paths)
(require 'dl-satan-tools)
(require 'dl-satan-tick)  ; for dl-satan-tick-register at load time

(defcustom dl-satan-tools-atsatan-root
  dl-notes-root
  "Root directory the @satan scan searches under."
  :type 'directory :group 'dl-satan)

(defcustom dl-satan-tools-atsatan-default-context-lines 3
  "Default lines of context above and below each @satan match."
  :type 'integer :group 'dl-satan)

(defconst dl-satan-tools-atsatan--context-max 20
  "Hard upper bound on context lines; clamped without error.")

(defconst dl-satan-tools-atsatan--results-max 200
  "Hard upper bound on results returned in a single scan.")

(defconst dl-satan-tools-atsatan--exclude-globs
  '("!**/satan/**")
  "Glob exclusions passed to rg as repeated --glob flags.
`!satan/**' alone does not exclude when rg traverses an absolute root
— rg matches globs against the full path. `!**/satan/**' excludes
any `satan/' subtree regardless of depth.")

(defconst dl-satan-tools-atsatan--default-path-glob "*.{org,md}"
  "Default rg glob for files to scan.")

(defconst dl-satan-tools-atsatan--mark "@satan"
  "Substring matching an active @satan directive.")

(defconst dl-satan-tools-atsatan--claimed-re
  "@satan-\\(?:was-here\\|done\\)\\b"
  "Regex marking a claimed @satan line; excluded from scan results.
Lines bearing this marker were processed by a prior run and are
followed by a quoted summary block.  The `@satan-done' alternative
is the legacy claim token used before the rename to
`@satan-was-here'; kept here so historical claims in existing notes
stay filtered.")

(defconst dl-satan-tools-atsatan--headline-re
  "^\\(\\*+\\|#+\\) "
  "Org-or-markdown heading line; walked backward from each match.")

(defvar dl-satan-tools-atsatan--rg-program "rg"
  "Name (or absolute path) of the ripgrep binary. Overridable for tests.")

(defvar dl-satan-tools-atsatan--id-index (make-hash-table :test 'equal)
  "Maps :id → (FILE . LINE) within a single Emacs session.
Populated by the scan handler so the done handler does not need to
re-scan to resolve an id.")

(defun dl-satan-tools-atsatan--clamp (raw default min max)
  (cond ((null raw) default)
        ((< raw min) min)
        ((> raw max) max)
        (t raw)))

(defun dl-satan-tools-atsatan--hash (file line)
  "Stable id for a (FILE . LINE) pair within a single scan cycle.
Hash shifts if lines above the match are inserted/deleted, so callers
must round-trip the id within one scan-then-done cycle."
  (concat "M-" (substring (secure-hash 'md5 (format "%s:%d" file line)) 0 12)))

(defun dl-satan-tools-atsatan--remember (matches)
  "Store FILE/LINE for each match's id in the session index."
  (dolist (m matches)
    (puthash (plist-get m :id)
             (cons (plist-get m :file) (plist-get m :line))
             dl-satan-tools-atsatan--id-index)))

(defun dl-satan-tools-atsatan--split-comment (comment)
  "Split COMMENT into (TAG . BODY) on the first colon.
TAG is the trimmed substring before `:'; BODY is the trimmed remainder.
A comment with no colon yields (nil . trimmed-COMMENT).  An empty
or all-whitespace COMMENT yields (nil . nil).  Newlines in either
half collapse to single spaces."
  (let ((c (and comment
                (replace-regexp-in-string "[\n\r]+" " " comment))))
    (cond
     ((or (null c) (string-empty-p (string-trim c)))
      (cons nil nil))
     ((string-match "\\`\\([^:]+\\):\\(.*\\)\\'" c)
      (let ((tag  (string-trim (match-string 1 c)))
            (body (string-trim (match-string 2 c))))
        (cons (if (string-empty-p tag) nil tag)
              (if (string-empty-p body) nil body))))
     (t (cons nil (string-trim c))))))

(defun dl-satan-tools-atsatan--render-block (file run-id comment)
  "Return the claim block for FILE as a list of strings (one per line).
RUN-ID identifies the producing tick; COMMENT is the model's summary,
split into TAG/BODY by `dl-satan-tools-atsatan--split-comment'.
Org files render an `#+BEGIN_QUOTE'/`#+END_QUOTE' pair; markdown files
render a `> '-prefixed blockquote."
  (let* ((ext   (downcase (or (file-name-extension file) "")))
         (md    (equal ext "md"))
         (split (dl-satan-tools-atsatan--split-comment comment))
         (tag   (car split))
         (body  (cdr split))
         (header (concat "satan " (or run-id "")
                         (if tag (concat "," tag) ""))))
    (if md
        (append (list (concat "> " header))
                (and body (list (concat "> " body))))
      (append (list (concat "#+BEGIN_QUOTE " header))
              (and body (list body))
              (list "#+END_QUOTE")))))

(defun dl-satan-tools-atsatan--rg-argv (max-results path-glob)
  (let ((argv (list "--json" "-n" "--fixed-strings"
                    "--max-count" (number-to-string max-results)
                    "--glob" path-glob)))
    (dolist (g dl-satan-tools-atsatan--exclude-globs)
      (setq argv (append argv (list "--glob" g))))
    (append argv
            (list dl-satan-tools-atsatan--mark
                  dl-satan-tools-atsatan-root))))

(defun dl-satan-tools-atsatan--run-rg (argv)
  "Invoke rg with ARGV. Returns (:exit N :stdout STR :stderr STR)."
  (let ((stdout-buf (generate-new-buffer " *satan-atsatan-rg-out*"))
        (stderr-file (make-temp-file "satan-atsatan-rg-err-")))
    (unwind-protect
        (let ((exit (apply #'call-process
                           dl-satan-tools-atsatan--rg-program nil
                           (list stdout-buf stderr-file) nil argv)))
          (list :exit exit
                :stdout (with-current-buffer stdout-buf (buffer-string))
                :stderr (with-temp-buffer
                          (when (file-readable-p stderr-file)
                            (insert-file-contents stderr-file))
                          (buffer-string))))
      (when (buffer-live-p stdout-buf) (kill-buffer stdout-buf))
      (when (file-exists-p stderr-file) (delete-file stderr-file)))))

(defun dl-satan-tools-atsatan--parse-matches (stdout)
  "Parse rg --json STDOUT into a list of (:file :line :content) plists.
Skips non-match records and lines bearing the claimed marker."
  (let (out)
    (dolist (raw (split-string stdout "\n" t))
      (let* ((rec (ignore-errors
                    (json-parse-string raw :object-type 'plist
                                       :array-type 'list
                                       :null-object nil)))
             (type (and rec (plist-get rec :type)))
             (data (and rec (plist-get rec :data))))
        (when (and (equal type "match") data)
          (let* ((path (plist-get (plist-get data :path) :text))
                 (line (plist-get data :line_number))
                 (text (plist-get (plist-get data :lines) :text))
                 (content (and text (string-trim-right text))))
            (when (and path line content
                       (not (string-match-p dl-satan-tools-atsatan--claimed-re
                                            content)))
              (push (list :file path :line line :content content)
                    out))))))
    (nreverse out)))

(defun dl-satan-tools-atsatan--enrich (matches context-lines)
  "Add :context, :headline, :mtime, :id to each match plist.
Opens each unique file once; reads lines into a vector for slicing."
  (let ((cache (make-hash-table :test 'equal)))
    (mapcar
     (lambda (m)
       (let* ((file  (plist-get m :file))
              (line  (plist-get m :line))
              (lines (or (gethash file cache)
                         (puthash file
                                  (with-temp-buffer
                                    (let ((coding-system-for-read 'utf-8))
                                      (insert-file-contents file))
                                    (vconcat (split-string (buffer-string) "\n")))
                                  cache)))
              (n     (length lines))
              (idx   (1- line))
              (lo    (max 0 (- idx context-lines)))
              (hi    (min (1- n) (+ idx context-lines)))
              (window (cl-loop for i from lo to hi
                               collect (aref lines i)))
              (headline (cl-loop for i from (1- idx) downto 0
                                 for ln = (aref lines i)
                                 when (string-match-p
                                       dl-satan-tools-atsatan--headline-re ln)
                                 return ln))
              (mtime (format-time-string
                      "%Y-%m-%dT%H:%M:%S%z"
                      (file-attribute-modification-time
                       (file-attributes file)))))
         (append m
                 (list :context (mapconcat #'identity window "\n")
                       :headline headline
                       :mtime mtime
                       :id (dl-satan-tools-atsatan--hash file line)))))
     matches)))

(defun dl-satan-tools-atsatan--rewrite-line (file line run-id comment)
  "Claim the @satan directive on LINE of FILE for RUN-ID with COMMENT.
Replaces the first `@satan' on the line with `@satan-was-here',
preserving any text on either side, and inserts the rendered claim
block (see `dl-satan-tools-atsatan--render-block') immediately below.
Block lines inherit the original line's leading whitespace so list
items stay aligned.

Optimistic re-read: if the line no longer contains a bare `@satan' (or
already contains `@satan-was-here'), return :status \"already-done\"
without writing."
  (let ((coding-system-for-read 'utf-8)
        (coding-system-for-write 'utf-8))
    (with-temp-buffer
      (insert-file-contents file)
      (goto-char (point-min))
      (forward-line (1- line))
      (let* ((line-start (point))
             (line-end   (line-end-position))
             (current    (buffer-substring-no-properties line-start line-end))
             (id         (dl-satan-tools-atsatan--hash file line)))
        (cond
         ((string-match-p dl-satan-tools-atsatan--claimed-re current)
          (cons 'ok (list :match-id id :status "already-done")))
         ((not (string-match-p (regexp-quote dl-satan-tools-atsatan--mark)
                               current))
          (cons 'ok (list :match-id id :status "already-done")))
         (t
          ;; Replace the first @satan in `current'; preserve any
          ;; preceding text (e.g. a leading "- " list bullet).
          ;; Note: an older spec used `(replace-regexp-in-string ... nil 1)';
          ;; non-nil START omits text before START from the return
          ;; value, eating the leading character. Use explicit match +
          ;; concat instead.
          (let* ((mark    dl-satan-tools-atsatan--mark)
                 (idx     (string-match (regexp-quote mark) current))
                 (replaced (concat (substring current 0 idx)
                                   "@satan-was-here"
                                   (substring current (+ idx (length mark)))))
                 (indent  (if (string-match "\\`\\([ \t]*\\)" current)
                              (match-string 1 current) ""))
                 (block   (dl-satan-tools-atsatan--render-block
                           file run-id comment))
                 (block-text (mapconcat (lambda (l) (concat indent l))
                                        block "\n")))
            (delete-region line-start line-end)
            (goto-char line-start)
            (insert replaced "\n" block-text)
            (write-region (point-min) (point-max) file nil 'silent)
            (cons 'ok (list :match-id id :status "done")))))))))

(defun dl-satan-tool/notes-at-satan-scan (args _ctx)
  "Implements notes_at_satan_scan. Returns (ok PLIST) | (error STR)."
  (let* ((ctx-lines (dl-satan-tools-atsatan--clamp
                     (plist-get args :context-lines)
                     dl-satan-tools-atsatan-default-context-lines
                     0 dl-satan-tools-atsatan--context-max))
         (max-res   (dl-satan-tools-atsatan--clamp
                     (plist-get args :max-results)
                     30 1 dl-satan-tools-atsatan--results-max))
         (glob      (or (plist-get args :path-glob)
                        dl-satan-tools-atsatan--default-path-glob))
         (argv      (dl-satan-tools-atsatan--rg-argv max-res glob))
         (run       (dl-satan-tools-atsatan--run-rg argv))
         (exit      (plist-get run :exit)))
    (cond
     ;; rg exits 1 when no matches; that is success-with-empty for us.
     ((not (memql exit '(0 1)))
      (cons 'error (format "rg failed: exit=%s %s"
                           exit (string-trim (plist-get run :stderr)))))
     (t
      (let* ((raw     (dl-satan-tools-atsatan--parse-matches
                       (plist-get run :stdout)))
             (capped  (if (> (length raw) max-res)
                          (cl-subseq raw 0 max-res)
                        raw))
             (truncated (> (length raw) max-res))
             (enriched (dl-satan-tools-atsatan--enrich capped ctx-lines)))
        (dl-satan-tools-atsatan--remember enriched)
        (cons 'ok
              (list :scope "notes_at_satan_scan"
                    :root dl-satan-tools-atsatan-root
                    :context-lines ctx-lines
                    :max-results max-res
                    :count (length enriched)
                    :truncated truncated
                    :matches enriched)))))))

(defun dl-satan-tools-atsatan--patch-job-comment (job-id existing)
  "Compose the comment string when :patch-job=JOB-ID is set.
EXISTING is the model-supplied :comment (or nil).  Returns the
final tagged comment passed to the renderer."
  (let ((base (format "patch-job: queued %s" job-id)))
    (if (and existing
             (not (string-empty-p (string-trim existing))))
        (concat base "\n" (string-trim existing))
      base)))

(defun dl-satan-tool/notes-at-satan-done (args ctx)
  "Implements notes_at_satan_done. Returns (ok PLIST) | (error STR).
Refused unless TOOL-CTX `:capabilities' includes `write-notes'.
Idempotent: claiming an already-done line returns :status \"already-done\".

When ARGS contains `:patch-job', the on-disk block is prefixed with a
`patch-job: queued <id>' tag; subsequent scans skip the line as
already-claimed (per `@satan-was-here').  The line is *not*
auto-rewritten when the patch later completes — the patch-ready inbox
item is the canonical user-facing surface for the result."
  (let* ((id      (plist-get args :match-id))
         (comment (plist-get args :comment))
         (patch-job (plist-get args :patch-job))
         (effective-comment
          (if patch-job
              (dl-satan-tools-atsatan--patch-job-comment patch-job comment)
            comment))
         (caps    (plist-get ctx :capabilities))
         (run-id  (plist-get ctx :id))
         (pair    (gethash id dl-satan-tools-atsatan--id-index)))
    (cond
     ((not (memq 'write-notes caps))
      (cons 'error "mode lacks capability write-notes"))
     ((not (stringp id))
      (cons 'error "match-id must be string"))
     ((null pair)
      (cons 'error (format "unknown match-id: %s (no prior scan in this session)" id)))
     ((not (file-exists-p (car pair)))
      (cons 'error (format "file no longer exists: %s" (car pair))))
     (t
      (let* ((file (car pair))
             (line (cdr pair)))
        (dl-satan-tools-atsatan--rewrite-line file line run-id effective-comment))))))

(dl-satan-tool-register
 (list :name "notes_at_satan_scan"
       :risk 'read
       :args-schema '(context-lines (:type integer :required nil)
                      max-results   (:type integer :required nil)
                      path-glob     (:type string  :required nil))
       :handler 'dl-satan-tool/notes-at-satan-scan))

(dl-satan-tool-register
 (list :name "notes_at_satan_done"
       :risk 'low
       :args-schema '(match-id  (:type string :required t)
                      comment   (:type string :required nil)
                      patch-job (:type string :required nil))
       :handler 'dl-satan-tool/notes-at-satan-done))

(dl-satan-tick-register
 "agent"
 :tools '("notes_at_satan_scan" "notes_at_satan_done"
          "org_read_context"
          "inbox_append"
          "hippocampus_write"
          "memory_mark" "memory_resonate" "memory_show_trace"
          "bough_read"
          "agenda_read"
          "patch_job_create" "patch_job_status")
 :capabilities '(write-notes inbox-write memory-write)
 :budget-tokens 100000
 :budget-tool-calls 15
 :timeout-seconds 120)

(provide 'dl-satan-tools-atsatan)
;;; dl-satan-tools-atsatan.el ends here
