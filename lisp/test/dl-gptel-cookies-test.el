;;; dl-gptel-cookies-test.el --- ert tests for @include, @expand, @notify -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-gptel-cookies RET.

;;; Code:

(require 'ert)
(require 'gptel)
(require 'notifications)   ; loaded now, so the stubs below stick
(require 'dl-gptel-cookies)

(defmacro dl-gptel-cookies-test--prompt (text &rest body)
  "Run BODY in a temp buffer holding TEXT, with point at its end."
  (declare (indent 1))
  `(with-temp-buffer
     (insert ,text)
     ,@body))

(ert-deftest dl-gptel-cookies/include-adds-buffers-and-files ()
  "@include adds each named buffer or file to the context, quoted or not."
  (let ((buffer (generate-new-buffer "dl-gptel-cookies-test"))
        (file (make-temp-file "dl-gptel-cookies-test")))
    (unwind-protect
        (with-temp-buffer
          (insert (format "@include \"%s\" %s\nsummarise" (buffer-name buffer) file))
          (goto-char (point-min))
          (search-forward "@include")
          (should (equal (dl-gptel-include-sources '(old))
                         (list file buffer 'old))))
      (kill-buffer buffer)
      (delete-file file))))

(ert-deftest dl-gptel-cookies/name-completion-only-after-a-sources-cookie ()
  "Buffer/file name completion is offered after @include and @gptel-annotate."
  (dolist (cookie '("@include " "@gptel-annotate \"x\" "))
    (dl-gptel-cookies-test--prompt (concat "look at " cookie "fo")
      (should (equal (seq-take (dl-gptel-source-name-capf) 2)
                     (list (- (point) 2) (point))))))
  (dl-gptel-cookies-test--prompt "@think fo"
    (should-not (dl-gptel-source-name-capf))))

(ert-deftest dl-gptel-cookies/expand-replaces-shell-and-elisp ()
  "@expand substitutes $:{shell} output and $:(elisp) values in the prompt."
  (dl-gptel-cookies-test--prompt "say $:{echo hi} and $:(+ 1 2)."
    (dl-gptel-expand-shell)
    (goto-char (point-max))
    (dl-gptel-expand-elisp)
    (should (equal (buffer-string) "say hi and 3."))))

(ert-deftest dl-gptel-cookies/expand-leaves-earlier-turns-alone ()
  "Only the prompt after the last response is expanded."
  (dl-gptel-cookies-test--prompt "old $:(+ 1 1)"
    (insert (propertize " reply " 'gptel 'response))
    (insert "new $:(+ 2 2)")
    (dl-gptel-expand-elisp)
    (should (equal (buffer-substring-no-properties (point-min) (point-max))
                   "old $:(+ 1 1) reply new 4"))))

(ert-deftest dl-gptel-cookies/notify-shows-the-start-of-the-reply ()
  "The completion notice names the chat and quotes the reply's start."
  (let (notice)
    (cl-letf (((symbol-function 'notifications-notify)
               (lambda (&rest args) (setq notice args))))
      (dl-gptel-cookies-test--prompt "prompt"
        (rename-buffer "chat" t)
        (let ((start (point-marker)))
          (insert "the answer")
          (dl-gptel-notify-response
           (list :position start :tracking-marker (point-marker)
                 :buffer (current-buffer)))))
      (should (string-prefix-p "gptel: chat" (plist-get notice :title)))
      (should (equal (plist-get notice :body) "the answer")))))

(provide 'dl-gptel-cookies-test)
;;; dl-gptel-cookies-test.el ends here
