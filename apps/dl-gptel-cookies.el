;;; dl-gptel-cookies.el --- what @include, @expand and @notify do -*- lexical-binding: t; -*-

;;; Commentary:
;; The behaviour behind three prompt-side presets (the table is in
;; dl-gptel-presets.el), adapted from karthink's gptel-preset-collection
;; (GPL-3.0-or-later):
;;
;;   @include "buf" file   add the named buffers and files to the context
;;   @expand               replace $:{shell} and $:(elisp) in the prompt
;;                         with their output — it runs what you typed, so
;;                         mind pasted text
;;   @notify               desktop notice when the reply lands
;;
;; `dl-gptel-source-name-capf' completes buffer and file names after
;; @include and after gptel-annotate's @gptel-annotate, which takes the
;; same arguments.

;;; Code:

(require 'map)
(require 'gptel)
(require 'text-property-search)

(declare-function notifications-notify "notifications")

;;;; @include

(defun dl-gptel-include-sources (context)
  "Return CONTEXT plus the buffers and files named after point on this line.
Names may be \"quoted\"; an unreadable one is skipped with a message."
  (skip-syntax-forward " " (line-end-position))
  (while-let ((_ (not (eolp)))
              (name (if (eq (char-after) ?\")
                        (read (current-buffer))
                      (prog1 (thing-at-point 'filename t)
                        (skip-syntax-forward "^ " (line-end-position))))))
    (skip-syntax-forward " " (line-end-position))
    (cond ((get-buffer name) (push (get-buffer name) context))
          ((file-readable-p name) (push name context))
          (t (message "@include: no buffer or readable file %s" name))))
  context)

(defconst dl-gptel-source-cookie-regexp "@\\(?:include\\|gptel-annotate\\)\\_>"
  "Cookies whose arguments are buffer or file names.")

(defun dl-gptel-source-name-capf ()
  "Complete buffer and file names after a `dl-gptel-source-cookie-regexp' cookie.
The chosen name is inserted quoted."
  (let* ((end (point))
         (beg (save-excursion (skip-chars-backward "^[:space:]\"") (point))))
    (when (save-excursion
            (re-search-backward dl-gptel-source-cookie-regexp
                                (line-beginning-position) t))
      (list beg end
            (completion-table-merge #'internal-complete-buffer
                                    #'read-file-name-internal)
            :exclusive 'no
            :exit-function
            (lambda (name status)
              (when (memq status '(finished sole exact))
                (let ((beg (- (point) (length name))))
                  (delete-region (if (eq (char-before beg) ?\") (1- beg) beg)
                                 (if (eq (char-after) ?\") (1+ (point)) (point))))
                (insert (format "%S" (substring-no-properties name)))))))))

(defun dl-gptel-source-name-setup ()
  "Offer `dl-gptel-source-name-capf' in this buffer."
  (add-hook 'completion-at-point-functions #'dl-gptel-source-name-capf nil t))

;;;; @expand

(defun dl-gptel--expand (opener evaluate)
  "Replace each OPENER form in the newest prompt by EVALUATE's string.
OPENER is \"$:(\" or \"$:{\".  EVALUATE is called on the form's opening
delimiter; it moves point past the form and returns the replacement."
  (text-property-search-backward 'gptel 'response)
  (while (search-forward opener nil t)
    (let ((beg (- (point) (length opener))))
      (forward-char -1)
      (condition-case err
          (let ((result (funcall evaluate)))
            (delete-region beg (point))
            (insert result))
        (error (goto-char (+ beg (length opener)))
               (message "@expand: skipped %s at %d: %s"
                        opener beg (error-message-string err)))))))

(defun dl-gptel-expand-elisp ()
  "Replace $:(FORM) in the newest prompt by FORM's value."
  (dl-gptel--expand
   "$:(" (lambda ()
           (let* ((print-length nil)
                  (value (eval (read (current-buffer)) t)))
             (if (stringp value) value (prin1-to-string value))))))

(defun dl-gptel-expand-shell ()
  "Replace $:{COMMAND} in the newest prompt by COMMAND's output."
  (dl-gptel--expand
   "$:{" (lambda ()
           (let ((from (1+ (point))))
             (forward-sexp)
             (string-trim-right
              (shell-command-to-string
               (buffer-substring-no-properties from (1- (point)))))))))

;;;; @notify

(defun dl-gptel-notify-response (info)
  "Post a desktop notice with the start of the reply described by INFO."
  (pcase-let (((map :position :tracking-marker :buffer) info))
    (when (buffer-live-p (marker-buffer position))
      (require 'notifications)
      (notifications-notify
       :title (format "gptel: %s" (buffer-name buffer))
       :body (with-current-buffer (marker-buffer position)
               (if tracking-marker
                   (buffer-substring-no-properties
                    position (min tracking-marker (+ position 340)))
                 "(see the chat buffer)"))))))

(defun dl-gptel-notify-on-completion (fsm)
  "Arrange for `dl-gptel-notify-response' when FSM's request ends."
  (push #'dl-gptel-notify-response (plist-get (gptel-fsm-info fsm) :post)))

(provide 'dl-gptel-cookies)
;;; dl-gptel-cookies.el ends here
