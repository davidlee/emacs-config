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
(require 'dl-satan-block)
(require 'dl-satan-tools)
(require 'dl-satan-tools-notify)
(require 'dl-satan-tools-memory)
(require 'dl-satan-tools-org)
(require 'dl-satan-context)
(require 'dl-satan-output)
(require 'dl-satan-audit)
(require 'dl-satan-broker)
(require 'dl-satan-mode)

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
                '(:type "tool_call" :id "n1" :name "notify.send"
                  :args (:title "hi" :body "there"))
                '("notify.send")
                nil)))
      (should (eq (plist-get res :ok) t))
      (should (equal (plist-get (plist-get res :result) :id) 42)))))

(ert-deftest dl-satan-notify/schema-missing-title ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n2" :name "notify.send"
                :args (:body "x"))
              '("notify.send")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "title" (plist-get res :error)))))

(ert-deftest dl-satan-notify/schema-urgency-enum ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "n3" :name "notify.send"
                :args (:title "t" :body "b" :urgency "screaming"))
              '("notify.send")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "urgency" (plist-get res :error)))))

(ert-deftest dl-satan-notify/handler-error-propagates ()
  "If `notifications-notify' signals, the result is `error' with message."
  (cl-letf (((symbol-function 'notifications-notify)
             (lambda (&rest _args) (error "no D-Bus today"))))
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "n4" :name "notify.send"
                  :args (:title "t" :body "b"))
                '("notify.send")
                nil)))
      (should (equal (plist-get res :ok) :false))
      (should (string-match-p "no D-Bus" (plist-get res :error))))))

;; ---------- dl-satan-tools-memory ----------

