;;; dl-zmx-org.el --- Org links to zmx sessions -*- lexical-binding: t; -*-

;; `[[zmx:hris.2]]' shows session `hris.2': its terminal, or a new one
;; reattached to it.  `org-store-link' in a zmx terminal stores one, and
;; `C-c C-l zmx: RET' picks a running session.
;;
;; A link to a session that is no longer running is refused, as `zmx attach'
;; would create an empty session under its name; `C-u C-c C-o' starts one, at
;; the Org file's directory.  Stock `ghostel-org' links
;; cannot reach zmx terminals: see IDE-004, Rejected.

(require 'seq)
(require 'ol)
(require 'dl-zmx)

(defun dl-zmx-org-follow (name arg)
  "Show running zmx session NAME: its terminal, or a new one reattached to it.
With ARG (`C-u C-c C-o'), start NAME at `default-directory' if not running."
  (if-let* ((session (seq-find (lambda (session)
                                 (equal (alist-get 'name session) name))
                               (dl-zmx-sessions))))
      (dl-zmx--reattach session)
    (unless arg
      (user-error "No running zmx session %s (C-u to start it)" name))
    (dl-zmx--check-reachable name)
    (dl-zmx--open name (dl-zmx-attach-argv name))))

(defun dl-zmx-org-store-link (&optional _interactive)
  "Store a link to the zmx session of the current terminal, if it is one."
  (when-let* ((name (dl-zmx-buffer-session (current-buffer))))
    (org-link-store-props :type "zmx" :link (concat "zmx:" name)
                          :description name)))

(defun dl-zmx-org-complete (&optional _arg)
  "Return a `zmx:' link to a running session, read with annotations."
  (concat "zmx:" (alist-get 'name (dl-zmx--read-session "zmx session: "))))

(org-link-set-parameters "zmx"
                         :follow #'dl-zmx-org-follow
                         :store #'dl-zmx-org-store-link
                         :complete #'dl-zmx-org-complete)

(provide 'dl-zmx-org)
;;; dl-zmx-org.el ends here
