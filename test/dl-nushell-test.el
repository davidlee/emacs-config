;;; dl-nushell-test.el --- ert tests for dl-nushell -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-nushell RET.

(require 'ert)
(require 'cl-lib)

(defun dl-nushell-test--configured-p (grammar-p)
  "Return non-nil if dl-nushell sets up the mode when GRAMMAR-P says nu exists."
  (let ((load-prefer-newer t))
    (provide 'nushell-ts-mode)
    (fmakunbound 'my/nushell-mode-hook)
    (unwind-protect
        (cl-letf (((symbol-function 'treesit-language-available-p)
                   (lambda (&rest _) grammar-p)))
          (load "dl-nushell" nil t))
      (setq features (delq 'nushell-ts-mode features)))
    (fboundp 'my/nushell-mode-hook)))

(ert-deftest dl-nushell/configures-with-the-grammar ()
  "Hosts with the nu grammar keep the mode."
  (should (dl-nushell-test--configured-p t)))

(ert-deftest dl-nushell/skips-without-the-grammar ()
  "Loading `nushell-ts-mode' without its grammar warns at startup."
  (should-not (dl-nushell-test--configured-p nil)))

(provide 'dl-nushell-test)
;;; dl-nushell-test.el ends here
