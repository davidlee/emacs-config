;;; dl-eglot-test.el --- ert tests for eglot on-save -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-eglot RET.

(require 'ert)
(require 'cl-lib)
(require 'dl-eglot)

(defun dl-eglot-test--formats-on-save-p (capable)
  "Whether saving formats when the server's formatting capability is CAPABLE."
  (let (formatted)
    (cl-letf (((symbol-function 'my/eglot-connected-p) #'always)
              ((symbol-function 'eglot-server-capable) (lambda (&rest _) capable))
              ((symbol-function 'eglot-format-buffer)
               (lambda () (setq formatted t))))
      (my/eglot-format-buffer-if-connected)
      formatted)))

(ert-deftest dl-eglot/save-formats-when-server-can ()
  (should (dl-eglot-test--formats-on-save-p t)))

(ert-deftest dl-eglot/save-skips-format-when-server-cannot ()
  "A server without (or ignoring) formatting must not error on save."
  (should-not (dl-eglot-test--formats-on-save-p nil)))

(provide 'dl-eglot-test)
;;; dl-eglot-test.el ends here
