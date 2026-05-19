;;; dl-secret.el --- secret management -*- lexical-binding: t; -*-

;;; Commentary:
;; Three concerns, one home:
;;
;; 1. Auth-source helpers — pull from gnome-keyring / netrc / etc via
;;    `auth-source-search'.
;; 2. 1Password CLI — resolve `op://vault/item/field' refs at call time so
;;    secrets live only in Emacs heap, never on disk.
;; 3. Env-file sourcing — read shell env exports at startup so an Emacs
;;    launched from sway (which never runs zshrc) still sees the same
;;    variables a terminal session would.

;;; Code:

(require 'auth-source)

;;;; Auth-source

(defun my/auth-source-secret (&rest spec)
  "Return the :secret string for SPEC (a plist of `auth-source-search' args),
or nil. Forces `:require \\='(:secret)' so partial matches are dropped."
  (when-let* ((found  (car (apply #'auth-source-search
                             (append spec '(:require (:secret))))))
               (secret (plist-get found :secret)))
    (encode-coding-string
      (if (functionp secret) (funcall secret) secret)
      'utf-8)))

;; (my/auth-source-secret :host "openrouter.ai" :user "apikey")

;;;; 1Password CLI

(defcustom my/op-cli "op"
  "Path to the 1Password CLI executable."
  :type 'string
  :group 'my)

(defvar my/op--cache (make-hash-table :test 'equal)
  "Session cache mapping op:// refs to resolved plaintext.")

(defun my/op-read (ref &optional refresh)
  "Resolve a 1Password REF (op://vault/item/field) to its plaintext value.
Cached for the Emacs session. With non-nil REFRESH, bypass the cache.
Signals an error if `op' is missing, unauthenticated, or the ref is bad."
  (or (and (not refresh) (gethash ref my/op--cache))
      (let* ((stderr-file (make-temp-file "op-stderr-"))
              (status nil)
              (stdout
                (unwind-protect
                  (with-output-to-string
                    (with-current-buffer standard-output
                      (setq status
                        (call-process my/op-cli nil
                          (list standard-output stderr-file)
                          nil "read" "--no-newline" ref))))
                  (when (file-exists-p stderr-file)
                    (let ((err (with-temp-buffer
                                 (insert-file-contents stderr-file)
                                 (string-trim (buffer-string)))))
                      (delete-file stderr-file)
                      (unless (eq status 0)
                        (error "op read %s failed (%s): %s" ref status err))))))
              (val (string-trim stdout)))
        (puthash ref val my/op--cache)
        val)))

(defun my/op-read-env (var &optional refresh)
  "Return the value of environment variable VAR.
If VAR's value begins with `op://', resolve it via 1Password and return the
resolved string; otherwise return the value as-is. Returns nil when VAR is
unset. With non-nil REFRESH, bypass the op cache."
  (when-let* ((raw (getenv var)))
    (if (string-prefix-p "op://" raw)
      (my/op-read raw refresh)
      raw)))

(defun my/op-forget ()
  "Clear cached 1Password secrets for this Emacs session."
  (interactive)
  (clrhash my/op--cache))

;;;; Env-file sourcing
;;
;; Sway / desktop launchers never invoke the user's shell init, so Emacs
;; comes up without the env vars a terminal session would have. Parse a
;; declared list of shell env files at load time and `setenv' any vars we
;; find. Only sets vars that are currently unset, so a terminal-launched
;; Emacs (which inherited the resolved values) wins over the op://
;; placeholders in the file.

(defcustom my/env-source-files
  '("~/.config/zsh/env.zsh"
    "~/.config/zsh/work.identity.zsh")
  "Shell env files to parse on load.

Each file is read for lines matching `[export] NAME=VALUE'. Surrounding
single or double quotes are stripped. No shell expansion is performed,
so values containing `$VAR' or command substitution will be wrong.
Designed for plain `op://...' refs and similar literal strings."
  :type '(repeat file)
  :group 'my)

(defconst my/env-source-line-re
  "^[ \t]*\\(?:export[ \t]+\\)?\\([A-Za-z_][A-Za-z0-9_]*\\)=\\(.*\\)$"
  "Regex for a sourceable `NAME=VALUE' line.")

(defun my/env--strip-quotes (s)
  (replace-regexp-in-string "\\`[\"']\\|[\"']\\'" "" s))

(defun my/source-env-file (file)
  "Parse FILE and `setenv' each declared var that is not already set."
  (let ((path (expand-file-name file)))
    (when (file-readable-p path)
      (with-temp-buffer
        (insert-file-contents path)
        (goto-char (point-min))
        (while (re-search-forward my/env-source-line-re nil t)
          (let ((name (match-string 1))
                 (val  (string-trim (my/env--strip-quotes (match-string 2)))))
            (unless (getenv name)
              (setenv name val))))))))

(defun my/source-env-files ()
  "Source every file in `my/env-source-files'."
  (mapc #'my/source-env-file my/env-source-files))

(my/source-env-files)

(provide 'dl-secret)
;;; dl-secret.el ends here
