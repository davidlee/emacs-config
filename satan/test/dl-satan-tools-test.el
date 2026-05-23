;;; dl-satan-tools-test.el --- ert tests for dl-satan-tools registry/validator/dispatcher -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l dl-satan-tools-test.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools)
(require 'dl-satan-tools-notify)

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

(provide 'dl-satan-tools-test)
;;; dl-satan-tools-test.el ends here
