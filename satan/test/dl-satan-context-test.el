;;; dl-satan-context-test.el --- ert tests for dl-satan-context recent-runs -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/lisp -L ~/.emacs.d/org \
;;     -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-context-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-broker)               ; defines `dl-satan-runs-dir' defcustom
(require 'dl-satan-context)

(defun dl-satan-context-test--mkrun (root run-id &optional final-summary tools failed)
  "Create a fake run directory under ROOT for RUN-ID.
TOOLS is an alist (NAME . COUNT) of tool-call lines to fabricate.
When FAILED is non-nil the directory name carries the `.FAILED' suffix."
  (let* ((bucket (concat (substring run-id 0 4) "-"
                         (substring run-id 4 6) "-"
                         (substring run-id 6 8)))
         (leaf (if failed (concat run-id ".FAILED") run-id))
         (dir (expand-file-name (concat bucket "/" leaf) root)))
    (make-directory dir t)
    ;; final.json — successful runs include a summary; failed runs may not.
    (when final-summary
      (with-temp-file (expand-file-name "final.json" dir)
        (insert (json-serialize
                 (list :type "final" :summary final-summary :actions (make-hash-table))))))
    ;; transcript.jsonl — one line per tool call (plus a non-tool line for noise).
    (with-temp-file (expand-file-name "transcript.jsonl" dir)
      (insert (json-serialize
               (list :ts "2026-05-21T00:00:00+1000"
                     :dir "in" :event "ready"
                     :payload (list :type "ready" :run_id run-id))))
      (insert "\n")
      (dolist (entry tools)
        (let ((name (car entry))
              (count (cdr entry)))
          (dotimes (_ count)
            (insert (json-serialize
                     (list :ts "2026-05-21T00:00:01+1000"
                           :dir "in" :event "tool-call"
                           :payload (list :type "tool_call"
                                          :id "call_x"
                                          :name name
                                          :args (make-hash-table)))))
            (insert "\n")))))
    dir))

(defmacro dl-satan-context-test--with-runs-root (var &rest body)
  "Bind VAR to a fresh temp runs root, evaluate BODY, then delete the tree."
  (declare (indent 1))
  `(let ((,var (make-temp-file "satan-context-test-runs-" t)))
     (unwind-protect (progn ,@body)
       (delete-directory ,var t))))

;; ---------- --list-recent-runs ----------

(ert-deftest dl-satan-context/list-recent-runs/returns-newest-first ()
  (dl-satan-context-test--with-runs-root root
    (dl-satan-context-test--mkrun root "20260520T100000-tick-pulse-aaaaaa" "old")
    (dl-satan-context-test--mkrun root "20260521T080000-morning-bbbbbb" "mid")
    (dl-satan-context-test--mkrun root "20260521T130000-tick-pulse-cccccc" "new")
    (let ((dl-satan-runs-dir root))
      (let ((dirs (dl-satan-context--list-recent-runs 3)))
        (should (equal (length dirs) 3))
        (should (string-match-p "tick-pulse-cccccc" (nth 0 dirs)))
        (should (string-match-p "morning-bbbbbb" (nth 1 dirs)))
        (should (string-match-p "tick-pulse-aaaaaa" (nth 2 dirs)))))))

(ert-deftest dl-satan-context/list-recent-runs/honours-n ()
  (dl-satan-context-test--with-runs-root root
    (dotimes (i 6)
      (dl-satan-context-test--mkrun
       root
       (format "20260521T%02d0000-tick-pulse-%06d" (1+ i) i)
       (format "run %d" i)))
    (let ((dl-satan-runs-dir root))
      (should (equal (length (dl-satan-context--list-recent-runs 3)) 3))
      (should (equal (length (dl-satan-context--list-recent-runs 100)) 6)))))

(ert-deftest dl-satan-context/list-recent-runs/empty-or-missing-yields-nil ()
  (let ((dl-satan-runs-dir "/nonexistent/path/that/should/not/exist"))
    (should (null (dl-satan-context--list-recent-runs 5))))
  (dl-satan-context-test--with-runs-root root
    (let ((dl-satan-runs-dir root))
      (should (null (dl-satan-context--list-recent-runs 5))))))

(ert-deftest dl-satan-context/list-recent-runs/skips-non-bucket-entries ()
  "`most-recent' symlinks and stray files at the runs root must be ignored."
  (dl-satan-context-test--with-runs-root root
    (dl-satan-context-test--mkrun root "20260521T100000-tick-pulse-aaaaaa" "ok")
    (write-region "" nil (expand-file-name "stray.txt" root))
    (make-symbolic-link "2026-05-21/20260521T100000-tick-pulse-aaaaaa"
                        (expand-file-name "most-recent" root) t)
    (let ((dl-satan-runs-dir root))
      (let ((dirs (dl-satan-context--list-recent-runs 5)))
        (should (equal (length dirs) 1))
        (should (string-match-p "tick-pulse-aaaaaa" (car dirs)))))))

;; ---------- --summarize-run ----------

