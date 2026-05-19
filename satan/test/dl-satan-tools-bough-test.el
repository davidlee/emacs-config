;;; dl-satan-tools-bough-test.el --- bough_read tool tests -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-tools-bough-test.el -f ert-run-tests-batch-and-exit
;;
;; Integration tests skip when `bough' is not on PATH.

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools)
(require 'dl-satan-tools-bough)

;; ---------- registration ----------

(ert-deftest dl-satan-bough/registers-bough-read ()
  (should (dl-satan-tool-lookup "bough_read"))
  (let ((spec (dl-satan-tool-lookup "bough_read")))
    (should (eq 'read (plist-get spec :risk)))
    (should (eq 'dl-satan-tool/bough-read (plist-get spec :handler)))))

;; ---------- schema validation ----------

(ert-deftest dl-satan-bough/schema-rejects-unknown-scope ()
  (let* ((spec (dl-satan-tool-lookup "bough_read"))
         (err (dl-satan-tool-validate-args
               spec (list :scope "bogus"))))
    (should err)
    (should (string-match-p "must be one of" err))))

(ert-deftest dl-satan-bough/schema-requires-scope ()
  (let* ((spec (dl-satan-tool-lookup "bough_read"))
         (err (dl-satan-tool-validate-args spec nil)))
    (should err)
    (should (string-match-p "scope" err))))

(ert-deftest dl-satan-bough/schema-rejects-bad-nanoid ()
  (let* ((spec (dl-satan-tool-lookup "bough_read"))
         (err (dl-satan-tool-validate-args
               spec (list :scope "node" :nanoid "has space"))))
    (should err)))

(ert-deftest dl-satan-bough/schema-rejects-bad-date ()
  (let* ((spec (dl-satan-tool-lookup "bough_read"))
         (err (dl-satan-tool-validate-args
               spec (list :scope "day" :date "2026/05/19"))))
    (should err)))

;; ---------- per-scope arg validation ----------

(ert-deftest dl-satan-bough/scope-args-node-requires-nanoid ()
  (should (dl-satan-bough--validate-scope-args "node" nil))
  (should-not (dl-satan-bough--validate-scope-args
               "node" (list :nanoid "0uGrns4"))))

(ert-deftest dl-satan-bough/scope-args-project-subtree-requires-nanoid ()
  (should (dl-satan-bough--validate-scope-args "project_subtree" nil))
  (should-not (dl-satan-bough--validate-scope-args
               "project_subtree" (list :nanoid "0uGrns4"))))

(ert-deftest dl-satan-bough/scope-args-recent-changes-requires-since ()
  (should (dl-satan-bough--validate-scope-args "recent_changes" nil))
  (should-not (dl-satan-bough--validate-scope-args
               "recent_changes" (list :since "2026-05-19T00:00:00Z"))))

(ert-deftest dl-satan-bough/scope-args-active-day-week-need-nothing ()
  (should-not (dl-satan-bough--validate-scope-args "active" nil))
  (should-not (dl-satan-bough--validate-scope-args "day" nil))
  (should-not (dl-satan-bough--validate-scope-args "week" nil)))

;; ---------- week-bounds (pure) ----------

(ert-deftest dl-satan-bough/week-bounds-monday ()
  (should (equal "2026-05-18"
                 (dl-satan-bough--monday-of "2026-05-18"))))

(ert-deftest dl-satan-bough/week-bounds-midweek ()
  (should (equal '("2026-05-18" . "2026-05-24")
                 (dl-satan-bough--week-bounds "2026-05-20"))))

(ert-deftest dl-satan-bough/week-bounds-sunday ()
  ;; Sunday belongs to the prior Monday's week (ISO).
  (should (equal '("2026-05-18" . "2026-05-24")
                 (dl-satan-bough--week-bounds "2026-05-24"))))

;; ---------- prune-depth (pure) ----------

(defun dl-satan-bough-test--tree (n)
  "Build a left-spine tree of N children (each with one child of its own)."
  (let ((leaf (list :nanoid "L" :title "leaf")))
    (cl-loop for i from n downto 1
             for next = leaf then prev
             for prev = (list :nanoid (format "N%d" i)
                              :title (format "n%d" i)
                              :children (list next))
             finally return prev)))

(ert-deftest dl-satan-bough/prune-depth-keeps-root-when-zero ()
  (let* ((tree (dl-satan-bough-test--tree 3))
         (out (dl-satan-bough--prune-depth tree 0 0)))
    (should-not (plist-get out :children))
    (should (= 1 (plist-get out :children_truncated_count)))))

(ert-deftest dl-satan-bough/prune-depth-keeps-within-limit ()
  (let* ((tree (dl-satan-bough-test--tree 4))
         (out  (dl-satan-bough--prune-depth tree 0 2))
         (child (car (plist-get out :children)))
         (gchild (car (plist-get child :children))))
    (should (equal "N1" (plist-get out :nanoid)))
    (should (equal "N2" (plist-get child :nanoid)))
    (should (equal "N3" (plist-get gchild :nanoid)))
    ;; depth 3 truncated
    (should-not (plist-get gchild :children))
    (should (= 1 (plist-get gchild :children_truncated_count)))))

(ert-deftest dl-satan-bough/prune-depth-passes-through-non-plist ()
  (should (equal '(1 2 3) (dl-satan-bough--prune-depth '(1 2 3) 0 5)))
  (should (equal "x"      (dl-satan-bough--prune-depth "x" 0 5))))

;; ---------- handler rejects unknown scope ----------

(ert-deftest dl-satan-bough/handler-rejects-unknown-scope ()
  (let ((res (dl-satan-tool/bough-read (list :scope "nope") nil)))
    ;; Per-scope validator returns nil for unknown scope; the dispatch
    ;; pcase then falls through to the catch-all error.
    (should (eq 'error (car res)))))

;; ---------- integration (skip when bough absent) ----------

(defvar dl-satan-bough-test--bough-ok
  (and (file-executable-p dl-satan-bough-program)))

(ert-deftest dl-satan-bough/active-scope-shape ()
  (skip-unless dl-satan-bough-test--bough-ok)
  (let ((res (dl-satan-tool/bough-read (list :scope "active") nil)))
    (should (eq 'ok (car res)))
    (let ((payload (cdr res)))
      (should (equal "active" (plist-get payload :scope)))
      (should (listp (plist-get payload :nodes))))))

(ert-deftest dl-satan-bough/day-not-found-becomes-ok-nil ()
  (skip-unless dl-satan-bough-test--bough-ok)
  ;; A date far in the past with no day entry.
  (let* ((res (dl-satan-tool/bough-read
               (list :scope "day" :date "1999-01-01") nil))
         (payload (cdr res)))
    (should (eq 'ok (car res)))
    (should (equal "1999-01-01" (plist-get payload :date)))
    (should (null (plist-get payload :day)))))

(ert-deftest dl-satan-bough/week-scope-bounds ()
  (skip-unless dl-satan-bough-test--bough-ok)
  (let* ((res (dl-satan-tool/bough-read
               (list :scope "week" :date "2026-05-20") nil))
         (payload (cdr res)))
    (should (eq 'ok (car res)))
    (should (equal "2026-05-18" (plist-get payload :start_date)))
    (should (equal "2026-05-24" (plist-get payload :end_date)))
    (should (listp (plist-get payload :days)))))

(provide 'dl-satan-tools-bough-test)
;;; dl-satan-tools-bough-test.el ends here
