;;; dl-zmx-org.el --- Org links to zmx sessions -*- lexical-binding: t; -*-

;; `[[zmx:hris.2]]' shows session `hris.2': its terminal, or a new one
;; reattached to it.  `org-store-link' in a zmx terminal stores one, and
;; `C-c C-l zmx: RET' picks a running session.
;;
;; A link to a session that is no longer running is refused, as `zmx attach'
;; would create an empty session under its name.  Stock `ghostel-org' links
;; cannot reach zmx terminals: see IDE-004, Rejected.

(require 'seq)
(require 'ol)
(require 'dl-zmx)

(defun dl-zmx-org-follow (name _arg)
  "Show running zmx session NAME: its terminal, or a new one reattached to it."
  (dl-zmx--reattach
   (or (seq-find (lambda (session) (equal (alist-get 'name session) name))
                 (dl-zmx-sessions))
       (user-error "No running zmx session %s" name))))

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
