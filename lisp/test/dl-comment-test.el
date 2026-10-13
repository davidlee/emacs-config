;;; dl-comment-test.el --- ert tests for dl-comment -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-comment RET.

(require 'ert)
(require 'dl-comment)

(ert-deftest dl-comment/key-reaches-a-loadable-command ()
  "`M-;' runs a command whose library is installed.
comment-dwim-2 is missing on darwin; there `M-;' stays `comment-dwim'."
  (let ((command (keymap-lookup global-map "M-;")))
    (should (commandp command))
    (when (autoloadp (symbol-function command))
      (should (locate-library (cadr (symbol-function command)))))))

(provide 'dl-comment-test)
;;; dl-comment-test.el ends here
