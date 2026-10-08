;;; dl-policy-lint.el --- Key policy lints -*- lexical-binding: t; -*-

;; Enforces the key policy codified in `KEYS.md'.  Three lints:
;;
;; - L1 (live keymap) walks `mode-specific-map' (the global `C-c'
;;   prefix) and reports any single-letter binding whose value is
;;   neither a family map (the value of a variable named `my-…-map')
;;   nor an explicitly reserved singleton (`C-c a' org-agenda, `C-c c'
;;   org-capture, `C-c l' org-store-link).
;;   - M-x `my-policy-lint' pops `*Policy Lint*'.
;;   - On startup, a silent scan runs from `emacs-startup-hook'; it
;;     logs to *Messages* iff violations are found, never opens a buffer.
;;   It catches foreign packages that grab `C-c <letter>' from their
;;   `:config' (`ready-player' / `rg.el' clobbered `C-c m' / `C-c s'
;;   before this lint existed).
;;
;; - L2 (source) flags keymap writes outside the sanctioned forms.
;; - L3 (source) flags a (map, key) written more than once.
;;
;; L2 and L3 read config sources without loading them: each literal
;; keymap write becomes a record plist
;;
;;   (:map global-map :key "C-:" :command avy-goto-char
;;    :form :bind :file "editing/dl-motion.el" :line 12)
;;
;; They are plain functions run by `lisp/test/dl-policy-lint-test.el'
;; (`just check'); nothing but L1 runs at startup.

(require 'seq)

;;; Family naming

(defun my-policy-lint--family-name-p (symbol)
  "Non-nil when SYMBOL is named `my-…-map' (the family map convention)."
  (and (symbolp symbol)
       (let ((name (symbol-name symbol)))
         (and (string-prefix-p "my-" name) (string-suffix-p "-map" name)))))

(defun my-policy-lint--family-maps ()
  "Keymaps held by variables named `my-…-map'."
  (let (maps)
    (mapatoms (lambda (sym)
                (when (and (my-policy-lint--family-name-p sym)
                           (boundp sym)
                           (keymapp (symbol-value sym)))
                  (push (symbol-value sym) maps))))
    maps))

;;; L1 — `C-c <letter>' (live keymap)

(defconst my-policy-lint-reserved-singletons
  '((?a . org-agenda)
     (?c . org-capture)
     (?l . org-store-link))
  "Per `KEYS.md' Policy clause 6: single-letter `C-c <letter>' commands
allowed to bind directly to a command instead of a `my-*-map' family.")

(defun my-policy-lint--letter-p (event)
  (and (characterp event)
    (or (and (>= event ?a) (<= event ?z))
      (and (>= event ?A) (<= event ?Z)))))

(defun my-policy-lint-scan (&optional map)
  "Return Policy violations in MAP (default `mode-specific-map').
Each entry: (:key STRING :binding BINDING :reason SYMBOL).
Reason is `foreign-map' (a keymap no `my-…-map' variable holds) or
`foreign-command' (a non-prefix command outside the reserved set)."
  (let ((family-maps (my-policy-lint--family-maps))
        violations)
    (map-keymap
      (lambda (event binding)
        (when (my-policy-lint--letter-p event)
          (let ((key (format "C-c %c" event)))
            (cond
              ((keymapp binding)
                (unless (memq binding family-maps)
                  (push (list :key key :binding binding :reason 'foreign-map)
                    violations)))
              ((or (symbolp binding) (functionp binding))
                (let ((reserved (alist-get event my-policy-lint-reserved-singletons)))
                  (unless (eq binding reserved)
                    (push (list :key key :binding binding :reason 'foreign-command)
                      violations))))
              (t
                (push (list :key key :binding binding :reason 'foreign-command)
                  violations))))))
      (or map mode-specific-map))
    (nreverse violations)))

(defun my-policy-lint--format-binding (binding)
  (cond
    ((keymapp binding)
      (let ((prompt (keymap-prompt binding)))
        (format "<keymap%s>" (if prompt (format " %S" prompt) ""))))
    ((symbolp binding) (symbol-name binding))
    (t (format "%S" binding))))

;;;###autoload
(defun my-policy-lint ()
  "Report Policy violations under `C-c <letter>'.
Pops `*Policy Lint*' when there are violations; otherwise echoes
\"clean\".  Returns the violation list."
  (interactive)
  (let ((violations (my-policy-lint-scan)))
    (cond
      ((null violations)
        (message "my-policy-lint: clean (no `C-c <letter>' Policy violations)."))
      (t
        (with-current-buffer (get-buffer-create "*Policy Lint*")
          (let ((inhibit-read-only t))
            (erase-buffer)
            (insert "Policy violations under `C-c <letter>'\n")
            (insert "=======================================\n\n")
            (dolist (v violations)
              (insert (format "  %-10s  %s  (%s)\n"
                        (plist-get v :key)
                        (my-policy-lint--format-binding (plist-get v :binding))
                        (plist-get v :reason))))
            (insert "\nSee KEYS.md `Policy'.  Lift offending bindings into\n"
              "`core/dl-keymap.el' under the appropriate `my-*-map' family,\n"
              "or disable the foreign package's global key install.\n")
            (goto-char (point-min)))
          (display-buffer (current-buffer)))
        (message "my-policy-lint: %d Policy violation(s) — see *Policy Lint*."
          (length violations))))
    violations))

