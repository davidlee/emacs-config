;;; test-sway-border.el --- ert tests for sway-border tools -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l test-sway-border.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools)
(require 'dl-satan-tools-sway)

;; ---------- nested-object validator extension ----------

(ert-deftest dl-satan-sway/validator-rejects-non-object ()
  (let ((spec (list :args-schema
                    '(classes (:type object :required t
                               :shape (focused (:type object :required nil
                                                :shape (border (:type string :required t)))))))))
    (should (stringp (dl-satan-tool-validate-args spec '(:classes "nope"))))))

(ert-deftest dl-satan-sway/validator-recurses-into-shape ()
  (let ((spec (list :args-schema
                    '(classes (:type object :required t
                               :shape (focused (:type object :required nil
                                                :shape (border (:type string :required t)))))))))
    (should (string-match-p
             "border"
             (dl-satan-tool-validate-args spec '(:classes (:focused (:background "#ffffff"))))))))

(ert-deftest dl-satan-sway/validator-skips-absent-class ()
  "Absent class keys do not trigger shape recursion."
  (let ((spec (list :args-schema
                    '(classes (:type object :required t
                               :shape (focused (:type object :required nil
                                                :shape (border (:type string :required t)))
                                       unfocused (:type object :required nil
                                                  :shape (border (:type string :required t)))))))))
    (should (null (dl-satan-tool-validate-args
                   spec '(:classes (:focused (:border "#ff0000"))))))))

(ert-deftest dl-satan-sway/validator-pattern-enforces-hex ()
  (let ((spec (list :args-schema
                    '(classes (:type object :required t
                               :shape (focused (:type object :required nil
                                                :shape (border (:type string :required t
                                                                :pattern "\\`#[0-9a-fA-F]\\{6\\}\\'")))))))))
    (should (string-match-p
             "match"
             (dl-satan-tool-validate-args
              spec '(:classes (:focused (:border "red"))))))))

;; ---------- JSON Schema mapper extension ----------

(ert-deftest dl-satan-sway/jsonschema-nests-properties ()
  (let* ((schema '(classes (:type object :required t
                            :shape (focused (:type object :required nil
                                             :shape (border (:type string :required t
                                                             :pattern "\\`#[0-9a-fA-F]\\{6\\}\\'")))))))
         (js (dl-satan-tool--args-schema-to-jsonschema schema))
         (classes-prop (plist-get (plist-get js :properties) :classes))
         (focused-prop (plist-get (plist-get classes-prop :properties) :focused))
         (border-prop  (plist-get (plist-get focused-prop :properties) :border)))
    (should (equal (plist-get js :type) "object"))
    (should (equal (append (plist-get js :required) nil) '("classes")))
    (should (equal (plist-get classes-prop :type) "object"))
    (should (equal (plist-get focused-prop :type) "object"))
    (should (equal (plist-get border-prop :type) "string"))
    (should (equal (plist-get border-prop :pattern)
                   "\\`#[0-9a-fA-F]\\{6\\}\\'"))))

;; ---------- sway_border_set handler ----------

(defvar dl-satan-sway-test--swaymsg-calls nil)

(defmacro dl-satan-sway-test--with-stub (&rest body)
  "Run BODY with `call-process' stubbed to record `swaymsg' argv."
  (declare (indent 0))
  `(let ((dl-satan-sway-test--swaymsg-calls nil))
     (cl-letf (((symbol-function 'call-process)
                (lambda (_prog _infile _dest _display &rest args)
                  (push args dl-satan-sway-test--swaymsg-calls)
                  0)))
       ,@body)))

(ert-deftest dl-satan-sway/set-emits-three-required-colours ()
  (dl-satan-sway-test--with-stub
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "s1" :name "sway_border_set"
                  :args (:classes
                         (:focused (:border "#ff0000"
                                    :background "#ff0000"
                                    :text "#ffffff"))))
                '("sway_border_set")
                nil)))
      (should (eq (plist-get res :ok) t))
      (should (equal (car dl-satan-sway-test--swaymsg-calls)
                     '("client.focused" "#ff0000" "#ff0000" "#ffffff")))
      (should (equal (plist-get (plist-get res :result) :applied)
                     '("focused"))))))

(ert-deftest dl-satan-sway/set-emits-optional-colours-when-given ()
  (dl-satan-sway-test--with-stub
    (dl-satan-tool-dispatch
     '(:type "tool_call" :id "s2" :name "sway_border_set"
       :args (:classes
              (:focused (:border "#000000"
                         :background "#111111"
                         :text "#ffffff"
                         :indicator "#aaaaaa"
                         :child_border "#222222"))))
     '("sway_border_set")
     nil)
    (should (equal (car dl-satan-sway-test--swaymsg-calls)
                   '("client.focused" "#000000" "#111111" "#ffffff"
                     "#aaaaaa" "#222222")))))

(ert-deftest dl-satan-sway/set-rejects-bad-hex ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "s3" :name "sway_border_set"
                :args (:classes (:focused (:border "red"
                                           :background "#ffffff"
                                           :text "#ffffff"))))
              '("sway_border_set")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "match" (plist-get res :error)))))

(ert-deftest dl-satan-sway/set-rejects-unknown-class ()
  (dl-satan-sway-test--with-stub
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "s4" :name "sway_border_set"
                  :args (:classes (:bindsym (:border "#ff0000"
                                             :background "#ff0000"
                                             :text "#ff0000"))))
                '("sway_border_set")
                nil)))
      (should (equal (plist-get res :ok) :false))
      (should (string-match-p "unknown class" (plist-get res :error)))
      (should (null dl-satan-sway-test--swaymsg-calls)))))

(ert-deftest dl-satan-sway/set-requires-border-background-text ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "s5" :name "sway_border_set"
                :args (:classes (:focused (:border "#ff0000"))))
              '("sway_border_set")
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p
             "\\(background\\|text\\|requires\\)"
             (plist-get res :error)))))

(ert-deftest dl-satan-sway/set-rejects-empty-classes ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "s6" :name "sway_border_set"
                :args (:classes nil))
              '("sway_border_set")
              nil)))
    (should (equal (plist-get res :ok) :false))))

(ert-deftest dl-satan-sway/set-applies-multiple-classes-in-order ()
  (dl-satan-sway-test--with-stub
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "s7" :name "sway_border_set"
                  :args (:classes
                         (:focused   (:border "#000000"
                                      :background "#000000"
                                      :text "#ffffff")
                          :unfocused (:border "#111111"
                                      :background "#111111"
                                      :text "#aaaaaa"))))
                '("sway_border_set")
                nil)))
      (should (eq (plist-get res :ok) t))
      ;; calls accumulated in reverse push order
      (let ((reversed (reverse dl-satan-sway-test--swaymsg-calls)))
        (should (equal (car (car reversed)) "client.focused"))
        (should (equal (car (cadr reversed)) "client.unfocused"))))))

;; ---------- sway_border_reset handler ----------

(ert-deftest dl-satan-sway/reset-emits-reload ()
  (dl-satan-sway-test--with-stub
    (let ((res (dl-satan-tool-dispatch
                '(:type "tool_call" :id "r1" :name "sway_border_reset"
                  :args nil)
                '("sway_border_reset")
                nil)))
      (should (eq (plist-get res :ok) t))
      (should (equal (car dl-satan-sway-test--swaymsg-calls)
                     '("reload"))))))

;; ---------- mode allowlist ----------

(ert-deftest dl-satan-sway/not-allowed-in-mode-without-tool ()
  (let ((res (dl-satan-tool-dispatch
              '(:type "tool_call" :id "x" :name "sway_border_reset"
                :args nil)
              '()
              nil)))
    (should (equal (plist-get res :ok) :false))
    (should (string-match-p "not allowed" (plist-get res :error)))))

(provide 'test-sway-border)
;;; test-sway-border.el ends here
