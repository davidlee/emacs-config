;;; dl-gptel-emcp-test.el --- ert tests for the emcp→gptel tool adapter -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gptel-emcp RET.

;;; Code:

(require 'ert)
(require 'dl-gptel-emcp)
(require 'dl-gptel-readonly)

(emcp-deftool dl-gptel-emcp-test--greet
    ((name "Who to greet")
     (greeting "Salutation" :default "hello")
     (times "Repetitions" :type "integer" :default 1))
  "Greet NAME.  Some names fail, each in a different way."
  :name "greet"
  :async t
  (pcase name
    ("nobody" (send-result '((content . [((type . "text") (text . "no one"))])
                             (isError . t))))
    ("ghost" (send-error -32000 "not found"))
    ("boom" (error "Boom"))
    (_ (send-result
        `((content . [((type . "text")
                       (text . ,(string-join
                                 (make-list times (format "%s %s" greeting name))
                                 " ")))]))))))

(defun dl-gptel-emcp-test--call (tool &rest values)
  "Call the gptel function adapted from emcp TOOL with VALUES; return its result."
  (let (result)
    (apply (plist-get (dl-gptel-emcp-tool-spec tool) :function)
           (lambda (r) (setq result r))
           values)
    result))

(ert-deftest dl-gptel-emcp/spec-describes-the-tool ()
  "Name, description and arguments come from the emcp metadata."
  (let ((spec (dl-gptel-emcp-tool-spec 'dl-gptel-emcp-test--greet)))
    (should (equal (plist-get spec :name) "greet"))
    (should (equal (plist-get spec :description)
                   "Greet NAME.  Some names fail, each in a different way."))
    (should (equal (plist-get spec :category) "introspection"))
    (should (plist-get spec :async))
    (should (equal (plist-get spec :args)
                   '((:name "name" :type string :description "Who to greet")
                     (:name "greeting" :type string :description "Salutation"
                            :optional t)
                     (:name "times" :type integer :description "Repetitions"
                            :optional t))))))

(ert-deftest dl-gptel-emcp/omitted-optional-arguments-take-defaults ()
  "An omitted optional argument, which gptel passes as nil, takes its default."
  (should (equal (dl-gptel-emcp-test--call 'dl-gptel-emcp-test--greet "ada")
                 "hello ada"))
  (should (equal (dl-gptel-emcp-test--call 'dl-gptel-emcp-test--greet "ada" nil 2)
                 "hello ada hello ada"))
  (should (equal (dl-gptel-emcp-test--call 'dl-gptel-emcp-test--greet "ada" "hi")
                 "hi ada")))

(ert-deftest dl-gptel-emcp/failures-reach-the-model-as-text ()
  "Error results, protocol errors and signals all answer the callback."
  (should (equal (dl-gptel-emcp-test--call 'dl-gptel-emcp-test--greet "nobody")
                 "Error: no one"))
  (should (equal (dl-gptel-emcp-test--call 'dl-gptel-emcp-test--greet "ghost")
                 "Error: not found"))
  (should (equal (dl-gptel-emcp-test--call 'dl-gptel-emcp-test--greet "boom")
                 "Error: Boom")))

(ert-deftest dl-gptel-emcp/find-references-reads-loaded-code ()
  "The adapted find-references locates call sites in loaded libraries."
  (let ((text (dl-gptel-emcp-test--call 'emcp-tools-find-references
                                        "dl-gptel-readonly--parse" "function")))
    (should (string-match-p "dl-gptel-readonly\\.el" text))))

(provide 'dl-gptel-emcp-test)
;;; dl-gptel-emcp-test.el ends here
