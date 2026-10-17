;;; dl-llm-gateway.el --- local LLM gateway access -*- lexical-binding: t; -*-

;;; Commentary:
;; One concern: where the local LLM gateway is, and what a named client's
;; key is.  Each client (gptel, minuet, ...) has a key file in
;; `dl-llm-gateway-key-directory', issued with `llm-gateway issue'.
;;
;; Keys are read on every call: no cache, no environment mutation, no 1Password
;; fallback.  Whether a key exists is not checked at load time, so Emacs
;; starts cleanly before keys are issued.  Clients pass
;; (lambda () (dl-llm-gateway-key "CLIENT")) as their key function.

;;; Code:

(defgroup dl-llm-gateway nil "Local LLM gateway access." :group 'tools)

(defcustom dl-llm-gateway-url "http://127.0.0.1:4000/v1"
  "Base URL of the local LLM gateway (OpenAI-compatible)." :type 'string)

(defcustom dl-llm-gateway-key-directory "~/.config/llm-gateway/keys"
  "Directory holding one key file per gateway client." :type 'directory)

(defun dl-llm-gateway--key-file (client)
  "Return the absolute path of CLIENT's key file."
  (expand-file-name client dl-llm-gateway-key-directory))

(defun dl-llm-gateway--read-key (file)
  "Return trimmed contents of FILE, or nil if unreadable or blank."
  (when (file-readable-p file)
    (let ((key (string-trim
                (with-temp-buffer (insert-file-contents file)
                                  (buffer-string)))))
      (unless (string-empty-p key) key))))

(defun dl-llm-gateway-key (client)
  "Return gateway CLIENT's key, read from its key file now.
Signal `user-error' naming CLIENT and the issue command if the file is
missing, unreadable or empty."
  (let ((file (dl-llm-gateway--key-file client)))
    (or (dl-llm-gateway--read-key file)
        (let ((shown (abbreviate-file-name file)))
          (user-error "No LLM gateway key for %s at %s; issue one: llm-gateway issue %s --models … --budget … --out %s"
                      client shown client shown)))))

(provide 'dl-llm-gateway)
;;; dl-llm-gateway.el ends here
