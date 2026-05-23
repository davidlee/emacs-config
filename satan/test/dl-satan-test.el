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

;; ---------- dl-satan self-edit context + output ----------

(defun dl-satan-test--path-suffix-p (suffix sources)
  (cl-some (lambda (s) (string-suffix-p suffix (plist-get s :path)))
           sources))

(defun dl-satan-test--write-framing (path)
  "Write the canonical framing keys to PATH for context-fn tests.
Context-fns under test render bundle sections via this file."
  (with-temp-file path
    (insert "now=# Now\n"
            "today=# Today (raw)\n"
            "sources=# Source files\n")))

(ert-deftest dl-satan-self-edit/context-bundles-sources ()
  "context-fn assembles scaffold + mode prompt and includes matching sources
from every root in MODE-SPEC's :source-roots."
  (let* ((tmp (make-temp-file "satan-se-" t))
         (root-a (expand-file-name "root-a" tmp))
         (root-b (expand-file-name "root-b" tmp))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory root-a t)
          (make-directory root-b t)
          (make-directory (expand-file-name "prompts" tmp))
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "SCAFFOLD\n"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/se.txt" tmp)
            (insert "PROMPT\n"))
          (with-temp-file (expand-file-name "a.el" root-a) (insert "(provide 'a)"))
          (with-temp-file (expand-file-name "b.py" root-b) (insert "x = 1"))
          (with-temp-file (expand-file-name "a.elc" root-a) (insert "skip"))
          (let* ((spec (list :name "self-edit-mech"
                             :prompt-file (expand-file-name "prompts/se.txt" tmp)
                             :source-roots (list root-a root-b)))
                 (bundle (dl-satan-context-self-edit spec))
                 (prompt (plist-get bundle :prompt))
                 (sources (plist-get bundle :sources)))
            (should (string-prefix-p "SCAFFOLD\n\nPROMPT" prompt))
            (should (string-match-p "^# Now$" prompt))
            (should (string-match-p "^# Source files$" prompt))
            (should (dl-satan-test--path-suffix-p "/a.el" sources))
            (should (dl-satan-test--path-suffix-p "/b.py" sources))
            (should-not (dl-satan-test--path-suffix-p "/a.elc" sources))
            (let ((a (cl-find "/a.el" sources
                              :key (lambda (s) (plist-get s :path))
                              :test (lambda (suf p) (string-suffix-p suf p)))))
              (should (equal (plist-get a :content) "(provide 'a)")))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-self-edit/bundle-budget-drops-overflow ()
  "When sources exceed `dl-satan-self-edit-bundle-char-budget' the
bundle keeps as much as fits in alphabetical order and reports the
rest under :dropped-files."
  (let* ((tmp (make-temp-file "satan-se-budget-" t))
         (root (expand-file-name "r" tmp))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp))
         (dl-satan-self-edit-bundle-char-budget 100))
    (unwind-protect
        (progn
          (make-directory root t)
          (make-directory (expand-file-name "prompts" tmp))
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          ;; Three 60-char files, alphabetical: a, b, c.  Budget = 100.
          ;; a (60) packed.  a+b (120) would overflow → b dropped.
          ;; a+c (120) likewise → c dropped.  Only a fits.
          (with-temp-file (expand-file-name "a.el" root) (insert (make-string 60 ?a)))
          (with-temp-file (expand-file-name "b.el" root) (insert (make-string 60 ?b)))
          (with-temp-file (expand-file-name "c.el" root) (insert (make-string 60 ?c)))
          (let* ((spec (list :name "self-edit-mech"
                             :prompt-file (expand-file-name "prompts/se.txt" tmp)
                             :source-roots (list root)))
                 (bundle (dl-satan-context-self-edit spec))
                 (sources (plist-get bundle :sources))
                 (dropped (plist-get bundle :dropped-files)))
            (should (= 1 (length sources)))
            (should (dl-satan-test--path-suffix-p "/a.el" sources))
            (should (= 2 (length dropped)))
            (should (cl-some (lambda (p) (string-suffix-p "/b.el" p)) dropped))
            (should (cl-some (lambda (p) (string-suffix-p "/c.el" p)) dropped))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-self-edit/bundle-budget-nil-packs-everything ()
  "With the budget set to nil every file is included; :dropped-files is empty."
  (let* ((tmp (make-temp-file "satan-se-nobudget-" t))
         (root (expand-file-name "r" tmp))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp))
         (dl-satan-self-edit-bundle-char-budget nil))
    (unwind-protect
        (progn
          (make-directory root t)
          (make-directory (expand-file-name "prompts" tmp))
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          (with-temp-file (expand-file-name "a.el" root) (insert (make-string 5000 ?a)))
          (with-temp-file (expand-file-name "b.el" root) (insert (make-string 5000 ?b)))
          (let* ((spec (list :name "self-edit-mech"
                             :prompt-file (expand-file-name "prompts/se.txt" tmp)
                             :source-roots (list root)))
                 (bundle (dl-satan-context-self-edit spec))
                 (sources (plist-get bundle :sources))
                 (dropped (plist-get bundle :dropped-files)))
            (should (= 2 (length sources)))
            (should (null dropped))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-self-edit/source-roots-var-indirection ()
  "When :source-roots is absent, context-fn dereferences :source-roots-var."
  (let* ((tmp (make-temp-file "satan-se-" t))
         (root (expand-file-name "rrr" tmp))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-system-framing-file
          (expand-file-name "system/framing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory root t)
          (make-directory (expand-file-name "prompts" tmp))
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (dl-satan-test--write-framing dl-satan-system-framing-file)
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          (with-temp-file (expand-file-name "only.el" root) (insert "x"))
          (defvar dl-satan-test--roots nil)
          (let ((dl-satan-test--roots (list root))
                (spec (list :name "self-edit-mech"
                            :prompt-file (expand-file-name "prompts/se.txt" tmp)
                            :source-roots-var 'dl-satan-test--roots)))
            (should (dl-satan-test--path-suffix-p
                     "/only.el"
                     (plist-get (dl-satan-context-self-edit spec) :sources)))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-self-edit/mech-and-mind-modes-registered-distinctly ()
  "Both lanes resolve, share governance defaults, point at distinct roots."
  (let ((mech (dl-satan-mode-resolve "self-edit-mech"))
        (mind (dl-satan-mode-resolve "self-edit-mind")))
    (should (eq (plist-get mech :auto-apply) 'none))
    (should (eq (plist-get mind :auto-apply) 'none))
    (dolist (tool '("proposal_stage" "sway_border_set" "sway_border_reset"))
      (should (member tool (plist-get mech :tools)))
      (should (member tool (plist-get mind :tools))))
    (should (eq (plist-get mech :source-roots-var) 'dl-satan-self-edit-mech-roots))
    (should (eq (plist-get mind :source-roots-var) 'dl-satan-self-edit-mind-roots))
    (should-not (equal (plist-get mech :prompt-file)
                       (plist-get mind :prompt-file)))))

(ert-deftest dl-satan-context/missing-prompt-errors ()
  "Mode prompt missing → context-fn signals; run cannot start."
  (let* ((tmp (make-temp-file "satan-ctx-" t))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (let ((spec (list :name "self-edit-mech"
                            :prompt-file
                            (expand-file-name "prompts/never.txt" tmp)
                            :source-roots (list tmp))))
            (should-error (dl-satan-context-self-edit spec)
                          :type 'error)))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/missing-scaffold-errors ()
  "System scaffold missing → context-fn signals."
  (let* ((tmp (make-temp-file "satan-ctx-" t))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/missing.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          (let ((spec (list :name "self-edit-mech"
                            :prompt-file
                            (expand-file-name "prompts/se.txt" tmp)
                            :source-roots (list tmp))))
            (should-error (dl-satan-context-self-edit spec)
                          :type 'error)))
      (delete-directory tmp t))))

;; ---------- dl-satan-tools JSON Schema builder ----------

(defun dl-satan-test--with-tool-descriptions (alist body-fn)
  "Run BODY-FN with `dl-satan-tools-descriptions-dir' bound to a tmp dir
populated from ALIST `((NAME . CONTENT) …)'."
  (let ((tmp (make-temp-file "satan-tools-" t)))
    (unwind-protect
        (let ((dl-satan-tools-descriptions-dir tmp))
          (dolist (pair alist)
            (with-temp-file (expand-file-name (concat (car pair) ".md") tmp)
              (insert (cdr pair))))
          (funcall body-fn))
      (delete-directory tmp t))))

(ert-deftest dl-satan-tools/json-schema-from-notes ()
  "json-schema dict pulls description from notes and shape from elisp."
  (dl-satan-test--with-tool-descriptions
   '(("fake.tool" . "Stage a fake test thing.\n\nParams:\n- title: a string."))
   (lambda ()
     (let* ((spec (list :name "fake.tool"
                        :risk 'low
                        :args-schema '(title (:type string :required t)
                                       count (:type integer :required nil))
                        :modes '("morning")
                        :handler (lambda (_a _c) (cons 'ok '()))))
            (js (dl-satan-tool-json-schema spec))
            (fn (plist-get js :function))
            (params (plist-get fn :parameters))
            (props (plist-get params :properties)))
       (should (equal (plist-get js :type) "function"))
       (should (equal (plist-get fn :name) "fake.tool"))
       (should (string-match-p "Stage a fake" (plist-get fn :description)))
       (should (equal (plist-get params :type) "object"))
       (should (equal (plist-get (plist-get props :title) :type) "string"))
       (should (equal (plist-get (plist-get props :count) :type) "integer"))
       (should (equal (append (plist-get params :required) nil) '("title")))))))

(ert-deftest dl-satan-tools/json-schema-includes-enum ()
  (dl-satan-test--with-tool-descriptions
   '(("fake.enum" . "desc"))
   (lambda ()
     (let* ((spec (list :name "fake.enum"
                        :args-schema '(scope (:type string :required t
                                              :enum ("a" "b")))
                        :handler #'ignore))
            (js (dl-satan-tool-json-schema spec))
            (scope (plist-get (plist-get
                               (plist-get (plist-get js :function) :parameters)
                               :properties)
                              :scope)))
       (should (equal (append (plist-get scope :enum) nil) '("a" "b")))))))

(ert-deftest dl-satan-tools/missing-description-errors ()
  "Missing tool description file signals; manifest build cannot proceed."
  (let ((dl-satan-tools-descriptions-dir
         (make-temp-file "satan-tools-empty-" t)))
    (unwind-protect
        (let ((spec (list :name "fake.absent"
                          :args-schema nil
                          :handler #'ignore)))
          (should-error (dl-satan-tool-json-schema spec) :type 'error))
      (delete-directory dl-satan-tools-descriptions-dir t))))

(ert-deftest dl-satan-tools/final-schema-uses-notes-description ()
  (dl-satan-test--with-tool-descriptions
   '(("satan_final" . "Terminate the run; describe what you did."))
   (lambda ()
     (let* ((js (dl-satan-tool-final-schema))
            (fn (plist-get js :function))
            (params (plist-get fn :parameters)))
       (should (equal (plist-get fn :name) "satan_final"))
       (should (string-match-p "Terminate" (plist-get fn :description)))
       (should (equal (append (plist-get params :required) nil) '("summary")))))))

;; ---------- dl-satan-broker--prepare (Phase 0.1) ----------

(ert-deftest dl-satan-broker/prepare-plist-shape ()
  "prepare returns a run_ctx plist with frozen run_id + time_now and v0 placeholders."
  (let* ((mode '(:name "tick-pulse"))
         (run-ctx (dl-satan-broker--prepare mode)))
    (should (stringp (plist-get run-ctx :run_id)))
    (should (string-prefix-p (format-time-string "%Y%m%dT")
                             (plist-get run-ctx :run_id)))
    (should (stringp (plist-get run-ctx :time_now)))
    (should (string-match-p
             "\\`[0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}T[0-9]\\{2\\}:[0-9]\\{2\\}:[0-9]\\{2\\}"
             (plist-get run-ctx :time_now)))
    (dolist (k '(:evidence :percept :sensor_status :pre_spawn :motive))
      (should (plist-member run-ctx k))
      (should (null (plist-get run-ctx k))))))

(ert-deftest dl-satan-broker/prepare-mints-distinct-run-ids ()
  "Two calls to prepare allocate different run_ids."
  (let* ((mode '(:name "x"))
         (a (dl-satan-broker--prepare mode))
         (b (dl-satan-broker--prepare mode)))
    (should-not (equal (plist-get a :run_id) (plist-get b :run_id)))))

(ert-deftest dl-satan-broker/prepare-freezes-time-now-once ()
  "time_now is computed exactly once at prepare; identical across reads."
  (let* ((mode '(:name "tick-pulse"))
         (run-ctx (dl-satan-broker--prepare mode))
         (frozen (plist-get run-ctx :time_now)))
    (sleep-for 0.05)
    (should (equal frozen (plist-get run-ctx :time_now)))))

;; ---------- dl-satan-broker tool-ctx ----------

(ert-deftest dl-satan-broker/tool-ctx-shape ()
  "Tool-ctx carries run-id, mode, capabilities, dirs, and frozen time fields
read from the prepare-phase run_ctx plist."
  (let* ((mode '(:name morning :capabilities (memory-write)))
         (start (encode-time '(0 0 10 19 5 2026 nil nil 36000)))
         (prepare (list :run_id "20260519T100000-morning-abc123"
                        :time_now "2026-05-19T10:00:00+1000"
                        :start_time start
                        :evidence nil :percept nil
                        :sensor_status nil :pre_spawn nil :motive nil))
         (run-ctx (make-dl-satan-run
                   :id "20260519T100000-morning-abc123"
                   :mode mode
                   :start-time start
                   :dir "/tmp/satan-run-test"
                   :prepare prepare))
         (tool-ctx (dl-satan-broker--tool-ctx run-ctx)))
    (should (equal (plist-get tool-ctx :id)
                   "20260519T100000-morning-abc123"))
    (should (equal (plist-get tool-ctx :mode-name) 'morning))
    (should (equal (plist-get tool-ctx :capabilities) '(memory-write)))
    (should (equal (plist-get tool-ctx :run-dir) "/tmp/satan-run-test"))
    (should (equal (plist-get tool-ctx :run-started-at)
                   "2026-05-19T10:00:00+1000"))
    (should (equal (plist-get tool-ctx :time-now)
                   "2026-05-19T10:00:00+1000"))))

(ert-deftest dl-satan-broker/tool-ctx-does-not-call-format-time-string ()
  "tool-ctx must read time_now from run_ctx, never compute it on demand."
  (let* ((mode '(:name morning :capabilities ()))
         (prepare (list :run_id "rid" :time_now "2026-01-01T00:00:00+0000"
                        :start_time (current-time)
                        :evidence nil :percept nil
                        :sensor_status nil :pre_spawn nil :motive nil))
         (run-ctx (make-dl-satan-run
                   :id "rid" :mode mode
                   :start-time (plist-get prepare :start_time)
                   :dir "/tmp/x" :prepare prepare))
         (called nil))
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (&rest args) (setq called args) "NEVER")))
      (let ((tool-ctx (dl-satan-broker--tool-ctx run-ctx)))
        (should (equal (plist-get tool-ctx :time-now)
                       "2026-01-01T00:00:00+0000"))
        (should (null called))))))

(ert-deftest dl-secret/scrub-op-refs-env-drops-unresolved-keys ()
  "Env-list scrub removes any KEY=op://… entries before child spawn.

A literal `op://…' ref reaching the child shows up as an opaque
401 `****tial' from the provider.  When op resolution fails the
explicit provider-env entry is absent but the same key can still
inherit from `process-environment'.  The scrub closes that leak."
  (let* ((input '("PATH=/usr/bin"
                  "SATAN_RUN_ID=abc"
                  "DEEPSEEK_API_KEY=op://API_KEYS/DEEPSEEK_API_KEY/credential"
                  "OPENAI_API_KEY=sk-real"
                  "OPENROUTER_API_KEY=op://x/y/z"
                  "BARE=op://still-a-secret"
                  "EMPTY="))
         (got (my/scrub-op-refs-env input)))
    (should (member "PATH=/usr/bin" got))
    (should (member "SATAN_RUN_ID=abc" got))
    (should (member "OPENAI_API_KEY=sk-real" got))
    (should (member "EMPTY=" got))
    (should-not (cl-find-if (lambda (kv)
                              (string-prefix-p "DEEPSEEK_API_KEY=" kv))
                            got))
    (should-not (cl-find-if (lambda (kv)
                              (string-prefix-p "OPENROUTER_API_KEY=" kv))
                            got))
    (should-not (cl-find-if (lambda (kv)
                              (string-prefix-p "BARE=" kv))
                            got))))

(ert-deftest dl-satan-broker/date-bucket-extracted-from-run-id ()
  (should (equal (dl-satan-broker--date-bucket-for-run-id
                  "20260520T163446-tick-pulse-5e8018")
                 "2026-05-20"))
  (should (null (dl-satan-broker--date-bucket-for-run-id "garbage")))
  (should (null (dl-satan-broker--date-bucket-for-run-id nil))))

(ert-deftest dl-satan-broker/run-id-from-leaf-strips-failed-suffix ()
  (should (equal (dl-satan-broker--run-id-from-leaf
                  "20260520T163446-tick-pulse-5e8018.FAILED")
                 "20260520T163446-tick-pulse-5e8018"))
  (should (equal (dl-satan-broker--run-id-from-leaf
                  "20260520T163446-tick-pulse-5e8018")
                 "20260520T163446-tick-pulse-5e8018")))

(ert-deftest dl-satan-broker/list-run-dirs-walks-both-layouts ()
  "Enumerator returns paths for legacy flat and bucketed runs, plus FAILED."
  (let ((root (make-temp-file "satan-runs-list-" t)))
    (unwind-protect
        (let ((legacy   (expand-file-name "20260519T100000-x-aaaaaa" root))
              (legacy-f (expand-file-name "20260519T110000-x-bbbbbb.FAILED" root))
              (bucket   (expand-file-name "2026-05-20" root))
              (bucketed (expand-file-name
                         "2026-05-20/20260520T120000-x-cccccc" root))
              (bucketed-f (expand-file-name
                           "2026-05-20/20260520T130000-x-dddddd.FAILED" root))
              (noise    (expand-file-name "not-a-run-dir" root))
              (noise-bucket-child
               (expand-file-name "2026-05-20/scratch" root)))
          (dolist (d (list legacy legacy-f bucket bucketed bucketed-f
                           noise noise-bucket-child))
            (make-directory d t))
          (let ((got (dl-satan-broker-list-run-dirs root)))
            (should (member legacy got))
            (should (member legacy-f got))
            (should (member bucketed got))
            (should (member bucketed-f got))
            (should-not (member noise got))
            (should-not (member noise-bucket-child got))
            (should-not (cl-find-if (lambda (p)
                                      (equal (file-name-nondirectory p)
                                             "2026-05-20"))
                                    got))))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/failure-streak-counts-trailing-failed ()
  "Counts consecutive .FAILED dirs back from the newest run-id."
  (let ((root (make-temp-file "satan-runs-streak-" t)))
    (unwind-protect
        (progn
          ;; Empty → 0.
          (should (= 0 (dl-satan-broker--failure-streak-count root)))
          ;; One done run → 0.
          (make-directory
           (expand-file-name "2026-05-20/20260520T100000-x-aaaaaa" root) t)
          (should (= 0 (dl-satan-broker--failure-streak-count root)))
          ;; Add a newer FAILED run → 1.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T110000-x-bbbbbb.FAILED" root) t)
          (should (= 1 (dl-satan-broker--failure-streak-count root)))
          ;; And another → 2.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T120000-x-cccccc.FAILED" root) t)
          (should (= 2 (dl-satan-broker--failure-streak-count root)))
          ;; A done run on top breaks the streak → 0.
          (make-directory
           (expand-file-name "2026-05-20/20260520T130000-x-dddddd" root) t)
          (should (= 0 (dl-satan-broker--failure-streak-count root))))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/announce-failure-syslog-and-streak-gate ()
  "Always logs via syslog; only notifies on streak == 1."
  (let* ((logged nil)
         (notified 0)
         (root (make-temp-file "satan-runs-announce-" t))
         (dl-satan-runs-dir root)
         (dl-satan-failure-syslog t)
         (dl-satan-failure-notify t))
    (unwind-protect
        (cl-letf
            (((symbol-function 'call-process)
              (lambda (cmd &rest args)
                (when (equal cmd "logger") (push args logged))
                0))
             ((symbol-function 'notifications-notify)
              (lambda (&rest _args) (cl-incf notified) 42)))
          ;; No prior runs → streak == 0 before rename; the just-renamed
          ;; dir is what bumps it to 1.  Emulate by creating that dir
          ;; first, then calling announce.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T100000-tick-pulse-aaaaaa.FAILED" root) t)
          (dl-satan-broker--announce-failure
           "20260520T100000-tick-pulse-aaaaaa" "tick-pulse"
           'failed "child-exit-1")
          (should (= 1 (length logged)))
          (should (= 1 notified))
          ;; Second consecutive failure → still logged, NOT notified.
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T110000-tick-pulse-bbbbbb.FAILED" root) t)
          (dl-satan-broker--announce-failure
           "20260520T110000-tick-pulse-bbbbbb" "tick-pulse"
           'failed "child-exit-1")
          (should (= 2 (length logged)))
          (should (= 1 notified)))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/announce-failure-respects-disables ()
  "Both syslog and notify are gated by their respective defcustom flags."
  (let* ((logged 0) (notified 0)
         (root (make-temp-file "satan-runs-announce2-" t))
         (dl-satan-runs-dir root)
         (dl-satan-failure-syslog nil)
         (dl-satan-failure-notify nil))
    (unwind-protect
        (cl-letf
            (((symbol-function 'call-process)
              (lambda (&rest _args) (cl-incf logged) 0))
             ((symbol-function 'notifications-notify)
              (lambda (&rest _args) (cl-incf notified) 42)))
          (make-directory
           (expand-file-name
            "2026-05-20/20260520T100000-tick-pulse-aaaaaa.FAILED" root) t)
          (dl-satan-broker--announce-failure
           "20260520T100000-tick-pulse-aaaaaa" "tick-pulse"
           'failed "child-exit-1")
          (should (= 0 logged))
          (should (= 0 notified)))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/locate-run-dir-finds-failed-and-buckets ()
  "Locator falls back through bucketed, bucketed-FAILED, legacy, legacy-FAILED."
  (let ((root (make-temp-file "satan-runs-locate-" t)))
    (unwind-protect
        (progn
          (let ((d (expand-file-name "2026-05-20/20260520T100000-x-aaaaaa"
                                     root)))
            (make-directory d t)
            (should (equal (dl-satan-broker-locate-run-dir
                            "20260520T100000-x-aaaaaa" root)
                           d)))
          (let ((d (expand-file-name
                    "2026-05-20/20260520T110000-x-bbbbbb.FAILED" root)))
            (make-directory d t)
            (should (equal (dl-satan-broker-locate-run-dir
                            "20260520T110000-x-bbbbbb" root)
                           d)))
          (let ((d (expand-file-name "20260520T120000-x-cccccc" root)))
            (make-directory d t)
            (should (equal (dl-satan-broker-locate-run-dir
                            "20260520T120000-x-cccccc" root)
                           d)))
          (should (null (dl-satan-broker-locate-run-dir
                         "20260520T999999-nope-zzzzzz" root))))
      (delete-directory root t))))

;; ---------- dl-satan-broker manifest assembly ----------

(ert-deftest dl-satan-broker/manifest-tools-shape ()
  "Manifest carries one JSON Schema per allowed tool plus satan_final."
  (dl-satan-test--with-tool-descriptions
   '(("org_read_context"      . "Read a slice of the notes corpus.")
     ("org_update_owned_block" . "Replace a SATAN-owned org block.")
     ("proposal_stage"         . "Stage a proposal.")
     ("notify_send"            . "Send a desktop notification.")
     ("hippocampus_write"      . "Write to the hippocampus.")
     ("inbox_append"           . "Append to the inbox.")
     ("agenda_read"            . "Read the agenda.")
     ("activity_read"          . "Read the user's recent activity.")
     ("notes_recent"           . "List recently changed notes files.")
     ("notes_at_satan_scan"    . "Scan @satan directives.")
     ("sway_border_set"        . "Retint sway window borders.")
     ("sway_border_reset"      . "Restore sway borders.")
     ("bough_read"             . "Read from bough.")
     ("memory_mark"            . "Mark a memory trace.")
     ("memory_resonate"        . "Resonate against handles.")
     ("memory_show_trace"      . "Show a memory trace.")
     ("docs_list"              . "List doc chunks.")
     ("docs_search"            . "Filter doc chunks.")
     ("docs_read"              . "Read a doc chunk.")
     ("motive_read"            . "Read motive entries.")
     ("motive_replace"         . "Replace a motive entry.")
     ("satan_final"            . "Terminate the run."))
   (lambda ()
     (let* ((mode (dl-satan-mode-resolve "morning"))
            (manifest (dl-satan-broker--build-manifest mode "test-run"))
            (tools (append (plist-get manifest :tools) nil))
            (names (mapcar (lambda (t-) (plist-get (plist-get t- :function) :name))
                           tools)))
       (should (equal (plist-get manifest :run_id) "test-run"))
       (should (member "org_read_context" names))
       (should (member "org_update_owned_block" names))
       (should (member "notify_send" names))
       (should (member "hippocampus_write" names))
       (should (member "inbox_append" names))
       (should (member "agenda_read" names))
       (should (member "activity_read" names))
       (should (member "notes_recent" names))
       (should (member "satan_final" names))
       ;; Descriptions came from notes files, not elisp.
       (let ((notify (cl-find "notify_send" tools
                              :key (lambda (t-)
                                     (plist-get (plist-get t- :function) :name))
                              :test #'equal)))
         (should (string-match-p
                  "Send a desktop notification"
                  (plist-get (plist-get notify :function) :description))))))))

(ert-deftest dl-satan-self-edit/output-only-applies-proposal-stage ()
  "Output handler auto-applies proposal.stage; everything else gets staged."
  (let* ((tmp (make-temp-file "satan-se-out-" t))
         (dl-satan-proposals-dir tmp)
         (final '(:summary "x"
                  :actions ((:type "proposal_stage"
                             :args (:title "fix" :body "do the thing"))
                            (:type "org_update_owned_block"
                             :args (:target "today" :block "satan" :content "x")))))
         (ctx (list :id "r1" :mode-name "self-edit-mech"
                    :capabilities '(stage-proposal))))
    (unwind-protect
        (let ((p (dl-satan-output/self-edit final ctx)))
          (should (equal (length (plist-get p :applied)) 1))
          (should (equal (length (plist-get p :staged)) 1))
          (should (equal (plist-get (car (plist-get p :applied)) :type)
                         "proposal_stage")))
      (delete-directory tmp t))))

;; ---------- dl-satan-tick ----------

(ert-deftest dl-satan-tick/quiet-hours-wraparound ()
  "Default 22..7 window suppresses overnight, lets daytime pass."
  (let ((dl-satan-tick-quiet-hours '(22 . 7)))
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (fmt &optional _time &rest _) (if (equal fmt "%H") "23" "x"))))
      (should (dl-satan-tick-quiet-p)))
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (fmt &optional _time &rest _) (if (equal fmt "%H") "03" "x"))))
      (should (dl-satan-tick-quiet-p)))
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (fmt &optional _time &rest _) (if (equal fmt "%H") "09" "x"))))
      (should-not (dl-satan-tick-quiet-p)))
    (cl-letf (((symbol-function 'format-time-string)
               (lambda (fmt &optional _time &rest _) (if (equal fmt "%H") "21" "x"))))
      (should-not (dl-satan-tick-quiet-p)))))

(ert-deftest dl-satan-tick/quiet-hours-disabled ()
  "nil quiet hours means never quiet."
  (let ((dl-satan-tick-quiet-hours nil))
    (should-not (dl-satan-tick-quiet-p))))

(ert-deftest dl-satan-tick/pick-single-deterministic ()
  (should (equal (dl-satan-tick-pick '(("tick-pulse" . 1))) "tick-pulse")))

(ert-deftest dl-satan-tick/pick-zero-weight-nil ()
  (should (null (dl-satan-tick-pick '(("x" . 0))))))

(ert-deftest dl-satan-tick/pick-distribution-respects-weight ()
  "Over many draws, weights determine relative frequency."
  (let* ((pool '(("a" . 3) ("b" . 1)))
         (counts (make-hash-table :test 'equal))
         (n 4000))
    (random "tick-test-seed")
    (dotimes (_ n)
      (let ((p (dl-satan-tick-pick pool)))
        (puthash p (1+ (gethash p counts 0)) counts)))
    (let ((a (gethash "a" counts 0))
          (b (gethash "b" counts 0)))
      (should (= (+ a b) n))
      ;; expect ~3:1; allow generous slack so the test is not flaky
      (should (> a (* b 2))))))

(ert-deftest dl-satan-tick/default-pulse-mode-registered ()
  "tick-pulse is registered with the documented budget defaults."
  (let ((mode (dl-satan-mode-resolve "tick-pulse")))
    (should (equal (plist-get mode :budget-tokens) 100000))
    (should (equal (plist-get mode :budget-tool-calls) 10))
    (should (equal (plist-get mode :timeout-seconds) 60))
    (should (eq (plist-get mode :output-handler) 'dl-satan-output/tick))
    (should (member "notify_send" (plist-get mode :tools)))
    (should (member "inbox_append" (plist-get mode :tools)))
    (should-not (member "org_update_owned_block" (plist-get mode :tools)))))

(ert-deftest dl-satan-tick/output-only-auto-applies-inbox ()
  "Tick output handler stages everything except `inbox_append'."
  (let ((final '(:summary ""
                 :actions ((:type "inbox_append"
                            :args (:title "x" :body "y"))
                           (:type "notify_send"
                            :args (:title "x" :body "y")))))
        (ctx (list :id "r1" :mode-name "tick-pulse"
                   :capabilities '(notify inbox-write)))
        (called nil))
    (cl-letf (((symbol-function 'dl-satan-tool/inbox-append)
               (lambda (&rest _) (setq called t) (cons 'ok '(:path "/x")))))
      (let ((p (dl-satan-output/tick final ctx)))
        (should called)
        (should (equal (length (plist-get p :applied)) 1))
        (should (equal (length (plist-get p :staged)) 1))
        (should (equal (plist-get (car (plist-get p :applied)) :type)
                       "inbox_append"))))))

;; ---------- dl-satan-tools-agenda ----------

(defmacro dl-satan-test--with-gcalcli-stub (status output &rest body)
  "Run BODY with `call-process' stubbed to return STATUS and emit OUTPUT.
Captures the argv passed to call-process in `argv-out'."
  (declare (indent 2))
  `(let ((argv-out nil))
     (cl-letf (((symbol-function 'call-process)
                (lambda (program &optional _in dest _disp &rest args)
                  (setq argv-out (cons program args))
                  (when (and dest (bufferp dest))
                    (with-current-buffer dest (insert ,output)))
                  (when (and dest (eq dest t))
                    (insert ,output))
                  ,status)))
       (let ((process-environment (cons "WORK_EMAIL=test@example.com"
                                        process-environment)))
         ,@body))))

(ert-deftest dl-satan-agenda/handler-ok ()
  "Happy path: agenda_read returns ok + trimmed text + echoed calendar/days."
  (dl-satan-test--with-gcalcli-stub 0 "Mon May 19  9:00 standup\n"
    (let ((res (dl-satan-tool/agenda-read nil nil)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get (cdr res) :text) "Mon May 19  9:00 standup"))
      (should (equal (plist-get (cdr res) :calendar) "test@example.com"))
      (should (equal (plist-get (cdr res) :days)
                     dl-satan-tools-agenda-default-days)))
    (should (member "timeout" argv-out))
    (should (member "gcalcli" argv-out))
    (should (member "--calendar" argv-out))
    (should (member "test@example.com" argv-out))))

(ert-deftest dl-satan-agenda/handler-respects-days ()
  "`:days' overrides the default and shows up in the response."
  (dl-satan-test--with-gcalcli-stub 0 ""
    (let ((res (dl-satan-tool/agenda-read '(:days 3) nil)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get (cdr res) :days) 3)))))

(ert-deftest dl-satan-agenda/days-clamped ()
  "Out-of-range `:days' is clamped to [1, agenda--days-max]."
  (dl-satan-test--with-gcalcli-stub 0 ""
    (let ((hi (dl-satan-tool/agenda-read '(:days 99) nil))
          (lo (dl-satan-tool/agenda-read '(:days 0) nil)))
      (should (equal (plist-get (cdr hi) :days)
                     dl-satan-tools-agenda--days-max))
      (should (equal (plist-get (cdr lo) :days) 1)))))

(ert-deftest dl-satan-agenda/missing-calendar-env ()
  "Unset env var yields a structured error, no process spawn."
  (let* ((spawned nil)
         (process-environment (cl-remove-if
                               (lambda (e) (string-prefix-p "WORK_EMAIL=" e))
                               process-environment)))
    (cl-letf (((symbol-function 'call-process)
               (lambda (&rest _) (setq spawned t) 0)))
      (let ((res (dl-satan-tool/agenda-read nil nil)))
        (should (eq (car res) 'error))
        (should (string-match-p "WORK_EMAIL" (cdr res)))
        (should-not spawned)))))

(ert-deftest dl-satan-agenda/handler-nonzero-exit ()
  "Non-zero exit surfaces stderr/stdout in the error string."
  (dl-satan-test--with-gcalcli-stub 1 "auth failure\n"
    (let ((res (dl-satan-tool/agenda-read nil nil)))
      (should (eq (car res) 'error))
      (should (string-match-p "auth failure" (cdr res))))))

(ert-deftest dl-satan-agenda/handler-timeout ()
  "Status 124 from `timeout(1)' is reported as a timeout."
  (dl-satan-test--with-gcalcli-stub 124 ""
    (let ((res (dl-satan-tool/agenda-read nil nil)))
      (should (eq (car res) 'error))
      (should (string-match-p "timed out" (cdr res))))))

(ert-deftest dl-satan-agenda/dispatch-mode-allowlist ()
  "agenda_read is allowed in morning and motd, blocked elsewhere."
  (dl-satan-test--with-gcalcli-stub 0 "x"
    (let ((ok (dl-satan-tool-dispatch
               '(:type "tool_call" :id "a1" :name "agenda_read" :args nil)
               '("agenda_read")
               nil))
          (blocked (dl-satan-tool-dispatch
                    '(:type "tool_call" :id "a2" :name "agenda_read" :args nil)
                    '("inbox_append")
                    nil)))
      (should (eq (plist-get ok :ok) t))
      (should (equal (plist-get blocked :ok) :false))
      (should (string-match-p "not allowed" (plist-get blocked :error))))))

;; ---------- dl-satan-tools-activity ----------

(defmacro dl-satan-test--with-activity-root (&rest body)
  "Bind `dl-satan-tools-activity-dir' to a temp dir for BODY."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "satan-activity-" t))
          (dl-satan-tools-activity-dir dir))
     (make-directory (expand-file-name "histograms" dir) t)
     (make-directory (expand-file-name "segments" dir) t)
     (unwind-protect (progn ,@body)
       (delete-directory dir t))))

(defun dl-satan-test--activity-today ()
  (format-time-string "%Y-%m-%d"))

(defun dl-satan-test--write-histogram (dir payload)
  (let ((path (expand-file-name
               (format "histograms/daily-%s.json"
                       (dl-satan-test--activity-today))
               dir)))
    (with-temp-file path (insert payload))
    path))

(defun dl-satan-test--write-focus-jsonl (dir lines)
  (let ((path (expand-file-name
               (format "segments/focus-%s.jsonl"
                       (dl-satan-test--activity-today))
               dir)))
    (with-temp-file path
      (dolist (l lines) (insert l) (insert "\n")))
    path))

(defun dl-satan-test--write-browser-jsonl (dir lines)
  (let ((path (expand-file-name
               (format "segments/browser-%s.jsonl"
                       (dl-satan-test--activity-today))
               dir)))
    (with-temp-file path
      (dolist (l lines) (insert l) (insert "\n")))
    path))

(defun dl-satan-test--write-current-sway (dir payload)
  (make-directory (expand-file-name "current" dir) t)
  (let ((path (expand-file-name "current/sway.json" dir)))
    (with-temp-file path (insert payload))
    path))

(ert-deftest dl-satan-activity/today-returns-parsed-histogram ()
  "Scope `today' reads histograms/daily-<today>.json and returns a plist."
  (dl-satan-test--with-activity-root
    (dl-satan-test--write-histogram
     dl-satan-tools-activity-dir
     "{\"day\":\"2026-05-19\",\"per_app_seconds\":{\"emacs\":42.5},\"per_workspace_seconds\":{\"09\":42.5},\"per_hour_seconds\":[0.0]}")
    (let ((res (dl-satan-tool/activity-read '(:scope "today") nil)))
      (should (eq (car res) 'ok))
      (let* ((p (cdr res))
             (h (plist-get p :histogram)))
        (should (equal (plist-get p :scope) "today"))
        (should (equal (plist-get p :date)
                       (dl-satan-test--activity-today)))
        (should (equal (plist-get h :day) "2026-05-19"))
        (should (equal (plist-get (plist-get h :per_app_seconds) :emacs)
                       42.5))))))

(ert-deftest dl-satan-activity/today-missing-file-returns-nil-histogram ()
  "Missing histogram file yields ok with :histogram nil, not an error."
  (dl-satan-test--with-activity-root
    (let ((res (dl-satan-tool/activity-read '(:scope "today") nil)))
      (should (eq (car res) 'ok))
      (should (null (plist-get (cdr res) :histogram))))))

(ert-deftest dl-satan-activity/recent-focus-returns-tail ()
  "Scope `recent_focus' returns last :limit segments in file order."
  (dl-satan-test--with-activity-root
    (dl-satan-test--write-focus-jsonl
     dl-satan-tools-activity-dir
     (cl-loop for i from 1 to 5 collect
              (format "{\"v\":1,\"app_id\":\"app%d\",\"workspace\":\"01\",\"duration_s\":%d}"
                      i i)))
    (let* ((res (dl-satan-tool/activity-read
                 '(:scope "recent_focus" :limit 2) nil))
           (p (cdr res))
           (segs (plist-get p :segments)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get p :limit) 2))
      (should (equal (length segs) 2))
      (should (equal (plist-get (car segs) :app_id) "app4"))
      (should (equal (plist-get (cadr segs) :app_id) "app5")))))

(ert-deftest dl-satan-activity/recent-focus-limit-defaults-and-clamps ()
  "Missing :limit uses default; out-of-range clamps to [1, 200]."
  (dl-satan-test--with-activity-root
    (dl-satan-test--write-focus-jsonl
     dl-satan-tools-activity-dir
     '("{\"app_id\":\"a\"}"))
    (let ((default-res (dl-satan-tool/activity-read
                        '(:scope "recent_focus") nil))
          (hi-res (dl-satan-tool/activity-read
                   '(:scope "recent_focus" :limit 9999) nil))
          (lo-res (dl-satan-tool/activity-read
                   '(:scope "recent_focus" :limit 0) nil)))
      (should (equal (plist-get (cdr default-res) :limit)
                     dl-satan-tools-activity-default-limit))
      (should (equal (plist-get (cdr hi-res) :limit)
                     dl-satan-tools-activity--limit-max))
      (should (equal (plist-get (cdr lo-res) :limit) 1)))))

(ert-deftest dl-satan-activity/recent-focus-missing-file-empty-segments ()
  "Missing segments file yields ok with :segments '()."
  (dl-satan-test--with-activity-root
    (let ((res (dl-satan-tool/activity-read
                '(:scope "recent_focus") nil)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get (cdr res) :segments) '())))))

(ert-deftest dl-satan-activity/recent-browser-returns-tail ()
  "Scope `recent_browser' returns last :limit browser segments in order."
  (dl-satan-test--with-activity-root
    (dl-satan-test--write-browser-jsonl
     dl-satan-tools-activity-dir
     (cl-loop for i from 1 to 4 collect
              (format "{\"v\":1,\"origin\":\"site%d.example\",\"duration_s\":%d}"
                      i i)))
    (let* ((res (dl-satan-tool/activity-read
                 '(:scope "recent_browser" :limit 2) nil))
           (p (cdr res))
           (segs (plist-get p :segments)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get p :scope) "recent_browser"))
      (should (equal (length segs) 2))
      (should (equal (plist-get (car segs) :origin) "site3.example"))
      (should (equal (plist-get (cadr segs) :origin) "site4.example")))))

(ert-deftest dl-satan-activity/recent-browser-missing-file-empty-segments ()
  "Missing browser segments file yields ok with :segments '()."
  (dl-satan-test--with-activity-root
    (let ((res (dl-satan-tool/activity-read
                '(:scope "recent_browser") nil)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get (cdr res) :segments) '())))))

(ert-deftest dl-satan-activity/current-returns-window-snapshot ()
  "Scope `current' returns parsed current/sway.json verbatim (title included)."
  (dl-satan-test--with-activity-root
    (dl-satan-test--write-current-sway
     dl-satan-tools-activity-dir
     "{\"app_id\":\"emacs\",\"title\":\"~/notes/foo.org\",\"workspace\":\"09\",\"output\":\"DP-3\",\"pid\":4242}")
    (let* ((res (dl-satan-tool/activity-read '(:scope "current") nil))
           (p (cdr res))
           (w (plist-get p :window)))
      (should (eq (car res) 'ok))
      (should (equal (plist-get p :scope) "current"))
      (should (equal (plist-get w :app_id) "emacs"))
      (should (equal (plist-get w :workspace) "09"))
      (should (equal (plist-get w :title) "~/notes/foo.org")))))

(ert-deftest dl-satan-activity/current-missing-file-nil-window ()
  "Missing current/sway.json yields ok with :window nil."
  (dl-satan-test--with-activity-root
    (let ((res (dl-satan-tool/activity-read '(:scope "current") nil)))
      (should (eq (car res) 'ok))
      (should (null (plist-get (cdr res) :window))))))

(ert-deftest dl-satan-activity/unknown-scope-errors ()
  "Unknown :scope is a structured error."
  (let ((res (dl-satan-tool/activity-read '(:scope "tomorrow") nil)))
    (should (eq (car res) 'error))
    (should (string-match-p "unknown scope" (cdr res)))))

(ert-deftest dl-satan-activity/dispatch-schema-enum ()
  "Dispatcher rejects scope values outside the registered enum."
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "ar1" :name "activity_read"
                :args (:scope "yesterday"))
              '("activity_read") nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "must be one of" (plist-get res :error)))))

;; ---------- dl-satan-tools-notes ----------

(defvar dl-satan-test--notes-fd-calls nil
  "List of (PROGRAM ARGS) recorded by `dl-satan-test--with-fd-stub'.")

(defmacro dl-satan-test--with-notes-root (&rest body)
  "Bind `dl-satan-tools-notes-root' to a temp dir for BODY."
  (declare (indent 0))
  `(let* ((dir (make-temp-file "satan-notes-" t))
          (dl-satan-tools-notes-root dir))
     (unwind-protect (progn ,@body)
       (delete-directory dir t))))

(defmacro dl-satan-test--with-fd-stub (stdout exit-code &rest body)
  "Stub `call-process' so that calls to `dl-satan-tools-notes--fd-program'
return EXIT-CODE and write STDOUT to the capture buffer.  Records each call
into `dl-satan-test--notes-fd-calls'."
  (declare (indent 2))
  `(let ((dl-satan-test--notes-fd-calls nil))
     (cl-letf (((symbol-function 'call-process)
                (lambda (program &optional _infile destination _display &rest args)
                  (push (cons program args) dl-satan-test--notes-fd-calls)
                  (when (and destination (not (eq destination 0)))
                    (let ((out-buf (if (consp destination) (car destination) destination)))
                      (when (bufferp out-buf)
                        (with-current-buffer out-buf
                          (insert ,stdout)))
                      (when (eq out-buf t)
                        (insert ,stdout))))
                  ,exit-code)))
       ,@body)))

(defun dl-satan-test--touch (root rel &optional age-seconds)
  "Create REL under ROOT and set its mtime to now minus AGE-SECONDS (default 0)."
  (let* ((path (expand-file-name rel root))
         (parent (file-name-directory path)))
    (when parent (make-directory parent t))
    (with-temp-file path (insert ""))
    (let ((when (time-subtract (current-time) (or age-seconds 0))))
      (set-file-times path when))
    path))

(ert-deftest dl-satan-notes/builds-correct-fd-argv ()
  "fd is invoked with --changed-after Nh, -t f, --print0, --base-directory, --exclude satan."
  (dl-satan-test--with-notes-root
    (dl-satan-test--with-fd-stub "" 0
      (dl-satan-tool/notes-read '(:since-hours 24 :limit 10) nil)
      (let* ((call (car dl-satan-test--notes-fd-calls))
             (program (car call))
             (args (cdr call)))
        (should (equal program dl-satan-tools-notes--fd-program))
        (should (member "--changed-after" args))
        (should (member "24h" args))
        (should (member "-t" args))
        (should (member "f" args))
        (should (member "--print0" args))
        (should (member "--base-directory" args))
        (should (member dl-satan-tools-notes-root args))
        (should (member "--exclude" args))
        (should (member "satan" args))))))

(ert-deftest dl-satan-notes/parses-output-and-sorts-by-mtime-desc ()
  "Returns files newer-first; relative paths; correct count."
  (dl-satan-test--with-notes-root
    (dl-satan-test--touch dl-satan-tools-notes-root "old.org"    1000)
    (dl-satan-test--touch dl-satan-tools-notes-root "middle.org" 100)
    (dl-satan-test--touch dl-satan-tools-notes-root "newest.org" 1)
    (dl-satan-test--with-fd-stub "old.org\0middle.org\0newest.org\0" 0
      (let* ((res (dl-satan-tool/notes-read '(:since-hours 24) nil))
             (p (cdr res))
             (files (plist-get p :files)))
        (should (eq (car res) 'ok))
        (should (equal (plist-get p :count) 3))
        (should (equal (mapcar (lambda (f) (plist-get f :path)) files)
                       '("newest.org" "middle.org" "old.org")))))))

(ert-deftest dl-satan-notes/limit-default-and-clamp ()
  "Missing :limit applies default; out-of-range clamps to [1, 200]."
  (dl-satan-test--with-notes-root
    (let* ((paths (cl-loop for i from 1 to 250 collect
                           (format "f%03d.org" i)))
           (stdout (mapconcat #'identity paths "\0")))
      (cl-loop for p in paths
               for age from 1
               do (dl-satan-test--touch dl-satan-tools-notes-root p age))
      (dl-satan-test--with-fd-stub (concat stdout "\0") 0
        (let ((default-res (dl-satan-tool/notes-read '(:since-hours 24) nil))
              (hi-res (dl-satan-tool/notes-read '(:since-hours 24 :limit 9999) nil))
              (lo-res (dl-satan-tool/notes-read '(:since-hours 24 :limit 0) nil)))
          (should (equal (plist-get (cdr default-res) :limit)
                         dl-satan-tools-notes-default-limit))
          (should (equal (plist-get (cdr hi-res) :limit)
                         dl-satan-tools-notes--limit-max))
          (should (equal (plist-get (cdr lo-res) :limit) 1))
          (should (equal (length (plist-get (cdr hi-res) :files))
                         dl-satan-tools-notes--limit-max)))))))

(ert-deftest dl-satan-notes/since-hours-default-and-clamp ()
  "Missing :since-hours uses default; out-of-range clamps to [1, 720]."
  (dl-satan-test--with-notes-root
    (cl-flet ((argv-has-hours (hours)
                (let* ((call (car dl-satan-test--notes-fd-calls))
                       (args (cdr call)))
                  (member (format "%dh" hours) args))))
      (dl-satan-test--with-fd-stub "" 0
        (dl-satan-tool/notes-read nil nil)
        (should (argv-has-hours dl-satan-tools-notes-default-hours)))
      (dl-satan-test--with-fd-stub "" 0
        (dl-satan-tool/notes-read '(:since-hours 99999) nil)
        (should (argv-has-hours dl-satan-tools-notes--hours-max)))
      (dl-satan-test--with-fd-stub "" 0
        (dl-satan-tool/notes-read '(:since-hours 0) nil)
        (should (argv-has-hours 1))))))

(ert-deftest dl-satan-notes/parses-denote-filename-metadata ()
  "Denote-style filename → :title spaces + :tags list; plain → :title nil."
  (dl-satan-test--with-notes-root
    (dl-satan-test--touch dl-satan-tools-notes-root
                          "20260520T011750--actually-learn-git-deeply__fundamentals_git_tech.org"
                          1)
    (dl-satan-test--touch dl-satan-tools-notes-root "protocol.org" 2)
    (dl-satan-test--with-fd-stub
        "20260520T011750--actually-learn-git-deeply__fundamentals_git_tech.org\0protocol.org\0"
        0
      (let* ((res (dl-satan-tool/notes-read '(:since-hours 24) nil))
             (files (plist-get (cdr res) :files))
             (denote (cl-find-if (lambda (f)
                                   (string-match-p "actually-learn"
                                                   (plist-get f :path)))
                                 files))
             (plain (cl-find-if (lambda (f)
                                  (equal (plist-get f :path) "protocol.org"))
                                files)))
        (should (eq (car res) 'ok))
        (should (equal (plist-get denote :title) "actually learn git deeply"))
        (should (equal (plist-get denote :tags) '("fundamentals" "git" "tech")))
        (should (equal (plist-get denote :ext) "org"))
        (should (null (plist-get plain :title)))
        (should (null (plist-get plain :tags)))
        (should (equal (plist-get plain :ext) "org"))))))

(ert-deftest dl-satan-notes/fd-failure-returns-error ()
  "Non-zero fd exit → (error . \"fd failed: ...\")."
  (dl-satan-test--with-notes-root
    (dl-satan-test--with-fd-stub "" 1
      (let ((res (dl-satan-tool/notes-read '(:since-hours 24) nil)))
        (should (eq (car res) 'error))
        (should (string-match-p "fd failed" (cdr res)))))))

(ert-deftest dl-satan-notes/empty-stdout-empty-files ()
  "fd returns nothing → ok with :count 0 and :files '()."
  (dl-satan-test--with-notes-root
    (dl-satan-test--with-fd-stub "" 0
      (let* ((res (dl-satan-tool/notes-read '(:since-hours 24) nil))
             (p (cdr res)))
        (should (eq (car res) 'ok))
        (should (equal (plist-get p :count) 0))
        (should (equal (plist-get p :files) '()))))))

;; ---------- dl-satan-budget ----------

(defun dl-satan-test--write-transcript (dir lines)
  "Write LINES (each a plist) as transcript.jsonl under DIR."
  (make-directory dir t)
  (let ((coding-system-for-write 'utf-8))
    (with-temp-file (expand-file-name "transcript.jsonl" dir)
      (dolist (l lines)
        (insert (json-serialize
                 (dl-satan-jsonl-prepare l)
                 :null-object :null :false-object :false))
        (insert "\n")))))

(defun dl-satan-test--usage-record (tokens-total)
  (list :ts "2026-05-19T09:00:00.000000+1000"
        :dir "in" :event "log"
        :payload (list :type "log" :kind "usage"
                       :tokens_in 0 :tokens_out 0
                       :tokens_total tokens-total)))

(ert-deftest dl-satan-budget/run-tokens-takes-max-cumulative ()
  (let ((dir (make-temp-file "satan-bud-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           dir (list (dl-satan-test--usage-record 100)
                     (dl-satan-test--usage-record 350)
                     (dl-satan-test--usage-record 350)))
          (should (equal (dl-satan-budget--run-tokens dir) 350)))
      (delete-directory dir t))))

(ert-deftest dl-satan-budget/run-tokens-zero-when-no-usage ()
  (let ((dir (make-temp-file "satan-bud-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           dir (list (list :ts "x" :dir "in" :event "ready"
                           :payload (list :type "ready"))))
          (should (equal (dl-satan-budget--run-tokens dir) 0)))
      (delete-directory dir t))))

(ert-deftest dl-satan-budget/today-total-sums-today-prefix-only ()
  (let* ((root (make-temp-file "satan-bud-root-" t))
         (now (current-time))
         (today (format-time-string "%Y%m%dT" now))
         (yesterday (format-time-string
                     "%Y%m%dT"
                     (time-subtract now (days-to-time 1))))
         (today-a (expand-file-name (concat today "090000-x-aaaaaa") root))
         (today-b (expand-file-name (concat today "100000-x-bbbbbb") root))
         (older   (expand-file-name (concat yesterday "120000-x-cccccc") root)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           today-a (list (dl-satan-test--usage-record 1000)))
          (dl-satan-test--write-transcript
           today-b (list (dl-satan-test--usage-record 2500)))
          (dl-satan-test--write-transcript
           older   (list (dl-satan-test--usage-record 999999)))
          (should (equal (dl-satan-budget-today-total root now) 3500)))
      (delete-directory root t))))

(ert-deftest dl-satan-budget/exceeded-p-respects-ceiling ()
  (let* ((root (make-temp-file "satan-bud-root-" t))
         (now (current-time))
         (today (format-time-string "%Y%m%dT" now))
         (dir (expand-file-name (concat today "090000-x-aaaaaa") root)))
    (unwind-protect
        (progn
          (dl-satan-test--write-transcript
           dir (list (dl-satan-test--usage-record 400000)))
          (let ((dl-satan-budget-daily-tokens 400000))
            (should (dl-satan-budget-exceeded-p root now)))
          (let ((dl-satan-budget-daily-tokens 400001))
            (should-not (dl-satan-budget-exceeded-p root now)))
          (let ((dl-satan-budget-daily-tokens nil))
            (should-not (dl-satan-budget-exceeded-p root now))))
      (delete-directory root t))))

(ert-deftest dl-satan-broker/refuses-spawn-when-budget-exceeded ()
  "Pre-spawn gate writes status=budget-exceeded; no child spawned."
  (dl-satan-test--with-tool-descriptions
   '(("org_read_context"       . "Read.")
     ("org_update_owned_block" . "Write owned.")
     ("proposal_stage"         . "Stage.")
     ("notify_send"            . "Notify.")
     ("hippocampus_write"      . "Write hippo.")
     ("inbox_append"           . "Append inbox.")
     ("agenda_read"            . "Read agenda.")
     ("activity_read"          . "Read activity.")
     ("notes_recent"           . "List recent notes.")
     ("notes_at_satan_scan"    . "Scan @satan directives.")
     ("sway_border_set"        . "Retint sway borders.")
     ("sway_border_reset"      . "Restore sway borders.")
     ("bough_read"             . "Read bough.")
     ("memory_mark"            . "Mark.")
     ("memory_resonate"        . "Resonate.")
     ("memory_show_trace"      . "Show.")
     ("docs_list"              . "List docs.")
     ("docs_search"            . "Search docs.")
     ("docs_read"              . "Read doc.")
     ("motive_read"            . "Read motives.")
     ("motive_replace"         . "Replace motive.")
     ("satan_final"            . "Terminate."))
   (lambda ()
     (let* ((root (make-temp-file "satan-bud-broker-" t))
            (now (current-time))
            (today (format-time-string "%Y%m%dT" now))
            (existing (expand-file-name (concat today "080000-x-eeeeee") root))
            (dl-satan-runs-dir root)
            (dl-satan-budget-daily-tokens 400000))
       (unwind-protect
           (progn
             (dl-satan-test--write-transcript
              existing (list (dl-satan-test--usage-record 500000)))
             (let* ((run-id (dl-satan-broker-run "morning"))
                    (dir (dl-satan-broker-locate-run-dir run-id root))
                    (status-path (expand-file-name "status" dir)))
               (should (string-suffix-p ".FAILED" dir))
               (should (file-directory-p dir))
               (should (file-readable-p status-path))
               (should (equal (string-trim
                               (with-temp-buffer
                                 (insert-file-contents status-path)
                                 (buffer-string)))
                              "budget-exceeded"))
               (should (eq (dl-satan-audit-verify-run dir) t))
               (let* ((final-path (expand-file-name "final.json" dir))
                      (final (with-temp-buffer
                               (insert-file-contents final-path)
                               (goto-char (point-min))
                               (json-parse-buffer
                                :object-type 'plist
                                :array-type 'list
                                :null-object :null
                                :false-object :false))))
                 (should (string-match-p "budget-exceeded"
                                         (plist-get final :summary)))
                 (should (equal (plist-get final :reason)
                                "budget_daily_tokens")))))
         (delete-directory root t))))))

;; ---------- dl-satan-audit verifier ----------

(defun dl-satan-test--write-run (dir final actions status &optional transcript)
  (make-directory dir t)
  (let ((audit (dl-satan-audit-open dir
                                    '(:run_id "r" :mode (:name "test"))
                                    '(:bundle t))))
    (dolist (rec (or transcript '()))
      (dl-satan-audit-record audit (nth 0 rec) (nth 1 rec) (nth 2 rec)))
    (dl-satan-audit-close audit final actions status)))

(ert-deftest dl-satan-audit/verifier-ok ()
  (let ((dir (make-temp-file "satan-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))
             (broker tool-result (:id "a" :ok t))))
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

;; ---------- dl-satan-broker pre_spawn threading (Phase 4.4) ----------

(ert-deftest dl-satan-broker/finalize-threads-pre-spawn-into-actions-json ()
  "broker--finalize copies `:pre_spawn' from the prepare run_ctx into the
actions plist passed to `dl-satan-audit-close', which lands the
entries in `actions.json'.  Phase 4.4 — wires the producer side
(Phase 4.3 `sensor-alerts.check') into the audit close (Phase 0.3
schema bump)."
  (let ((dir (make-temp-file "satan-broker-pre-spawn-" t))
        (entries (list (list :kind "sensor_alert"
                             :cause "panopticon_current_stale"
                             :severity "warning"
                             :message "stale 28m"
                             :suppressed :false
                             :dispatched_at "2026-05-22T11:13Z"))))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-22T11:13Z"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil
                              :pre_spawn entries))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 30
                       :budget-tool-calls 1 :capabilities ()))
               (run-ctx (make-dl-satan-run
                         :id "rid"
                         :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir
                         :status 'running
                         :final '(:summary "ok" :actions ())
                         :audit audit
                         :prepare prepare)))
          (cl-letf (((symbol-function 'dl-satan-broker--mark-failed-on-disk)
                     (lambda (&rest _) nil)))
            (dl-satan-broker--finalize run-ctx))
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (let ((ps (plist-get parsed :pre_spawn)))
              (should (listp ps))
              (should (= 1 (length ps)))
              (should (equal "panopticon_current_stale"
                             (plist-get (car ps) :cause)))
              (should (equal "2026-05-22T11:13Z"
                             (plist-get (car ps) :dispatched_at))))
            (should (eq (dl-satan-audit-verify-run dir) t))))
      (delete-directory dir t))))

(ert-deftest dl-satan-broker/finalize-omits-pre-spawn-when-empty ()
  "When `:pre_spawn' is nil on prepare, actions.json omits the key
entirely so untouched runs keep the original four-partition shape."
  (let ((dir (make-temp-file "satan-broker-pre-spawn-empty-" t)))
    (unwind-protect
        (let* ((prepare (list :run_id "rid" :time_now "2026-05-22T11:13Z"
                              :start_time (current-time)
                              :evidence nil :percept nil
                              :sensor_status nil :motive nil :pre_spawn nil))
               (audit (dl-satan-audit-open
                       dir '(:run_id "rid" :mode (:name "test"))
                       '(:bundle t) prepare))
               (mode '(:name "test" :auto-apply none :timeout-seconds 30
                       :budget-tool-calls 1 :capabilities ()))
               (run-ctx (make-dl-satan-run
                         :id "rid"
                         :mode mode
                         :start-time (plist-get prepare :start_time)
                         :dir dir
                         :status 'running
                         :final '(:summary "ok" :actions ())
                         :audit audit
                         :prepare prepare)))
          (cl-letf (((symbol-function 'dl-satan-broker--mark-failed-on-disk)
                     (lambda (&rest _) nil)))
            (dl-satan-broker--finalize run-ctx))
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (should-not (plist-member parsed :pre_spawn))))
      (delete-directory dir t))))

;; ---------- dl-satan-audit pre_spawn (Phase 0.3) ----------

(ert-deftest dl-satan-audit/pre-spawn-key-written-when-present ()
  "`dl-satan-audit-close' writes `:pre_spawn' into actions.json when the
caller supplies it; the four model-action partitions stay untouched."
  (let ((dir (make-temp-file "satan-prespawn-write-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :kind "sensor_alert"
                                        :cause "panopticon_current_stale"
                                        :severity "warning"
                                        :message "stale 28m"
                                        :dispatched_at "2026-05-22T11:13Z")))
           'done)
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (should (equal (plist-get parsed :applied) '()))
            (should (equal (plist-get parsed :staged) '()))
            (should (equal (plist-get parsed :rejected) '()))
            (should (equal (plist-get parsed :failed) '()))
            (let ((ps (plist-get parsed :pre_spawn)))
              (should (listp ps))
              (should (= 1 (length ps)))
              (should (equal (plist-get (car ps) :kind) "sensor_alert"))
              (should (equal (plist-get (car ps) :cause)
                             "panopticon_current_stale")))))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/pre-spawn-omitted-when-absent ()
  "Runs without `:pre_spawn' omit the key entirely from actions.json."
  (let ((dir (make-temp-file "satan-prespawn-absent-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done)
          (let* ((actions-path (expand-file-name "actions.json" dir))
                 (parsed (with-temp-buffer
                           (insert-file-contents actions-path)
                           (goto-char (point-min))
                           (json-parse-buffer :object-type 'plist
                                              :array-type 'list
                                              :null-object :null
                                              :false-object :false))))
            (should-not (plist-member parsed :pre_spawn))))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-accepts-pre-spawn-run ()
  "A run carrying a single `pre_spawn' sensor_alert and zero model
actions still verifies clean — `pre_spawn' must NOT pollute the
{applied,staged,rejected,failed} partition count invariant against
`final.actions'."
  (let ((dir (make-temp-file "satan-prespawn-verify-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "no model actions, sensor alert pre-spawn"
             :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :kind "sensor_alert"
                                        :cause "panopticon_current_stale"
                                        :severity "warning"
                                        :message "stale 28m"
                                        :remediation "systemctl --user status panopticon-sway"
                                        :suppressed :false
                                        :dispatched_at "2026-05-22T11:13Z")))
           'done)
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-rejects-malformed-pre-spawn ()
  "An entry missing the `kind' discriminator is malformed structure
(distinct from an unknown discriminant value).  Verifier flags it."
  (let ((dir (make-temp-file "satan-prespawn-bad-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "" :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :cause "no_kind_here")))
           'done)
          (let ((res (dl-satan-audit-verify-run dir)))
            (should (consp res))
            (should (assq 'pre-spawn-shape res))))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/verifier-accepts-unknown-pre-spawn-kind ()
  "Unknown `kind' discriminants are accepted gracefully (forward-compat);
only malformed STRUCTURE is rejected."
  (let ((dir (make-temp-file "satan-prespawn-unknown-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "" :actions ())
           (list :applied () :staged () :rejected () :failed ()
                 :pre_spawn (list (list :kind "future_thing_v2"
                                        :payload "whatever")))
           'done)
          (should (eq (dl-satan-audit-verify-run dir) t)))
      (delete-directory dir t))))

(ert-deftest dl-satan-audit/validate-actions-pure ()
  "`dl-satan-audit-validate-actions' is a pure (in-memory) validator over
the actions.json shape — usable from fixtures without touching disk."
  (should (null (dl-satan-audit-validate-actions
                 '(:applied () :staged () :rejected () :failed ()))))
  (should (null (dl-satan-audit-validate-actions
                 (list :applied () :staged () :rejected () :failed ()
                       :pre_spawn (list (list :kind "sensor_alert"
                                              :cause "x" :message "y"))))))
  (should (stringp (dl-satan-audit-validate-actions
                    (list :applied () :staged () :rejected () :failed ()
                          :pre_spawn (list (list :cause "no_kind")))))))

(ert-deftest dl-satan-audit/verifier-detects-orphan-call ()
  (let ((dir (make-temp-file "satan-run-" t)))
    (unwind-protect
        (progn
          (dl-satan-test--write-run
           dir
           '(:summary "s" :actions ())
           '(:applied () :staged () :rejected () :failed ())
           'done
           '((in tool-call (:id "a"))))
          (let ((res (dl-satan-audit-verify-run dir)))
            (should (consp res))
            (should (assq 'calls-match-results res))))
      (delete-directory dir t))))

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
