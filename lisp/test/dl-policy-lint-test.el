;;; dl-policy-lint-test.el --- ert tests for key policy lints -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans lisp/test), or M-x ert RET dl-policy-lint RET.

(require 'ert)
(require 'dl-policy-lint)

;;; Helpers

(defun dl-policy-lint-test--writes (form)
  "FORM's records as (MAP KEY COMMAND FORM-KIND) lists, in order."
  (mapcar (lambda (r)
            (list (plist-get r :map) (plist-get r :key)
                  (plist-get r :command) (plist-get r :form)))
          (my-policy-lint-form-records form)))

(defun dl-policy-lint-test--record (map key &rest props)
  "A record writing KEY into MAP, plus PROPS (defaults: command `ignore',
form `bind-keys', file \"a.el\", line 1)."
  (append (list :map map :key key) props
          (list :command 'ignore :form 'bind-keys :file "a.el" :line 1)))

(defmacro dl-policy-lint-test--with-file (contents &rest body)
  "Run BODY with `file' bound to a temp .el file holding CONTENTS."
  (declare (indent 1))
  `(let ((file (make-temp-file "dl-policy-lint-test" nil ".el" ,contents)))
     (unwind-protect (progn ,@body)
       (delete-file file))))

;;; L1 — `C-c <letter>' prefixes

(defvar-keymap my-policy-lint-test-family-map :name "test-family")

(ert-deftest dl-policy-lint/l1-family-by-naming ()
  "A keymap held by a `my-…-map' variable is allowed; a foreign keymap
or command on `C-c <letter>' is flagged; reserved singletons pass."
  (let ((map (make-sparse-keymap)))
    (define-key map "f" my-policy-lint-test-family-map)
    (define-key map "x" (make-sparse-keymap))
    (define-key map "y" #'forward-char)
    (define-key map "a" #'org-agenda)
    (should (equal (sort (mapcar (lambda (v) (list (plist-get v :key) (plist-get v :reason)))
                                 (my-policy-lint-scan map))
                         :key #'car)
                   '(("C-c x" foreign-map) ("C-c y" foreign-command))))))

(ert-deftest dl-policy-lint/l1-real-config ()
  "Every family prefix `dl-keymap' installs passes L1 (incl. `C-c i')."
  (require 'dl-keymap)
  (should-not (my-policy-lint-scan)))

;;; Records

(ert-deftest dl-policy-lint/records-bind-global ()
  "`:bind' without `:map' writes `global-map'; both list shapes parse."
  (should (equal (dl-policy-lint-test--writes
                  '(use-package foo :bind ("C-c x" . foo-x) :config (foo)))
                 '((global-map "C-c x" foo-x :bind))))
  (should (equal (dl-policy-lint-test--writes
                  '(use-package foo :bind (("C-c x" . foo-x) ("M-o" . #'foo-o))))
                 '((global-map "C-c x" foo-x :bind) (global-map "M-o" foo-o :bind)))))

(ert-deftest dl-policy-lint/records-bind-map-sections ()
  "`:map' switches the target map for the bindings that follow it."
  (should (equal (dl-policy-lint-test--writes
                  '(use-package foo
                     :bind (("C-c x" . foo-x)
                            :map foo-mode-map
                            ("C-c y" . foo-y))
                     (:map bar-map ("q" . bar-q))))
                 '((global-map "C-c x" foo-x :bind)
                   (foo-mode-map "C-c y" foo-y :bind)
                   (bar-map "q" bar-q :bind)))))

(ert-deftest dl-policy-lint/records-bind-map-list ()
  "`:map (A B)' writes each binding into both maps."
  (should (equal (dl-policy-lint-test--writes
                  '(use-package foo :bind (:map (a-map b-map) ("k" . foo-k))))
                 '((a-map "k" foo-k :bind) (b-map "k" foo-k :bind)))))

(ert-deftest dl-policy-lint/records-bind-star ()
  "`:bind*' writes `override-global-map' unless a `:map' is given."
  (should (equal (dl-policy-lint-test--writes
                  '(use-package foo :bind* ("C-." . foo-dot)))
                 '((override-global-map "C-." foo-dot :bind*)))))

(ert-deftest dl-policy-lint/records-empty-bind ()
  "`:bind' with no bindings (followed by another keyword) yields nothing."
  (should-not (my-policy-lint-form-records
               '(use-package foo :bind :config (setq a 1)))))

(ert-deftest dl-policy-lint/records-bind-keys ()
  "`bind-keys' writes `global-map' by default, or its `:map'."
  (should (equal (dl-policy-lint-test--writes
                  '(bind-keys ("M-z" . zap-up-to-char) ("C-x K" . kill-current-buffer)))
                 '((global-map "M-z" zap-up-to-char bind-keys)
                   (global-map "C-x K" kill-current-buffer bind-keys))))
  (should (equal (dl-policy-lint-test--writes
                  '(bind-keys :map comint-mode-map ("C-p" . comint-previous-input)))
                 '((comint-mode-map "C-p" comint-previous-input bind-keys)))))

(ert-deftest dl-policy-lint/records-my-bind ()
  "`my/bind' writes its literal map."
  (should (equal (dl-policy-lint-test--writes
                  '(my/bind my-file-map "f" #'find-file "find-file"))
                 '((my-file-map "f" find-file my/bind)))))

(ert-deftest dl-policy-lint/records-define-key-vector ()
  "`define-key' keys normalise from `kbd' strings, vectors and raw strings."
  (should (equal (dl-policy-lint-test--writes
                  '(progn (define-key foo-map (kbd "C-c C-k") #'foo-k)
                          (define-key foo-map [(shift return)] #'foo-ret)
                          (define-key foo-map "\C-x" #'foo-x)))
                 '((foo-map "C-c C-k" foo-k define-key)
                   (foo-map "S-<return>" foo-ret define-key)
                   (foo-map "C-x" foo-x define-key)))))

(ert-deftest dl-policy-lint/records-keymap-set-syntax ()
  "`keymap-set' / `keymap-global-set' keys are `keymap' syntax."
  (should (equal (dl-policy-lint-test--writes
                  '(progn (keymap-set org-mode-map "C-," #'embark-act)
                          (keymap-global-set "C-<prior>" 'tab-previous)))
                 '((org-mode-map "C-," embark-act keymap-set)
                   (global-map "C-<prior>" tab-previous keymap-global-set)))))

(ert-deftest dl-policy-lint/records-global-writers ()
  "`global-set-key', `global-unset-key', `local-set-key' are recorded."
  (should (equal (dl-policy-lint-test--writes
                  '(progn (global-unset-key (kbd "C-z"))
                          (global-set-key (kbd "C-z") 'undo)
                          (local-set-key (kbd "C-c C-c") #'foo)))
                 '((global-map "C-z" nil global-unset-key)
                   (global-map "C-z" undo global-set-key)
                   (local "C-c C-c" foo local-set-key)))))

(ert-deftest dl-policy-lint/records-remap-own-space ()
  "`[remap CMD]' normalises to \"<remap> <CMD>\", apart from real keys."
  (should (equal (dl-policy-lint-test--writes
                  '(progn (global-set-key [remap keyboard-quit] #'crux-quit)
                          (use-package dwim :bind ([remap shell-command] . dwim-sh))))
                 '((global-map "<remap> <keyboard-quit>" crux-quit global-set-key)
                   (global-map "<remap> <shell-command>" dwim-sh :bind)))))

(ert-deftest dl-policy-lint/records-non-literal-skipped ()
  "A non-literal map or key yields no record (e.g. `my/bind''s own body)."
  (should-not (my-policy-lint-form-records
               '(defun my/bind (map key cmd)
                  (define-key map (kbd key) cmd)
                  (keymap-set (foo) "C-a" #'bar)
                  (global-set-key key cmd)))))

(ert-deftest dl-policy-lint/records-nested ()
  "Writes nested in `:config', `with-eval-after-load' and defuns are found."
  (should (equal (dl-policy-lint-test--writes
                  '(use-package foo
                     :config
                     (with-eval-after-load 'bar
                       (global-set-key (kbd "M-Q") #'unfill))))
                 '((global-map "M-Q" unfill global-set-key)))))

(ert-deftest dl-policy-lint/records-quoted-data-ignored ()
  "Quoted data is not code: no records from inside `quote'."
  (should-not (my-policy-lint-form-records
               '(setq x '(global-set-key (kbd "C-a") #'foo)))))

;;; Files

(ert-deftest dl-policy-lint/file-records-position ()
  "Records carry the file and the top-level form's start line; comments
and commented-out code are not forms."
  (dl-policy-lint-test--with-file
      ";; (global-set-key (kbd \"C-a\") #'nope)\n\n(bind-keys\n (\"C-b\" . yes))\n"
    (let ((records (my-policy-lint-file-records file)))
      (should (equal (mapcar (lambda (r) (plist-get r :key)) records) '("C-b")))
      (should (= (plist-get (car records) :line) 3))
      (should (equal (plist-get (car records) :file)
                     (file-relative-name file user-emacs-directory))))))

(ert-deftest dl-policy-lint/file-unreadable-signals ()
  "A file that does not read signals an error naming it."
  (dl-policy-lint-test--with-file "(bind-keys (\"C-a\" . a))\n(oops"
    (let ((err (should-error (my-policy-lint-file-records file))))
      (should (string-match-p (regexp-quote (file-name-nondirectory file))
                              (error-message-string err))))))

(ert-deftest dl-policy-lint/file-odd-forms-survive ()
  "Improper and odd forms do not abort the file."
  (dl-policy-lint-test--with-file
      "(define-key . 3)\n(a b . c)\n(use-package x :bind :config)\n(use-package y :bind (\"C-a\" . nil) 3 . 4)\n(bind-keys :map)\n(global-set-key (kbd \"C-b\") #'b)\n"
    (should (member "C-b" (mapcar (lambda (r) (plist-get r :key))
                                  (my-policy-lint-file-records file))))))

(ert-deftest dl-policy-lint/config-files ()
  "Config files include `init.el' and core modules, never tests."
  (let ((files (mapcar (lambda (f) (file-relative-name f user-emacs-directory))
                       (my-policy-lint-config-files))))
    (should (member "init.el" files))
    (should (member "core/dl-keymap.el" files))
    (should-not (seq-some (lambda (f) (string-match-p "-test\\.el\\'\\|/test-" f))
                         files))))

;;; L2 — sanctioned forms

(defun dl-policy-lint-test--reasons (records)
  "L2 violations of RECORDS as (KEY REASON) lists."
  (mapcar (lambda (v) (list (plist-get v :key) (plist-get v :reason)))
          (my-policy-lint-form-violations records)))

(ert-deftest dl-policy-lint/l2-global-set-key-flagged ()
  "Global writers outside `bind-keys' / `:bind' are flagged; sanctioned
forms are not."
  (should (equal (dl-policy-lint-test--reasons
                  (my-policy-lint-form-records
                   '(progn (global-set-key (kbd "C-a") #'a)
                           (keymap-global-set "C-b" #'b)
                           (global-unset-key (kbd "C-c"))
                           (local-set-key (kbd "C-d") #'d)
                           (bind-keys ("C-e" . e))
                           (use-package f :bind ("C-f" . f)))))
                 '(("C-a" forbidden-form) ("C-b" forbidden-form)
                   ("C-c" forbidden-form) ("C-d" forbidden-form)))))

(ert-deftest dl-policy-lint/l2-define-key-mode-map-flagged ()
  "Literal `define-key' / `keymap-set' into any map is flagged."
  (should (equal (dl-policy-lint-test--reasons
                  (my-policy-lint-form-records
                   '(progn (define-key comint-mode-map (kbd "C-p") #'p)
                           (keymap-set org-mode-map "C-," #'embark-act))))
                 '(("C-p" forbidden-form) ("C-," forbidden-form)))))

(ert-deftest dl-policy-lint/l2-family-prefix-exempt ()
  "R3: `C-c <letter>' family prefixes in `core/dl-keymap.el' are exempt;
the same line elsewhere, or a non-family value, is not."
  (let ((prefix (dl-policy-lint-test--record
                 'global-map "C-c f" :command 'my-file-map :form 'define-key)))
    (should-not (my-policy-lint-form-violations
                 (list (plist-put (copy-sequence prefix) :file "core/dl-keymap.el"))))
    (should (my-policy-lint-form-violations
             (list (plist-put (copy-sequence prefix) :file "core/dl-other.el"))))
    (should (my-policy-lint-form-violations
             (list (dl-policy-lint-test--record
                    'global-map "C-c f" :command 'find-file :form 'define-key
                    :file "core/dl-keymap.el"))))))

(ert-deftest dl-policy-lint/l2-my-bind-foreign-map ()
  "`my/bind' into a map not named `my-…-map' is flagged."
  (should (equal (dl-policy-lint-test--reasons
                  (my-policy-lint-form-records
                   '(progn (my/bind my-file-map "f" #'find-file)
                           (my/bind org-mode-map "C-c x" #'x))))
                 '(("C-c x" my-bind-foreign-map)))))

;;; L3 — duplicates

(defun dl-policy-lint-test--dup-keys (records)
  "L3 duplicate groups of RECORDS as ((MAP . KEY) WRITER-COUNT) lists."
  (mapcar (lambda (d) (list (car d) (length (cdr d))))
          (my-policy-lint-duplicates records)))

(ert-deftest dl-policy-lint/l3-cross-file ()
  "One (map, key) written from two files is a duplicate; the same key in
different maps, and a remap of the same name, are not."
  (should (equal (dl-policy-lint-test--dup-keys
                  (list (dl-policy-lint-test--record 'global-map "C-:" :file "a.el")
                        (dl-policy-lint-test--record 'global-map "C-:" :file "b.el")
                        (dl-policy-lint-test--record 'org-mode-map "C-:")
                        (dl-policy-lint-test--record 'global-map "<remap> <C-:>")))
                 '(((global-map . "C-:") 2)))))

(ert-deftest dl-policy-lint/l3-same-file ()
  "Two writes of one key in one file — even of the same command — duplicate."
  (should (equal (dl-policy-lint-test--dup-keys
                  (list (dl-policy-lint-test--record 'global-map "C-z" :line 1)
                        (dl-policy-lint-test--record 'global-map "C-z" :line 9)))
                 '(((global-map . "C-z") 2)))))

(ert-deftest dl-policy-lint/l3-allow-listed ()
  "An allow-listed (map, key) is not reported."
  (let ((my-policy-lint-duplicate-allow-list
         '(((global-map . "C-z") "test: deliberate"))))
    (should-not (my-policy-lint-duplicates
                 (list (dl-policy-lint-test--record 'global-map "C-z")
                       (dl-policy-lint-test--record 'global-map "C-z"))))))

(provide 'dl-policy-lint-test)
;;; dl-policy-lint-test.el ends here