(defun my-policy-lint--startup-check ()
  "Silent startup scan: log a one-line summary iff violations exist."
  (let ((violations (my-policy-lint-scan)))
    (when violations
      (message "my-policy-lint: %d Policy violation(s) under `C-c <letter>' — M-x my-policy-lint."
        (length violations)))))

(add-hook 'emacs-startup-hook #'my-policy-lint--startup-check)

;;; Records — literal keymap writes in source forms

(defconst my-policy-lint--writers
  '((define-key        0          1 raw    2)
    (keymap-set        0          1 keymap 2)
    (my/bind           0          1 kbd    2)
    (global-set-key    global-map 0 raw    1)
    (keymap-global-set global-map 0 keymap 1)
    (global-unset-key  global-map 0 raw    nil)
    (local-set-key     local      0 raw    1))
  "Positional writers: (FN MAP KEY-ARG SYNTAX COMMAND-ARG).
MAP is an argument index or a fixed map symbol; SYNTAX is how a key
string parses (`raw' event string, `kbd', or `keymap' syntax).")

(defun my-policy-lint--elements (list)
  "Elements of LIST, dropping an improper tail."
  (let (out)
    (while (consp list) (push (pop list) out))
    (nreverse out)))

(defun my-policy-lint--key (key syntax)
  "Normalised description of literal KEY, or nil when KEY is not literal.
A string parses per SYNTAX; `(kbd STRING)' and vectors are accepted too."
  (when-let* ((keys (ignore-errors
                      (pcase key
                        ((pred vectorp) key)
                        (`(kbd ,(and (pred stringp) s)) (kbd s))
                        ((pred stringp) (pcase syntax
                                          ('kbd (kbd key))
                                          ('keymap (key-parse key))
                                          (_ key)))))))
    (key-description keys)))

(defun my-policy-lint--command (form)
  "FORM with a `#'' or `'' quote stripped."
  (pcase form
    (`(,(or 'function 'quote) ,sym) sym)
    (_ form)))

(defun my-policy-lint--maps (map)
  "Literal map symbols named by MAP (a symbol or a list of symbols)."
  (seq-filter (lambda (m) (and m (symbolp m) (not (keywordp m))))
              (ensure-list map)))

(defun my-policy-lint--record (map key command form)
  (list :map map :key key :command command :form form))

(defun my-policy-lint--writer-records (args spec form)
  "Records for positional writer FORM called with ARGS, per SPEC."
  (pcase-let* ((`(,map-at ,key-at ,syntax ,command-at) spec)
               (map (if (integerp map-at) (nth map-at args) map-at))
               (key (my-policy-lint--key (nth key-at args) syntax)))
    (when (and key (symbolp map))
      (mapcar (lambda (m)
                (my-policy-lint--record
                 m key (and command-at (my-policy-lint--command (nth command-at args)))
                 form))
              (my-policy-lint--maps map)))))

