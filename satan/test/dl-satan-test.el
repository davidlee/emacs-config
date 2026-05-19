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
(require 'dl-satan-tools-sway)
(require 'dl-satan-memory)
(require 'dl-satan-context)
(require 'dl-satan-output)
(require 'dl-satan-audit)
(require 'dl-satan-broker)
(require 'dl-satan-budget)
(require 'dl-satan-mode)
(require 'dl-satan-tick)

;; ---------- dl-satan-jsonl ----------

(ert-deftest dl-satan-jsonl/parses-complete-line ()
  (let* ((seen nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (obj) (push obj seen))
                  (lambda (_err) (error "should not error")))))
    (funcall filter nil "{\"type\":\"ready\",\"run_id\":\"r1\"}\n")
    (should (equal (length seen) 1))
    (should (equal (plist-get (car seen) :type) "ready"))
    (should (equal (plist-get (car seen) :run_id) "r1"))))

(ert-deftest dl-satan-jsonl/joins-chunked-line ()
  (let* ((seen nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (obj) (push obj seen))
                  (lambda (_err) (error "should not error")))))
    (funcall filter nil "{\"type\":\"log\",")
    (funcall filter nil "\"message\":\"x\"}\n")
    (should (equal (length seen) 1))
    (should (equal (plist-get (car seen) :type) "log"))))

(ert-deftest dl-satan-jsonl/holds-partial-trailing-line ()
  (let* ((seen nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (obj) (push obj seen))
                  (lambda (_err) (error "should not error")))))
    (funcall filter nil "{\"type\":\"log\",\"message\":\"a\"}\n{\"type\":")
    (should (equal (length seen) 1))
    (funcall filter nil "\"log\",\"message\":\"b\"}\n")
    (should (equal (length seen) 2))))

(ert-deftest dl-satan-jsonl/reports-parse-error ()
  (let* ((errs nil)
         (filter (dl-satan-jsonl-make-filter
                  (lambda (_obj) (error "should not call on-object"))
                  (lambda (e) (push e errs)))))
    (funcall filter nil "not-json\n")
    (should (equal (length errs) 1))
    (should (equal (car (car errs)) "not-json"))))

;; ---------- dl-satan-block ----------

(ert-deftest dl-satan-block/replace-ok ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "* h\n"
                    "#+begin_satan :block satan :owner SATAN :updated [old]\n"
                    "old body\n"
                    "#+end_satan\n"
                    "* tail\n"))
          (should (eq (dl-satan-block-replace file "satan" "new body") 'ok))
          (let ((s (with-temp-buffer (insert-file-contents file) (buffer-string))))
            (should (string-match-p "new body\n" s))
            (should-not (string-match-p "old body" s))
            (should (string-match-p ":updated \\[20" s))
            (should (string-match-p "\\* tail" s))))
      (delete-file file))))

(ert-deftest dl-satan-block/multi-match-refuses ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file
            (insert "#+begin_satan :block satan :owner SATAN :updated [a]\nA\n#+end_satan\n\n"
                    "#+begin_satan :block satan :owner SATAN :updated [b]\nB\n#+end_satan\n"))
          (should (eq (dl-satan-block-replace file "satan" "new") 'multi-match)))
      (delete-file file))))

(ert-deftest dl-satan-block/none-match-noop ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "no block here\n"))
          (should (eq (dl-satan-block-replace file "satan" "new") 'none-match)))
      (delete-file file))))

