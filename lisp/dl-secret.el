;;; dl-secret.el --- secret management -*- lexical-binding: t; -*-

;; (let* ((found  (car (auth-source-search :host "openrouter.ai"
;;                       :user "apikey"
;;                       :require '(:secret))))
;;         (secret (plist-get found :secret)))
;;   (if (functionp secret) (funcall secret) secret))

;; Reusable helper:

(defun my/auth-source-secret (&rest spec)
  "Return the :secret string for SPEC (a plist of `auth-source-search' args),
  or nil. Forces :require '(:secret) so partial matches are dropped."
  (when-let* ((found  (car (apply #'auth-source-search
                             (append spec '(:require (:secret))))))
               (secret (plist-get found :secret)))
    (encode-coding-string
      (if (functionp secret) (funcall secret) secret)
      'utf-8)))

;; (my/auth-source-secret :host "openrouter.ai" :user "apikey")

;;  Notes:
;;   - :require '(:secret) filters out matches missing a secret — otherwise you can get hits with
;;   no usable value.
;;   - encode-coding-string … 'utf-8 matches what gptel-api-key-from-auth-source does. Drop it if
;;   you don't care.
;;   - auth-source caches negative lookups for the Emacs session — after rewriting a secret, run
;;   M-x auth-source-forget-all-cached or the next search may still return nil.
;;   - For gptel-style use (:key slot), pass a 0-arg lambda or function symbol, not the resolved
;;   string — gptel re-resolves per request so a stale key doesn't get pinned.

(provide 'dl-secret)
;;; dl-secret.el ends here