(ert-deftest dl-satan-context/summarize-run/extracts-time-mode-summary-tools ()
  (dl-satan-context-test--with-runs-root root
    (let* ((dir (dl-satan-context-test--mkrun
                 root "20260521T125543-tick-pulse-80e9e6"
                 "User in Slack. Nothing to mark."
                 '(("activity_read" . 1) ("memory_resonate" . 2)))))
      (let ((entry (dl-satan-context--summarize-run dir)))
        (should (equal (plist-get entry :when) "2026-05-21 12:55"))
        (should (equal (plist-get entry :mode) "tick-pulse"))
        (should (equal (plist-get entry :status) "ok"))
        (should (equal (plist-get entry :summary) "User in Slack. Nothing to mark."))
        (should (equal (plist-get entry :tools)
                       '(("activity_read" . 1) ("memory_resonate" . 2))))))))

(ert-deftest dl-satan-context/summarize-run/handles-failed-with-no-final ()
  (dl-satan-context-test--with-runs-root root
    (let* ((dir (dl-satan-context-test--mkrun
                 root "20260521T090000-morning-cccccc"
                 nil nil t)))
      (let ((entry (dl-satan-context--summarize-run dir)))
        (should (equal (plist-get entry :status) "FAILED"))
        (should (equal (plist-get entry :mode) "morning"))
        (should (null (plist-get entry :summary)))))))

(ert-deftest dl-satan-context/summarize-run/excludes-satan-final-from-tools ()
  (dl-satan-context-test--with-runs-root root
    (let* ((dir (dl-satan-context-test--mkrun
                 root "20260521T100000-tick-pulse-aaaaaa"
                 "summary"
                 '(("activity_read" . 1) ("satan_final" . 1)))))
      (let ((entry (dl-satan-context--summarize-run dir)))
        (should (equal (plist-get entry :tools)
                       '(("activity_read" . 1))))))))

(ert-deftest dl-satan-context/summarize-run/clips-long-summary ()
  (dl-satan-context-test--with-runs-root root
    (let* ((long (make-string 600 ?x))
           (dir (dl-satan-context-test--mkrun
                 root "20260521T100000-tick-pulse-aaaaaa" long)))
      (let* ((entry (dl-satan-context--summarize-run dir))
             (s (plist-get entry :summary)))
        (should (<= (length s) 280))
        (should (string-suffix-p "…" s))))))

;; ---------- --render-recent-runs ----------

(ert-deftest dl-satan-context/render-recent-runs/nil-when-no-entries ()
  (let ((framing '(("recent_runs" . "# Recent SATAN runs"))))
    (should (null (dl-satan-context--render-recent-runs framing nil)))))

(ert-deftest dl-satan-context/render-recent-runs/renders-block ()
  (let* ((framing '(("recent_runs" . "# Recent SATAN runs")))
         (entries (list
                   (list :when "2026-05-21 12:55" :mode "tick-pulse"
                         :status "ok" :summary "User in Slack."
                         :tools '(("activity_read" . 1)))
                   (list :when "2026-05-21 09:00" :mode "morning"
                         :status "FAILED" :summary nil :tools nil)))
         (lines (dl-satan-context--render-recent-runs framing entries))
         (text  (mapconcat #'identity lines "\n")))
    (should (equal (car lines) "# Recent SATAN runs"))
    (should (string-match-p "\\[2026-05-21 12:55\\] tick-pulse: User in Slack\\." text))
    (should (string-match-p "tools: activity_read×1" text))
    (should (string-match-p "\\[2026-05-21 09:00\\] morning (FAILED)" text))))

;; ---------- End-to-end via context-fn ----------

(ert-deftest dl-satan-context/tick-emits-block-when-recent-runs-set ()
  (dl-satan-context-test--with-runs-root root
    (dl-satan-context-test--mkrun
     root "20260521T125543-tick-pulse-80e9e6"
     "Earlier tick observation."
     '(("activity_read" . 1)))
    (let* ((dl-satan-runs-dir root)
           ;; The mode-prompt and scaffold come from disk; let the context
           ;; function fail loudly if framing.txt lacks the recent_runs key
           ;; so the test catches that drift.
           (spec (list :name "tick-pulse"
                       :recent-runs 5
                       :prompt-file (or (locate-file "tick/pulse.txt"
                                                    (list (expand-file-name
                                                           "satan/prompts"
                                                           (or (bound-and-true-p dl-notes-root)
                                                               (expand-file-name "~/notes")))))
                                        (error "tick/pulse.txt prompt missing from notes"))))
           (bundle (dl-satan-context-tick spec))
           (prompt (plist-get bundle :prompt)))
      (should (string-match-p "# Recent SATAN runs" prompt))
      (should (string-match-p "tick-pulse: Earlier tick observation\\." prompt)))))

(ert-deftest dl-satan-context/tick-omits-block-when-recent-runs-unset ()
  (dl-satan-context-test--with-runs-root root
    (dl-satan-context-test--mkrun
     root "20260521T125543-tick-pulse-80e9e6"
     "Earlier tick observation."
     '(("activity_read" . 1)))
    (let* ((dl-satan-runs-dir root)
           (spec (list :name "tick-pulse"
                       :prompt-file (or (locate-file "tick/pulse.txt"
                                                    (list (expand-file-name
                                                           "satan/prompts"
                                                           (or (bound-and-true-p dl-notes-root)
                                                               (expand-file-name "~/notes")))))
                                        (error "tick/pulse.txt prompt missing from notes"))))
           (bundle (dl-satan-context-tick spec))
           (prompt (plist-get bundle :prompt)))
      (should-not (string-match-p "# Recent SATAN runs" prompt)))))

(provide 'dl-satan-context-test)
;;; dl-satan-context-test.el ends here
