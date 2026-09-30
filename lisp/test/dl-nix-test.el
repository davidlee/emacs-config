;;; dl-nix-test.el --- ert tests for nix editing -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-nix RET.

(require 'ert)
(require 'dl-nix)
(require 'dl-format)
(require 'eglot)

(ert-deftest dl-nix/lsp-does-not-format ()
  "apheleia owns nix formatting; nixd must not also format on save."
  (with-temp-buffer
    (nix-mode)
    (should (memq :documentFormattingProvider
                  eglot-ignored-server-capabilities))
    (should-not (plist-get (plist-get (dl-nix-nixd-config) :nixd)
                           :formatting))))

(ert-deftest dl-nix/apheleia-formats-with-alejandra ()
  "Nix buffers are formatted by alejandra, matching the flake's treefmt."
  (should (eq (alist-get 'nix-mode apheleia-mode-alist) 'alejandra))
  (should (eq (alist-get 'nix-ts-mode apheleia-mode-alist) 'alejandra))
  (let ((command (alist-get 'alejandra apheleia-formatters)))
    (with-temp-buffer
      (insert "{ inherit a; }")
      (should (zerop (apply #'call-process-region (point-min) (point-max)
                            (car command) t t nil (cdr command))))
      (should (equal (buffer-string) "{inherit a;}\n")))))

(provide 'dl-nix-test)
;;; dl-nix-test.el ends here
