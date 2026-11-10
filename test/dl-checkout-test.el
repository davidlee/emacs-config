;;; dl-checkout-test.el --- ert tests for dl-checkout -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-checkout RET.
;;
;; Every test works inside a throwaway directory put at the head
;; of `load-path' under unique library names, so no real checkout
;; (~/dev/satan) is ever compiled.

(require 'ert)
(require 'bytecomp)
(require 'dl-checkout)

(defun dl-checkout-test--write (dir name)
  "Write a trivial compilable library called NAME into DIR."
  (with-temp-file (expand-file-name name dir)
    (insert (format ";;; %s --- test fixture -*- lexical-binding: t; -*-\n\n"
                    name)
            (format "(provide '%s)\n" (file-name-base name))
            (format ";;; %s ends here\n" name))))

(defmacro dl-checkout-test--with-checkout (dir-var &rest body)
  "Run BODY with DIR-VAR bound to a temp dir holding lib `fake-lib.el'.
The directory heads `load-path'; the fixture library names are unique,
so no real checkout is located or compiled."
  (declare (indent 1) (debug t))
  `(let ((,dir-var (make-temp-file "dl-checkout-test" t)))
     (unwind-protect
         (progn
           (dl-checkout-test--write ,dir-var "fake-lib.el")
           (let ((load-path (cons ,dir-var load-path)))
             ,@body))
       (delete-directory ,dir-var t))))

(defun dl-checkout-test--elcs (dir)
  "Return the `.elc' file names in DIR, sorted."
  (sort (directory-files dir nil "\\.elc\\'") #'string<))

(ert-deftest dl-checkout/compiles-missing-elc ()
  "A checkout with no .elc is interpreted; the whole of it gets compiled."
  (dl-checkout-test--with-checkout dir
    (should-not (file-exists-p (expand-file-name "fake-lib.elc" dir)))
    (dl-checkout-compile-stale "fake-lib.el")
    (should (file-exists-p (expand-file-name "fake-lib.elc" dir)))))

(ert-deftest dl-checkout/compiles-whole-directory ()
  "Every stale `.el' in LIBRARY's directory is compiled, not LIBRARY alone."
  (dl-checkout-test--with-checkout dir
    (dl-checkout-test--write dir "other-lib.el")
    (dl-checkout-compile-stale "fake-lib.el")
    (should (equal (dl-checkout-test--elcs dir)
                   '("fake-lib.elc" "other-lib.elc")))))

(ert-deftest dl-checkout/skips-fresh-elc ()
  "An up-to-date .elc is left alone: recompiling costs startup time."
  (dl-checkout-test--with-checkout dir
    (let ((elc (expand-file-name "fake-lib.elc" dir)))
      (dl-checkout-compile-stale "fake-lib.el")
      (should (file-exists-p elc))
      (set-file-times elc (time-add (current-time) 60))
      (let ((stamp (file-attribute-modification-time (file-attributes elc))))
        (dl-checkout-compile-stale "fake-lib.el")
        (should (equal (file-attribute-modification-time (file-attributes elc))
                       stamp))))))

(ert-deftest dl-checkout/does-nothing-while-compiling ()
  "Another compiler owns where .elc files go, so no .elc may be written."
  (dl-checkout-test--with-checkout dir
    (let ((byte-compile-current-file "some-other-file.el"))
      (dl-checkout-compile-stale "fake-lib.el"))
    (should-not (dl-checkout-test--elcs dir))))

(ert-deftest dl-checkout/ignores-missing-library ()
  "No checkout for LIBRARY means nothing to compile, and no error."
  (dl-checkout-test--with-checkout dir
    (should-not (dl-checkout-compile-stale "no-such-lib-xyz.el"))
    (should-not (dl-checkout-test--elcs dir))))

(provide 'dl-checkout-test)
;;; dl-checkout-test.el ends here
