;;; dl-satan-tools-notify.el --- notify.send tool handler -*- lexical-binding: t; -*-

;; Desktop notification via D-Bus.  Thin wrapper around
;; `notifications-notify' (built-in).  Visible to the user immediately,
;; so risk is `low' but never `read': included in the audit transcript
;; like any other tool call.

(require 'cl-lib)
(require 'notifications)
(require 'dl-satan-tools)

(defcustom dl-satan-notify-app "SATAN"
  "Application name shown in D-Bus notifications."
  :type 'string :group 'dl-satan)

(defcustom dl-satan-notify-default-timeout 8000
  "Default notification timeout in milliseconds."
  :type 'integer :group 'dl-satan)

(defun dl-satan-tool/notify-send (args _ctx)
  "Send a desktop notification via D-Bus.
ARGS: (:title STR :body STR :urgency low|normal|critical :timeout INT-MS).
Returns (ok :id N) | (error MSG)."
  (let* ((title   (plist-get args :title))
         (body    (plist-get args :body))
         (urgency (plist-get args :urgency))
         (timeout (or (plist-get args :timeout)
                      dl-satan-notify-default-timeout)))
    (cond
     ((not (and (stringp title) (stringp body)))
      (cons 'error "title and body must be strings"))
     (t
      (condition-case err
          (let ((id (notifications-notify
                     :title title
                     :body body
                     :app-name dl-satan-notify-app
                     :urgency (pcase urgency
                                ("low"      'low)
                                ("critical" 'critical)
                                (_          'normal))
                     :timeout timeout)))
            (cons 'ok (list :id id)))
        (error (cons 'error (error-message-string err))))))))

(dl-satan-tool-register
 (list :name "notify.send"
       :description "Send a desktop notification via D-Bus."
       :risk 'low
       :args-schema '(title   (:type string :required t)
                      body    (:type string :required t)
                      urgency (:type string :required nil
                               :enum ("low" "normal" "critical"))
                      timeout (:type integer :required nil))
       :modes '("morning" "motd")
       :handler 'dl-satan-tool/notify-send))

(provide 'dl-satan-tools-notify)
;;; dl-satan-tools-notify.el ends here