(ert-deftest dl-satan-block/create-at-end ()
  (let ((file (make-temp-file "satan-block-" nil ".org")))
    (unwind-protect
        (progn
          (with-temp-file file (insert "* header\nbody\n"))
          (should (eq (dl-satan-block-create-at-end file "satan" "fresh") 'ok))
          (let ((s (with-temp-buffer (insert-file-contents file) (buffer-string))))
            (should (string-match-p "#\\+begin_satan :block satan :owner SATAN :updated \\[20" s))
            (should (string-match-p "fresh\n#\\+end_satan" s))))
      (delete-file file))))

;; ---------- dl-satan-tools schema validator ----------

(ert-deftest dl-satan-tools/schema-required-missing ()
  (let ((spec (list :args-schema '(scope (:type string :required t
                                          :enum ("today" "week"))))))
    (should (stringp (dl-satan-tool-validate-args spec '())))))

(ert-deftest dl-satan-tools/schema-enum-violation ()
  (let ((spec (list :args-schema '(scope (:type string :required t
                                          :enum ("today" "week"))))))
    (should (stringp (dl-satan-tool-validate-args spec '(:scope "year"))))))

(ert-deftest dl-satan-tools/schema-ok ()
  (let ((spec (list :args-schema '(scope (:type string :required t
                                          :enum ("today" "week"))))))
    (should (null (dl-satan-tool-validate-args spec '(:scope "today"))))))

(ert-deftest dl-satan-tools/schema-array-non-array-rejected ()
  (let ((spec (list :args-schema '(tags (:type array :items string)))))
    (should (string-match-p
             "tags must be array"
             (dl-satan-tool-validate-args spec '(:tags "foo"))))))

(ert-deftest dl-satan-tools/schema-array-of-scalars-ok ()
  (let ((spec (list :args-schema '(tags (:type array :items string)))))
    (should (null (dl-satan-tool-validate-args spec '(:tags ("a" "b")))))))

(ert-deftest dl-satan-tools/schema-array-element-type-mismatch ()
  (let ((spec (list :args-schema '(tags (:type array :items string)))))
    (should (string-match-p
             "tags\\[1\\]"
             (dl-satan-tool-validate-args spec '(:tags ("a" 2)))))))

(ert-deftest dl-satan-tools/schema-array-of-objects-shape-ok ()
  (let ((spec (list :args-schema
                    '(rows (:type array
                            :items (:type object
                                    :shape (id (:type string :required t))))))))
    (should (null (dl-satan-tool-validate-args
                   spec '(:rows ((:id "x") (:id "y"))))))))

(ert-deftest dl-satan-tools/schema-array-of-objects-shape-missing-required ()
  (let ((spec (list :args-schema
                    '(rows (:type array
                            :items (:type object
                                    :shape (id (:type string :required t))))))))
    (should (string-match-p
             "id"
             (dl-satan-tool-validate-args spec '(:rows ((:other "x"))))))))

(ert-deftest dl-satan-tools/jsonschema-items-scalar ()
  (let* ((params (dl-satan-tool--args-schema-to-jsonschema
                  '(tags (:type array :items string))))
         (tags (plist-get (plist-get params :properties) :tags)))
    (should (equal (plist-get tags :type) "array"))
    (should (equal (plist-get tags :items) (list :type "string")))))

(ert-deftest dl-satan-tools/jsonschema-items-object-shape ()
  (let* ((params (dl-satan-tool--args-schema-to-jsonschema
                  '(rows (:type array
                          :items (:type object
                                  :shape (id (:type string :required t)))))))
         (rows (plist-get (plist-get params :properties) :rows))
         (items (plist-get rows :items)))
    (should (equal (plist-get items :type) "object"))
    (should (equal (plist-get (plist-get items :properties) :id)
                   (list :type "string")))
    (should (equal (plist-get items :required) ["id"]))))

(ert-deftest dl-satan-tools/dispatch-unknown ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "x" :name "no.such" :args nil)
              '("no.such")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "unknown tool" (plist-get res :error)))))

(ert-deftest dl-satan-tools/dispatch-not-allowed ()
  (dl-satan-tool-register
   (list :name "test.allowed-check"
         :args-schema nil
         :handler (lambda (_a _c) (cons 'ok '(:done t)))))
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "x" :name "test.allowed-check" :args nil)
              '()
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "not allowed" (plist-get res :error)))))

;; ---------- dl-satan-tools-notify ----------

(ert-deftest dl-satan-notify/dispatch-ok ()
  "notify.send dispatches via the registry, stubbing the D-Bus call."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) 42)))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n1" :name "notify_send"
                  :args (:title "hi" :body "there"))
                '("notify_send")
                nil)))
      (should (eq (plist-get res :ok) t))
      (should (equal (plist-get (plist-get res :result) :id) 42)))))

(ert-deftest dl-satan-notify/schema-missing-title ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n2" :name "notify_send"
                :args (:body "x"))
              '("notify_send")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "title" (plist-get res :error)))))

(ert-deftest dl-satan-notify/schema-urgency-enum ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n3" :name "notify_send"
                :args (:title "t" :body "b" :urgency "screaming"))
              '("notify_send")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "urgency" (plist-get res :error)))))

(ert-deftest dl-satan-notify/handler-error-propagates ()
  "If `notifications-notify' signals, the result is `error' with message."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) (error "no D-Bus today"))))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n4" :name "notify_send"
                  :args (:title "t" :body "b"))
                '("notify_send")
                nil)))
      (should (equal (plist-get res :ok) :false))
      (should (string-match-p "no D-Bus" (plist-get res :error))))))

;; ---------- dl-satan-tools-inbox ----------

(ert-deftest dl-satan-inbox/handler-appends-headline ()
  (let* ((tmp (make-temp-file "satan-inbox-"))
         (dl-satan-inbox-file tmp))
    (unwind-protect
        (let* ((res (dl-satan-tool/inbox-append
                     '(:title "Daily plan ready"
                       :body "Focus section blank; nudge to fill in.")
                     '(:id "r1" :mode-name "motd"
                       :capabilities (inbox-write)))))
          (should (eq (car res) 'ok))
          (let ((text (with-temp-buffer
                        (insert-file-contents tmp)
                        (buffer-string))))
            (should (string-match-p "#\\+title:    SATAN inbox" text))
            (should (string-match-p "^\\* \\[.*\\] Daily plan ready" text))
            (should (string-match-p ":unread:satan:" text))
            (should (string-match-p ":RUN_ID: r1" text))
            (should (string-match-p "Focus section blank" text))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest dl-satan-inbox/capability-required ()
  (let ((res (dl-satan-tool/inbox-append
              '(:title "t" :body "b")
              '(:capabilities (write-daily)))))
    (should (eq (car res) 'error))
    (should (string-match-p "inbox-write" (cdr res)))))

(ert-deftest dl-satan-inbox/append-preserves-existing ()
  (let* ((tmp (make-temp-file "satan-inbox-"))
         (dl-satan-inbox-file tmp))
    (unwind-protect
        (progn
          (dl-satan-tool/inbox-append
           '(:title "first" :body "a")
           '(:id "r1" :mode-name "motd" :capabilities (inbox-write)))
          (dl-satan-tool/inbox-append
           '(:title "second" :body "b" :urgency "urgent")
           '(:id "r1" :mode-name "motd" :capabilities (inbox-write)))
          (let ((text (with-temp-buffer
                        (insert-file-contents tmp)
                        (buffer-string))))
            (should (string-match-p "first" text))
            (should (string-match-p "second" text))
            (should (string-match-p ":urgent:" text))))
      (when (file-exists-p tmp) (delete-file tmp)))))

(ert-deftest dl-satan-inbox/unread-count-matches-tags ()
  (let* ((tmp (make-temp-file "satan-inbox-"))
         (dl-satan-inbox-file tmp))
    (unwind-protect
        (progn
          (should (equal (my/satan-inbox-unread-count) 0))
          (dl-satan-tool/inbox-append
           '(:title "a" :body "x")
           '(:capabilities (inbox-write)))
          (dl-satan-tool/inbox-append
           '(:title "b" :body "y")
           '(:capabilities (inbox-write)))
          (should (equal (my/satan-inbox-unread-count) 2)))
      (when (file-exists-p tmp) (delete-file tmp)))))

;; ---------- dl-satan-tools-hippocampus ----------

(ert-deftest dl-satan-hippocampus/handler-writes-denote-file ()
  (let* ((tmp (make-temp-file "satan-hippo-" t))
         (dl-satan-hippocampus-dir tmp))
    (unwind-protect
        (let* ((res (dl-satan-tool/hippocampus-write
                     '(:title "Avoid mocking the DB"
                       :body "User burned by a mock/prod divergence in 2026 Q1.")
                     '(:id "r1" :mode-name "morning"
                       :capabilities (hippocampus-write)))))
          (should (eq (car res) 'ok))
          (let* ((path (plist-get (cdr res) :path))
                 (text (with-temp-buffer
                         (insert-file-contents path)
                         (buffer-string))))
            (should (string-match-p "__satan_hippocampus\\.org$" path))
            (should (string-match-p ":satan:hippocampus:" text))
            (should (string-match-p ":RUN_ID: r1" text))
            (should (string-match-p "mock/prod divergence" text))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-hippocampus/capability-required ()
  (let ((res (dl-satan-tool/hippocampus-write
              '(:title "t" :body "b")
              '(:capabilities (write-daily)))))
    (should (eq (car res) 'error))
    (should (string-match-p "hippocampus-write" (cdr res)))))

(ert-deftest dl-satan-hippocampus/schema-required ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "m1" :name "hippocampus_write"
                :args (:body "x"))
              '("hippocampus_write")
              '(:capabilities (hippocampus-write)))))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "title" (plist-get res :error)))))

;; ---------- dl-satan-tools-org ----------

(ert-deftest dl-satan-org/update-owned-block-rejects-motd-target ()
  "motd is no longer a writable target; satan_final.summary owns motd."
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "u1" :name "org_update_owned_block"
                :args (:target "motd" :block "satan" :content "x"))
              '("org_update_owned_block")
              '(:capabilities (write-daily)))))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "target" (plist-get res :error)))))

(ert-deftest dl-satan-org/update-owned-block-tool-not-in-motd-mode ()
  "motd mode's :tools list must not include org_update_owned_block."
  (let* ((mode (dl-satan-mode-resolve "motd"))
         (tools (plist-get mode :tools)))
    (should-not (member "org_update_owned_block" tools))))

(ert-deftest dl-satan-org/update-owned-block-only-registered-for-morning ()
  "Tool registration restricts org_update_owned_block to morning mode."
  (let* ((spec (dl-satan-tool-lookup "org_update_owned_block"))
         (modes (plist-get spec :modes)))
    (should (member "morning" modes))
    (should-not (member "motd" modes))))

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
     ("sway_border_set"        . "Retint sway window borders.")
     ("sway_border_reset"      . "Restore sway borders.")
     ("bough_read"             . "Read from bough.")
     ("memory_mark"            . "Mark a memory trace.")
     ("memory_resonate"        . "Resonate against handles.")
     ("memory_show_trace"      . "Show a memory trace.")
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
    (should (equal (plist-get mode :budget-tokens) 10000))
    (should (equal (plist-get mode :budget-tool-calls) 4))
    (should (equal (plist-get mode :timeout-seconds) 30))
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
     ("sway_border_set"        . "Retint sway borders.")
     ("sway_border_reset"      . "Restore sway borders.")
     ("bough_read"             . "Read bough.")
     ("memory_mark"            . "Mark.")
     ("memory_resonate"        . "Resonate.")
     ("memory_show_trace"      . "Show.")
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
                    (dir (expand-file-name run-id root))
                    (status-path (expand-file-name "status" dir)))
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

(ert-deftest dl-satan-protocol/fixtures-valid-pass ()
  "Every fixture marked `valid' validates clean."
  (dolist (entry (dl-satan-protocol-fixtures))
    (when (string= (plist-get entry :kind) "valid")
      (let* ((direction (dl-satan-test--protocol-fixture-direction entry))
             (msg (plist-get entry :message))
             (err (dl-satan-protocol-validate direction msg)))
        (should (null err))))))

(ert-deftest dl-satan-protocol/fixtures-invalid-fail ()
  "Every fixture marked `invalid' validates to a reason matching the fixture's reason."
  (dolist (entry (dl-satan-protocol-fixtures))
    (when (string= (plist-get entry :kind) "invalid")
      (let* ((direction (dl-satan-test--protocol-fixture-direction entry))
             (msg (plist-get entry :message))
             (expected (plist-get entry :reason))
             (name (plist-get entry :name))
             (err (dl-satan-protocol-validate direction msg)))
        (should (not (null err)))
        (should
         (equal expected (plist-get err :reason)))
        (ignore name)))))

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