(ert-deftest dl-satan-memory/handler-writes-denote-file ()
  (let* ((tmp (make-temp-file "satan-mem-" t))
         (dl-satan-memory-candidates-dir tmp))
    (unwind-protect
        (let* ((res (dl-satan-tool/memory-add-candidate
                     '(:title "Avoid mocking the DB"
                       :body "User burned by a mock/prod divergence in 2026 Q1.")
                     '(:id "r1" :mode-name "morning"
                       :capabilities (memory-candidate)))))
          (should (eq (car res) 'ok))
          (let* ((path (plist-get (cdr res) :path))
                 (text (with-temp-buffer
                         (insert-file-contents path)
                         (buffer-string))))
            (should (string-match-p "__satan_memory\\.org$" path))
            (should (string-match-p ":satan:memory:candidate:" text))
            (should (string-match-p ":RUN_ID: r1" text))
            (should (string-match-p "mock/prod divergence" text))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-memory/capability-required ()
  (let ((res (dl-satan-tool/memory-add-candidate
              '(:title "t" :body "b")
              '(:capabilities (write-daily)))))
    (should (eq (car res) 'error))
    (should (string-match-p "memory-candidate" (cdr res)))))

(ert-deftest dl-satan-memory/schema-required ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "m1" :name "memory.add_candidate"
                :args (:body "x"))
              '("memory.add_candidate")
              '(:capabilities (memory-candidate)))))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "title" (plist-get res :error)))))

;; ---------- dl-satan self-edit context + output ----------

(ert-deftest dl-satan-self-edit/context-bundles-sources ()
  "context-fn assembles scaffold + mode prompt and includes matching sources."
  (let* ((tmp (make-temp-file "satan-se-" t))
         (dl-satan-self-edit-root tmp)
         (user-emacs-directory tmp)
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp)))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "prompts" tmp))
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file (expand-file-name "system/scaffold.txt" tmp)
            (insert "SCAFFOLD\n"))
          (with-temp-file (expand-file-name "prompts/se.txt" tmp)
            (insert "PROMPT\n"))
          (with-temp-file (expand-file-name "a.el" tmp) (insert "(provide 'a)"))
          (with-temp-file (expand-file-name "b.py" tmp) (insert "x = 1"))
          (with-temp-file (expand-file-name "a.elc" tmp) (insert "skip"))
          (let* ((spec (list :name "self-edit"
                             :prompt-file (expand-file-name "prompts/se.txt" tmp)))
                 (bundle (dl-satan-context-self-edit spec))
                 (sources (plist-get bundle :sources))
                 (paths (mapcar (lambda (s) (plist-get s :path)) sources)))
            (should (equal (plist-get bundle :prompt) "SCAFFOLD\n\nPROMPT"))
            (should (member "a.el" paths))
            (should (member "b.py" paths))
            (should-not (member "a.elc" paths))
            (let ((a (cl-find "a.el" sources
                              :key (lambda (s) (plist-get s :path))
                              :test #'equal)))
              (should (equal (plist-get a :content) "(provide 'a)")))))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/missing-prompt-errors ()
  "Mode prompt missing → context-fn signals; run cannot start."
  (let* ((tmp (make-temp-file "satan-ctx-" t))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/scaffold.txt" tmp))
         (dl-satan-self-edit-root tmp)
         (user-emacs-directory tmp))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "system" tmp))
          (with-temp-file dl-satan-system-scaffold-file (insert "S"))
          (let ((spec (list :name "self-edit"
                            :prompt-file
                            (expand-file-name "prompts/never.txt" tmp))))
            (should-error (dl-satan-context-self-edit spec)
                          :type 'error)))
      (delete-directory tmp t))))

(ert-deftest dl-satan-context/missing-scaffold-errors ()
  "System scaffold missing → context-fn signals."
  (let* ((tmp (make-temp-file "satan-ctx-" t))
         (dl-satan-prompts-dir (expand-file-name "prompts/" tmp))
         (dl-satan-system-scaffold-file
          (expand-file-name "system/missing.txt" tmp))
         (dl-satan-self-edit-root tmp)
         (user-emacs-directory tmp))
    (unwind-protect
        (progn
          (make-directory (expand-file-name "prompts" tmp))
          (with-temp-file (expand-file-name "prompts/se.txt" tmp) (insert "P"))
          (let ((spec (list :name "self-edit"
                            :prompt-file
                            (expand-file-name "prompts/se.txt" tmp))))
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
   '(("satan.final" . "Terminate the run; describe what you did."))
   (lambda ()
     (let* ((js (dl-satan-tool-final-schema))
            (fn (plist-get js :function))
            (params (plist-get fn :parameters)))
       (should (equal (plist-get fn :name) "satan.final"))
       (should (string-match-p "Terminate" (plist-get fn :description)))
       (should (equal (append (plist-get params :required) nil) '("summary")))))))

;; ---------- dl-satan-broker manifest assembly ----------

(ert-deftest dl-satan-broker/manifest-tools-shape ()
  "Manifest carries one JSON Schema per allowed tool plus satan.final."
  (dl-satan-test--with-tool-descriptions
   '(("org.read_context"      . "Read a slice of the notes corpus.")
     ("org.update_owned_block" . "Replace a SATAN-owned org block.")
     ("proposal.stage"         . "Stage a proposal.")
     ("notify.send"            . "Send a desktop notification.")
     ("memory.add_candidate"   . "Stage a candidate memory.")
     ("satan.final"            . "Terminate the run."))
   (lambda ()
     (let* ((mode (dl-satan-mode-resolve "morning"))
            (manifest (dl-satan-broker--build-manifest mode "test-run"))
            (tools (append (plist-get manifest :tools) nil))
            (names (mapcar (lambda (t-) (plist-get (plist-get t- :function) :name))
                           tools)))
       (should (equal (plist-get manifest :run_id) "test-run"))
       (should (member "org.read_context" names))
       (should (member "org.update_owned_block" names))
       (should (member "notify.send" names))
       (should (member "memory.add_candidate" names))
       (should (member "satan.final" names))
       ;; Descriptions came from notes files, not elisp.
       (let ((notify (cl-find "notify.send" tools
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
                  :actions ((:type "proposal.stage"
                             :args (:title "fix" :body "do the thing"))
                            (:type "org.update_owned_block"
                             :args (:target "today" :block "satan" :content "x")))))
         (ctx (list :id "r1" :mode-name "self-edit"
                    :capabilities '(stage-proposal))))
    (unwind-protect
        (let ((p (dl-satan-output/self-edit final ctx)))
          (should (equal (length (plist-get p :applied)) 1))
          (should (equal (length (plist-get p :staged)) 1))
          (should (equal (plist-get (car (plist-get p :applied)) :type)
                         "proposal.stage")))
      (delete-directory tmp t))))

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

(provide 'dl-satan-test)
;;; dl-satan-test.el ends here
