;;; dl-satan-test.el --- ert tests for SATAN -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     --eval "(require 'package)" \
;;     -l dl-satan-test.el -f ert-run-tests-batch-and-exit
;;
;; Or interactively: M-x ert RET t RET.

(require 'ert)
(require 'cl-lib)
(require 'json)
(require 'dl-secret)
(require 'dl-satan-jsonl)
(require 'dl-satan-protocol)
(require 'dl-satan-block)
(require 'dl-satan-tools)
(require 'dl-satan-tools-notify)
(require 'dl-satan-tools-hippocampus)
(require 'dl-satan-tools-inbox)
(require 'dl-satan-tools-org)
(require 'dl-satan-tools-agenda)
(require 'dl-satan-tools-activity)
(require 'dl-satan-tools-notes)
(require 'dl-satan-tools-atsatan)
(require 'dl-satan-tools-sway)
(require 'dl-satan-tools-docs)
(require 'dl-satan-tools-memory)
(require 'dl-satan-tools-motive)
(require 'dl-satan-tools-bough)
(require 'dl-satan-memory)
(require 'dl-satan-context)
(require 'dl-satan-output)
(require 'dl-satan-audit)
(require 'dl-satan-broker)
(require 'dl-satan-budget)
(require 'dl-satan-mode)
(require 'dl-satan-tick)
(require 'dl-satan-percept-test)

;; Shared helpers still used by remaining sections (context :now,
;; context framing rendering).  Move with the next context-test
;; extraction batch.
(defun dl-satan-test--path-suffix-p (suffix sources)
  (cl-some (lambda (s) (string-suffix-p suffix (plist-get s :path)))
           sources))

(defun dl-satan-test--write-framing (path)
  "Write the canonical framing keys to PATH for context-fn tests."
  (with-temp-file path
    (insert "now=# Now\n"
            "today=# Today (raw)\n"
            "sources=# Source files\n")))

(defun dl-satan-test--with-tool-descriptions (alist body-fn)
  "Run BODY-FN with `dl-satan-tools-descriptions-dir' bound to a tmp dir
populated from ALIST `((NAME . CONTENT) …)'.  Still used by remaining
broker manifest + budget sections; will move with those extractions."
  (let ((tmp (make-temp-file "satan-tools-" t)))
    (unwind-protect
        (let ((dl-satan-tools-descriptions-dir tmp))
          (dolist (pair alist)
            (with-temp-file (expand-file-name (concat (car pair) ".md") tmp)
              (insert (cdr pair))))
          (funcall body-fn))
      (delete-directory tmp t))))

;; ---------- dl-satan-context :now ----------

(ert-deftest dl-satan-context/now-plist-shape ()
  "`:now' carries every key the harness renders into `# Now'."
  (let* ((time (encode-time 0 30 14 19 5 2026 nil nil 36000)) ; +1000
         (now (dl-satan-context-now time)))
    (should (stringp (plist-get now :iso_date)))
    (should (string-match-p "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\'"
                            (plist-get now :iso_date)))
    (should (stringp (plist-get now :weekday)))
    (should (string-match-p "\\`[0-9]\\{4\\}-W[0-9]\\{2\\}\\'"
                            (plist-get now :iso_week)))
    (should (string-match-p "\\`[0-9]\\{2\\}:[0-9]\\{2\\}\\'"
                            (plist-get now :time)))
    (should (stringp (plist-get now :tz_offset)))
    (should (stringp (plist-get now :tz_name)))))

(ert-deftest dl-satan-context/motd-bundle-carries-now ()
  (let* ((tmp (make-temp-file "satan-now-" t))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "system" tmp))
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/p.txt" tmp) (insert "P"))
          (let* ((spec (list :name "motd"
                             :prompt-file (expand-file-name "prompts/p.txt" tmp)))
                 (bundle (dl-satan-context-motd spec))
                 (now (plist-get bundle :now)))
            (should (plistp now))
            (should (stringp (plist-get now :iso_date)))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/tick-bundle-carries-now ()
  (let* ((tmp (make-temp-file "satan-now-" t))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "system" tmp))
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/p.txt" tmp) (insert "P"))
          (let* ((spec (list :name "tick-pulse"
                             :prompt-file (expand-file-name "prompts/p.txt" tmp)))
                 (bundle (dl-satan-context-tick spec))
                 (now (plist-get bundle :now)))
            (should (plistp now))
            (should (stringp (plist-get now :time)))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/self-edit-bundle-carries-now ()
  (let* ((tmp (make-temp-file "satan-now-" t))
         (root (expand-file-name "rrr" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory root t)
          (make-directory (expand-file-name "system" tmp))
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          (with-temp-file (expand-file-name "only.el" root) (insert "x"))
          (let* ((spec (list :name "self-edit-mech"
                             :prompt-file (expand-file-name "prompts/se.txt" tmp)
                             :source-roots (list root)))
                 (bundle (dl-satan-context-self-edit spec))
                 (now (plist-get bundle :now)))
            (should (plistp now))
            (should (stringp (plist-get now :iso_date)))))
      (delete-directory tmp t))))

;; ---------- dl-satan-context framing rendering ----------

(defun dl-satan-test--with-framing (body-fn)
  "Run BODY-FN with `dl-satan-system-framing-file' bound to a temp file."
  (let* ((tmp (make-temp-file "satan-framing-" t))
         (path (expand-file-name "framing.txt" tmp)))
    (unwind-protect
        (let ((dl-satan-system-framing-file path))
          (dl-satan-test--write-framing path)
          (funcall body-fn))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/framing-parses-key-value ()
  (let ((alist (dl-satan-context--parse-framing
                "# comment\nnow=# Now\n\ntoday=# Today (raw)\nsources=# Source files\n")))
    (should (equal (cdr (assoc "now" alist)) "# Now"))
    (should (equal (cdr (assoc "today" alist)) "# Today (raw)"))
    (should (equal (cdr (assoc "sources" alist)) "# Source files"))))

(ert-deftest dl-satan-context/framing-missing-key-errors ()
  (let* ((tmp (make-temp-file "satan-framing-" t))
         (path (expand-file-name "framing.txt" tmp))
         (dl-satan-system-framing-file path))
    (unwind-protect
        (progn
          (with-temp-file path (insert "now=# Now\n"))
          (should-error (dl-satan-context--framing) :type 'error))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/framing-missing-file-errors ()
  (let ((dl-satan-system-framing-file "/tmp/satan-framing-does-not-exist-XYZ.txt"))
    (should-error (dl-satan-context--framing) :type 'error)))

(ert-deftest dl-satan-context/render-prompt-now-block ()
  "Rendered prompt prepends scaffold+mode and emits a `# Now' block."
  (dl-satan-test--with-framing
   (lambda ()
     (let* ((bundle (list :now (list :iso_date "2026-05-19"
                                     :weekday "Tuesday"
                                     :iso_week "2026-W21"
                                     :time "09:00"
                                     :tz_offset "+1000"
                                     :tz_name "AEST")))
            (out (dl-satan-context--render-prompt "ASSEMBLED" bundle)))
       (should (string-prefix-p "ASSEMBLED\n\n# Now\n" out))
       (should (string-match-p "^date: 2026-05-19 (Tuesday, ISO 2026-W21)$" out))
       (should (string-match-p "^time: 09:00 \\+1000 AEST$" out))))))

(ert-deftest dl-satan-context/render-prompt-skips-empty-now ()
  "Missing or empty `:now' produces no `# Now' header."
  (dl-satan-test--with-framing
   (lambda ()
     (let ((out (dl-satan-context--render-prompt "ASSEMBLED" '())))
       (should (equal out "ASSEMBLED"))
       (should-not (string-match-p "^# Now$" out))))))

(ert-deftest dl-satan-context/render-prompt-today-block ()
  "Non-empty `:today_text' produces a `# Today (raw)' block; empty skips."
  (dl-satan-test--with-framing
   (lambda ()
     (let ((with-today (dl-satan-context--render-prompt
                       "ASSEMBLED" (list :today_text "body text"))))
       (should (string-match-p "# Today (raw)\nbody text" with-today)))
     (let ((sans-today (dl-satan-context--render-prompt
                       "ASSEMBLED" (list :today_text ""))))
       (should-not (string-match-p "# Today (raw)" sans-today))))))

(ert-deftest dl-satan-context/render-prompt-sources-block ()
  "Each source emits a fenced `## PATH' subsection under `# Source files'."
  (dl-satan-test--with-framing
   (lambda ()
     (let* ((sources (list (list :path "satan/x.el" :content "(provide 'x)")
                           (list :path "satan/y.py" :content "x = 1")))
            (out (dl-satan-context--render-prompt
                  "ASSEMBLED" (list :sources sources))))
       (should (string-match-p "^# Source files$" out))
       (should (string-match-p "^## satan/x.el$" out))
       (should (string-match-p "(provide 'x)" out))
       (should (string-match-p "^## satan/y.py$" out))
       (should (string-match-p "^x = 1$" out))))))

(ert-deftest dl-satan-context/render-prompt-section-ordering ()
  "Sections render in canonical order: Now, then Today, then Source files."
  (dl-satan-test--with-framing
   (lambda ()
     (let* ((bundle (list :now (list :iso_date "2026-05-19" :time "09:00")
                          :today_text "BODY"
                          :sources (list (list :path "p" :content "c"))))
            (out (dl-satan-context--render-prompt "A" bundle))
            (i-now    (string-match "^# Now$"          out))
            (i-today  (string-match "^# Today (raw)$"  out))
            (i-source (string-match "^# Source files$" out)))
       (should i-now)
       (should i-today)
       (should i-source)
       (should (< i-now i-today))
       (should (< i-today i-source))))))

;; ---------- dl-satan-protocol ----------

(defun dl-satan-test--protocol-fixture-direction (entry)
  (intern (plist-get entry :direction)))

(defun dl-satan-test--wire-fixture-p (entry)
  "Non-nil when ENTRY is a wire-protocol fixture (direction in|out).
Skips Phase-0.4 `actions' fixtures which are validated by
`dl-satan-audit-validate-actions', not the wire protocol module."
  (member (plist-get entry :direction) '("in" "out")))

(ert-deftest dl-satan-protocol/fixtures-valid-pass ()
  "Every wire fixture marked `valid' validates clean."
  (dolist (entry (dl-satan-protocol-fixtures))
    (when (and (string= (plist-get entry :kind) "valid")
               (dl-satan-test--wire-fixture-p entry))
      (let* ((direction (dl-satan-test--protocol-fixture-direction entry))
             (msg (plist-get entry :message))
             (err (dl-satan-protocol-validate direction msg)))
        (should (null err))))))

(ert-deftest dl-satan-protocol/fixtures-invalid-fail ()
  "Every wire fixture marked `invalid' validates to a matching reason."
  (dolist (entry (dl-satan-protocol-fixtures))
    (when (and (string= (plist-get entry :kind) "invalid")
               (dl-satan-test--wire-fixture-p entry))
      (let* ((direction (dl-satan-test--protocol-fixture-direction entry))
             (msg (plist-get entry :message))
             (expected (plist-get entry :reason))
             (name (plist-get entry :name))
             (err (dl-satan-protocol-validate direction msg)))
        (should (not (null err)))
        (should
         (equal expected (plist-get err :reason)))
        (ignore name)))))

(ert-deftest dl-satan-audit/fixtures-actions-valid-pass ()
  "Every actions fixture marked `valid' passes `validate-actions'.
Asserts the suite is non-empty so a fixture-file regression is loud."
  (let ((seen 0))
    (dolist (entry (dl-satan-protocol-fixtures))
      (when (and (string= (plist-get entry :kind) "valid")
                 (string= (plist-get entry :direction) "actions"))
        (cl-incf seen)
        (let* ((msg (plist-get entry :message))
               (err (dl-satan-audit-validate-actions msg))
               (name (plist-get entry :name)))
          (should (null err))
          (ignore name))))
    (should (> seen 0))))

(ert-deftest dl-satan-audit/fixtures-actions-invalid-fail ()
  "Every actions fixture marked `invalid' fails with the fixture's reason."
  (let ((seen 0))
    (dolist (entry (dl-satan-protocol-fixtures))
      (when (and (string= (plist-get entry :kind) "invalid")
                 (string= (plist-get entry :direction) "actions"))
        (cl-incf seen)
        (let* ((msg (plist-get entry :message))
               (expected (plist-get entry :reason))
               (name (plist-get entry :name))
               (err (dl-satan-audit-validate-actions msg)))
          (should (stringp err))
          (should (equal expected err))
          (ignore name))))
    (should (> seen 0))))

(ert-deftest dl-satan-protocol/rejects-bad-direction ()
  (should-error (dl-satan-protocol-validate 'sideways
                                            '(:type "ready" :run_id "x"))))

(ert-deftest dl-satan-protocol/tool-result-ok-true-passes ()
  (should (null (dl-satan-protocol-validate
                 'out
                 '(:type "tool_result" :id "c1" :ok t :result (:content ""))))))

(ert-deftest dl-satan-protocol/tool-result-ok-false-passes ()
  (should (null (dl-satan-protocol-validate
                 'out
                 '(:type "tool_result" :id "c1" :ok :false :error "denied")))))

(provide 'dl-satan-test)
;;; dl-satan-test.el ends here
