;;; dl-keymap-shadow-test.el --- ert tests for minor-mode key yielding -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-keymap-shadow RET.

(require 'ert)
(require 'dl-keymap-shadow)

(defvar dl-keymap-shadow-test-mode-map
  (define-keymap "a" #'upcase-word "b" #'downcase-word))

(define-minor-mode dl-keymap-shadow-test-mode
  "Minor mode whose map shadows the buffer's own keys.")

(defun dl-keymap-shadow-test--check-yield ()
  "Yield `a' in one buffer: it reaches the local map there, not elsewhere.
`b' stays shadowed by the minor mode."
  (let ((local (define-keymap "a" #'ignore "b" #'ignore)))
    (with-temp-buffer
      (use-local-map local)
      (dl-keymap-shadow-test-mode)
      (dl-keymap-shadow-yield 'dl-keymap-shadow-test-mode "a")
      (should (eq (key-binding "a") #'ignore))
      (should (eq (key-binding "b") #'downcase-word))
      (with-temp-buffer
        (use-local-map local)
        (dl-keymap-shadow-test-mode)
        (should (eq (key-binding "a") #'upcase-word))))))

(ert-deftest dl-keymap-shadow/yields-minor-mode-map ()
  "A map registered in `minor-mode-map-alist' (`define-minor-mode')."
  (dl-keymap-shadow-test--check-yield))

(ert-deftest dl-keymap-shadow/yields-emulation-map ()
  "A map registered inline in `emulation-mode-map-alists', as meow does.
It outranks every minor-mode map, so it must be replaced there."
  (let ((emulation-mode-map-alists
          (cons `((dl-keymap-shadow-test-mode . ,dl-keymap-shadow-test-mode-map))
            emulation-mode-map-alists)))
    (dl-keymap-shadow-test--check-yield)))

(provide 'dl-keymap-shadow-test)
;;; dl-keymap-shadow-test.el ends here