(defun my-policy-lint--binding-records (items map form)
  "Records for ITEMS, a `bind-keys' / `:bind' list targeting MAP.
ITEMS holds (KEY . COMMAND) pairs, `:map M' switches (M a symbol or
list), other keyword arguments, and nested lists of the same."
  (let (records)
    (while (consp items)
      (let ((item (pop items)))
        (cond
          ((eq item :map) (setq map (car-safe items) items (cdr-safe items)))
          ((keywordp item) (setq items (cdr-safe items)))
          ((and (consp item) (or (stringp (car item)) (vectorp (car item))))
            (let ((key (my-policy-lint--key (car item) 'kbd)))
              (when key
                (dolist (m (my-policy-lint--maps map))
                  (push (my-policy-lint--record
                         m key (my-policy-lint--command (cdr item)) form)
                        records)))))
          ((consp item)
            (setq records (append (reverse (my-policy-lint--binding-records item map form))
                                  records))))))
    (nreverse records)))

(defun my-policy-lint--use-package-records (args)
  "Records for the `:bind' / `:bind*' sections of `use-package' ARGS."
  (let (records)
    (while (consp args)
      (let ((arg (pop args)))
        (when (memq arg '(:bind :bind*))
          (let (items)
            (while (and (consp args) (not (keywordp (car args))))
              (push (pop args) items))
            (setq records
                  (append records
                          (my-policy-lint--binding-records
                           (nreverse items)
                           (if (eq arg :bind) 'global-map 'override-global-map)
                           arg)))))))
    records))

(defun my-policy-lint--own-records (form)
  "Records for FORM's own head, ignoring its subforms."
  (let ((head (car form))
        (args (my-policy-lint--elements (cdr form))))
    (pcase head
      ('use-package (my-policy-lint--use-package-records (cdr args)))
      ('bind-keys (my-policy-lint--binding-records args 'global-map 'bind-keys))
      (_ (let ((spec (alist-get head my-policy-lint--writers)))
           (and spec (my-policy-lint--writer-records args spec head)))))))

(defun my-policy-lint-form-records (form)
  "Literal keymap writes in FORM and its subforms, as record plists.
Quoted data is not walked."
  (when (and (consp form) (not (eq (car form) 'quote)))
    (apply #'append
           (my-policy-lint--own-records form)
           (mapcar #'my-policy-lint-form-records
                   (my-policy-lint--elements form)))))

(defun my-policy-lint-file-records (file)
  "Records for every top-level form in FILE, adding :file and :line.
:file is relative to `user-emacs-directory'; :line is the top-level
form's first line.  Signals an error when FILE does not read."
  (let ((rel (file-relative-name file user-emacs-directory))
        records)
    (with-temp-buffer
      (insert-file-contents file)
      (with-syntax-table emacs-lisp-mode-syntax-table
        (while (progn (forward-comment (buffer-size)) (not (eobp)))
          (let* ((line (line-number-at-pos))
                 (form (condition-case err (read (current-buffer))
                         (error (error "my-policy-lint: cannot read %s:%d: %S"
                                       rel line err)))))
            (dolist (r (my-policy-lint-form-records form))
              (push (append r (list :file rel :line line)) records))))))
    (nreverse records)))

(defconst my-policy-lint-config-dirs
  '("core" "lisp" "org" "editing" "completion" "apps" "lang" "dev")
  "Config directories (relative to `user-emacs-directory') read by L2/L3.")

(defun my-policy-lint--test-file-p (name)
  "Non-nil when NAME (a basename) is an ERT file, per `dl-test--file-p'."
  (or (string-suffix-p "-test.el" name) (string-prefix-p "test-" name)))

(defun my-policy-lint-config-files ()
  "Absolute paths of config sources: `init.el' and the top level of
`my-policy-lint-config-dirs', excluding tests and dotfiles."
  (cons (expand-file-name "init.el" user-emacs-directory)
        (seq-remove (lambda (f) (my-policy-lint--test-file-p (file-name-nondirectory f)))
                    (mapcan (lambda (dir)
                              (directory-files (expand-file-name dir user-emacs-directory)
                                               t "\\`[^.].*\\.el\\'"))
                            my-policy-lint-config-dirs))))

;;; L2 — sanctioned forms

(defconst my-policy-lint-forbidden-forms
  '(define-key keymap-set global-set-key keymap-global-set global-unset-key
     local-set-key)
  "Writers forbidden in config (R2): use `bind-keys' or `:bind'.")

(defun my-policy-lint--family-prefix-p (record)
  "Non-nil when RECORD is an R3 family prefix: `C-c <letter>' bound to
a `my-…-map' in `global-map', written in `core/dl-keymap.el'."
  (and (equal (plist-get record :file) "core/dl-keymap.el")
       (eq (plist-get record :map) 'global-map)
       (string-match-p "\\`C-c [a-zA-Z]\\'" (plist-get record :key))
       (my-policy-lint--family-name-p (plist-get record :command))))

(defun my-policy-lint--violation (record)
  "L2 reason RECORD breaks the rules, or nil."
  (let ((form (plist-get record :form)))
    (cond
      ((and (memq form my-policy-lint-forbidden-forms)
            (not (my-policy-lint--family-prefix-p record)))
        'forbidden-form)
      ((and (eq form 'my/bind)
            (not (my-policy-lint--family-name-p (plist-get record :map))))
        'my-bind-foreign-map))))

(defun my-policy-lint-form-violations (records)
  "L2: RECORDS written by a forbidden form, each with a :reason."
  (seq-keep (lambda (r)
              (let ((reason (my-policy-lint--violation r)))
                (and reason (cons :reason (cons reason r)))))
            records))

;;; L3 — duplicates

(defconst my-policy-lint-duplicate-allow-list nil
  "Deliberate duplicate writes (R4): entries ((MAP . KEY) REASON).")

(defun my-policy-lint-duplicates (records)
  "L3: ((MAP . KEY) . RECORDS) for every slot RECORDS write more than
once, minus `my-policy-lint-duplicate-allow-list'."
  (seq-filter (lambda (group)
                (and (cddr group)
                     (not (assoc (car group) my-policy-lint-duplicate-allow-list))))
              (seq-group-by (lambda (r) (cons (plist-get r :map) (plist-get r :key)))
                            records)))

(provide 'dl-policy-lint)
;;; dl-policy-lint.el ends here
