;;; dl-term-test.el --- ert tests for terminal display -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-term RET.

(require 'ert)
(require 'dl-term)

(defun dl-term-test--terminal (name)
  "A buffer NAME that the `ghostel-mode' display rule matches."
  (with-current-buffer (get-buffer-create name)
    (setq major-mode 'ghostel-mode)
    (current-buffer)))

(defmacro dl-term-test--with-dock (&rest body)
  "Run BODY with `dock', a dedicated bottom window showing terminal `first'.
`display-buffer-alist' holds only the terminal rule."
  (declare (indent 0))
  `(let ((display-buffer-alist (list dl-term-ghostel-display-rule))
         (first (dl-term-test--terminal "*dl-term-test:first*"))
         (second (dl-term-test--terminal "*dl-term-test:second*")))
     (save-window-excursion
       (delete-other-windows)
       (unwind-protect
           (let ((dock (display-buffer first)))
             ,@body)
         (kill-buffer first)
         (kill-buffer second)))))

(ert-deftest dl-term/first-terminal-docks-dedicated ()
  (dl-term-test--with-dock
    (should (equal (length (window-list)) 2))
    (should (window-dedicated-p dock))))

(ert-deftest dl-term/new-terminal-replaces-the-dock ()
  "A second terminal takes the dock rather than opening a window beside it."
  (dl-term-test--with-dock
    (should (eq (display-buffer second) dock))
    (should (equal (length (window-list)) 2))
    (should (window-dedicated-p dock))))

(ert-deftest dl-term/dock-refuses-other-buffers ()
  "Dedication survives the swap, so ordinary buffers still go elsewhere."
  (dl-term-test--with-dock
    (display-buffer second)
    (with-temp-buffer
      (should-not (eq (display-buffer (current-buffer)) dock)))))

(defconst dl-term-test--ghostel-dir
  (expand-file-name "elpa/ghostel/lisp" user-emacs-directory)
  "Ghostel's package-vc checkout; absent outside a provisioned config.")

(ert-deftest dl-term/eshell-visual-commands-run-in-ghostel ()
  "Loading eshell routes visual commands (less, htop) through ghostel."
  (skip-unless (file-directory-p dl-term-test--ghostel-dir))
  (let ((load-path (cons dl-term-test--ghostel-dir load-path)))
    (require 'ghostel-eshell))
  (unwind-protect
      (progn
        (run-hooks 'eshell-load-hook)
        (should ghostel-eshell-visual-command-mode))
    (ghostel-eshell-visual-command-mode -1)))

(provide 'dl-term-test)
;;; dl-term-test.el ends here
