;;; dl-satan-audit.el --- SATAN run audit log + verifier -*- lexical-binding: t; -*-

;; Append-only artifacts under runs/<run-id>/:
;;   manifest.json    mode / tools / harness / jail / start
;;   bundle.json      frozen input bundle
;;   transcript.jsonl one JSON object per line; :dir in|out|broker, :event, :payload
;;   final.json       validated final from harness, or {status: invalid}
;;   actions.json     {applied, staged, rejected, failed}
;;   stdout.log       raw child stdout (broker tees here)
;;   stderr.log       raw child stderr (process :stderr buffer)
;;   status           terminal: done|failed|timed-out|invalid-protocol
;;
;; `dl-satan-audit-verify-run' answers the six predicates that together prove
;; the SATAN auditability invariant (SATAN.local.md:601-616).

(require 'cl-lib)
(require 'json)
(require 'subr-x)
(require 'dl-satan-jsonl)

(cl-defstruct dl-satan-audit-handle
  dir
  transcript-path
  last-ts)

(defun dl-satan-audit--iso-now ()
  "Return current time as ISO-8601 with microseconds + zone."
  (format-time-string "%Y-%m-%dT%H:%M:%S.%6N%z" nil))

(defun dl-satan-audit--write-json (path obj)
  "Write OBJ as JSON to PATH (utf-8, no backup, atomic via rename)."
  (let ((tmp (concat path ".tmp"))
        (coding-system-for-write 'utf-8))
    (with-temp-file tmp
      (insert (json-serialize (dl-satan-jsonl-prepare obj)
                              :null-object :null :false-object :false)))
    (rename-file tmp path t)))

(defun dl-satan-audit--append-line (path line)
  "Append LINE plus newline to PATH."
  (let ((coding-system-for-write 'utf-8))
    (write-region (concat line "\n") nil path 'append 'silent)))

(defun dl-satan-audit-open (dir manifest bundle)
  "Create DIR, write MANIFEST and BUNDLE plists, return an audit handle."
  (unless (file-directory-p dir) (make-directory dir t))
  (dl-satan-audit--write-json (expand-file-name "manifest.json" dir) manifest)
  (dl-satan-audit--write-json (expand-file-name "bundle.json"   dir) bundle)
  (let ((tp (expand-file-name "transcript.jsonl" dir)))
    (with-temp-file tp (insert ""))
    (make-dl-satan-audit-handle :dir dir :transcript-path tp :last-ts nil)))

(defun dl-satan-audit-record (handle dir event payload)
  "Append a transcript record.
DIR ∈ in|out|broker.  EVENT is a symbol.  PAYLOAD is a plist/list/string."
  (let* ((ts (dl-satan-audit--iso-now))
         (rec (list :ts ts
                    :dir (symbol-name dir)
                    :event (symbol-name event)
                    :payload (or payload :null))))
    (setf (dl-satan-audit-handle-last-ts handle) ts)
    (dl-satan-audit--append-line
     (dl-satan-audit-handle-transcript-path handle)
     (json-serialize (dl-satan-jsonl-prepare rec)
                     :null-object :null :false-object :false))))

(defun dl-satan-audit-close (handle final actions status)
  "Finalize the run.
FINAL is a plist (or nil).  ACTIONS is a plist with the four partition keys
\(:applied :staged :rejected :failed).  STATUS is a symbol."
  (let ((dir (dl-satan-audit-handle-dir handle)))
    (dl-satan-audit--write-json
     (expand-file-name "final.json" dir)
     (or final (list :status "invalid")))
    (dl-satan-audit--write-json
     (expand-file-name "actions.json" dir)
     (list :applied  (or (plist-get actions :applied)  [])
           :staged   (or (plist-get actions :staged)   [])
           :rejected (or (plist-get actions :rejected) [])
           :failed   (or (plist-get actions :failed)   [])))
    (let ((coding-system-for-write 'utf-8))
      (write-region (concat (symbol-name status) "\n") nil
                    (expand-file-name "status" dir) nil 'silent))))

;; ---------- Verifier ----------

(defun dl-satan-audit--read-json (path)
  "Read PATH as JSON, return plist or signal."
  (let ((coding-system-for-read 'utf-8))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (json-parse-buffer :object-type 'plist
                         :array-type 'list
                         :null-object :null
                         :false-object :false))))

(defun dl-satan-audit--read-jsonl (path)
  "Read PATH as JSONL, return list of plists in order."
  (let ((coding-system-for-read 'utf-8))
    (with-temp-buffer
      (insert-file-contents path)
      (goto-char (point-min))
      (let (out)
        (while (not (eobp))
          (let ((line (buffer-substring-no-properties
                       (point) (line-end-position))))
            (unless (string-empty-p (string-trim line))
              (push (json-parse-string line
                                       :object-type 'plist
                                       :array-type 'list
                                       :null-object :null
                                       :false-object :false)
                    out))
            (forward-line 1)))
        (nreverse out)))))

(defun dl-satan-audit-p/has-manifest (dir)
  (and (file-readable-p (expand-file-name "manifest.json" dir))
       (ignore-errors (dl-satan-audit--read-json
                       (expand-file-name "manifest.json" dir)))
       t))

(defun dl-satan-audit-p/has-bundle (dir)
  (and (file-readable-p (expand-file-name "bundle.json" dir))
       (ignore-errors (dl-satan-audit--read-json
                       (expand-file-name "bundle.json" dir)))
       t))

(defun dl-satan-audit-p/transcript-monotonic (dir)
  (let ((records (dl-satan-audit--read-jsonl
                  (expand-file-name "transcript.jsonl" dir)))
        (prev nil)
        (ok t))
    (dolist (r records)
      (let ((ts (plist-get r :ts)))
        (when (and prev (string< ts prev)) (setq ok nil))
        (setq prev ts)))
    ok))

(defun dl-satan-audit-p/calls-match-results (dir)
  "Every tool-call id has a matching tool-result id."
  (let ((records (dl-satan-audit--read-jsonl
                  (expand-file-name "transcript.jsonl" dir)))
        (calls (make-hash-table :test 'equal))
        (results (make-hash-table :test 'equal)))
    (dolist (r records)
      (let ((ev (plist-get r :event))
            (p  (plist-get r :payload)))
        (cond
         ((equal ev "tool-call")
          (when-let ((id (plist-get p :id))) (puthash id t calls)))
         ((or (equal ev "tool-result") (equal ev "tool-denied"))
          (when-let ((id (plist-get p :id))) (puthash id t results))))))
    (let ((ok t))
      (maphash (lambda (id _) (unless (gethash id results) (setq ok nil))) calls)
      ok)))

(defun dl-satan-audit-p/actions-partition-final (dir)
  "Union of applied|staged|rejected|failed equals final.actions (count)."
  (let* ((final   (ignore-errors
                    (dl-satan-audit--read-json
                     (expand-file-name "final.json" dir))))
         (actions (ignore-errors
                    (dl-satan-audit--read-json
                     (expand-file-name "actions.json" dir))))
         (fa (and final (plist-get final :actions)))
         (sum (+ (length (or (plist-get actions :applied)  '()))
                 (length (or (plist-get actions :staged)   '()))
                 (length (or (plist-get actions :rejected) '()))
                 (length (or (plist-get actions :failed)   '())))))
    (cond
     ((null final) nil)
     ((eq fa :null) (= 0 sum))
     ((listp fa) (= (length fa) sum))
     (t nil))))

(defun dl-satan-audit-p/status-terminal (dir)
  (let ((p (expand-file-name "status" dir)))
    (and (file-readable-p p)
         (let ((s (string-trim
                   (with-temp-buffer
                     (insert-file-contents p) (buffer-string)))))
           (member s '("done" "failed" "timed-out" "invalid-protocol"))))))

(defun dl-satan-audit-verify-run (dir)
  "Return t if all six audit predicates pass for DIR.
Otherwise return an alist of (PREDICATE-SYMBOL . nil) pairs."
  (let ((checks
         (list
          (cons 'has-manifest        (dl-satan-audit-p/has-manifest dir))
          (cons 'has-bundle          (dl-satan-audit-p/has-bundle dir))
          (cons 'transcript-monotonic (dl-satan-audit-p/transcript-monotonic dir))
          (cons 'calls-match-results (dl-satan-audit-p/calls-match-results dir))
          (cons 'actions-partition-final (dl-satan-audit-p/actions-partition-final dir))
          (cons 'status-terminal     (dl-satan-audit-p/status-terminal dir)))))
    (let ((failed (cl-remove-if #'cdr checks)))
      (if (null failed) t failed))))

(provide 'dl-satan-audit)
;;; dl-satan-audit.el ends here
