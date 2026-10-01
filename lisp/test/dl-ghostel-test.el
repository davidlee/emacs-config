;;; dl-ghostel-test.el --- ert tests for ghostel integration -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-ghostel RET.

(require 'ert)
(require 'pixel-scroll)
(require 'dl-ghostel)

(ert-deftest dl-ghostel/paging-reaches-terminal ()
  "PgUp/PgDn go to the buffer's own map despite `pixel-scroll-precision-mode'.
Its minor-mode map otherwise wins and scrolls the Emacs window.  Wheel
scrolling stays smooth."
  (let ((pixel-scroll-precision-mode t)
        (terminal (make-sparse-keymap)))
    (keymap-set terminal "<prior>" #'ignore)
    (keymap-set terminal "<next>" #'ignore)
    (with-temp-buffer
      (use-local-map terminal)
      (dl-ghostel--pass-paging-keys)
      (should (eq (key-binding [prior]) #'ignore))
      (should (eq (key-binding [next]) #'ignore))
      (should (eq (key-binding [wheel-down]) #'pixel-scroll-precision)))))

(provide 'dl-ghostel-test)
;;; dl-ghostel-test.el ends here
