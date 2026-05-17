;;; dl-review.el --- Notes review surfaces -*- lexical-binding: t; -*-

;; Triage commands for the notes corpus.  Two flavours:
;;
;;   1. Navigational  (`my/review-inbox', `my/review-intake',
;;      `my/review-weekly') — open the right buffer for a review pass.
;;
;;   2. Reporting     (`my/review-stale',
;;      `my/review-references-retained',
;;      `my/review-references-untrusted') — surface items that match a
;;      review predicate via `org-ql' (for Org) or `consult-ripgrep'
;;      (for mixed Org / Markdown / PDF metadata in `references/').
;;
;; Bound under `C-c n v …' in `core/dl-keymap.el'.

(require 'dl-notes-paths)
(require 'org-ql)

(defvar my/review-stale-days 7
  "Days a WAITING item must be untouched before it counts as stale.
Used by `my/review-stale'.")

(defun my/review--notes-files ()
  "Return the Org files / dirs that the review queries scan."
  (list dl-notes-inbox-file
         dl-notes-projects-dir
         dl-notes-areas-dir
         dl-notes-sources-dir
         dl-notes-slips-dir
         dl-notes-journal-dir
         dl-notes-weekly-dir))

(defun my/review-inbox ()
  "Open `inbox.org' and jump to the first TODO heading."
  (interactive)
  (find-file dl-notes-inbox-file)
  (goto-char (point-min))
  (unless (re-search-forward "^\\*+ TODO\\b" nil t)
    (goto-char (point-min))))

(defun my/review-intake ()
  "Open Dired on the intake directory, newest first."
  (interactive)
  (let ((dired-listing-switches "-laht"))
    (dired dl-notes-intake-dir)))

(defun my/review-weekly ()
  "Open this week's weekly note alongside an `org-ql' WAITING report."
  (interactive)
  (my/weekly-note)
  (split-window-right)
  (other-window 1)
  (org-ql-search (my/review--notes-files)
                 '(todo "WAITING")
                 :title "Open WAITING items"))

(defun my/review-stale ()
  "Show WAITING items with no timestamp in the last `my/review-stale-days'.
Approximation: an item is stale if no timestamp (active or inactive)
in its subtree falls within the window."
  (interactive)
  (let ((cutoff (format-time-string "%Y-%m-%d"
                  (time-subtract nil (days-to-time my/review-stale-days)))))
    (org-ql-search (my/review--notes-files)
                   `(and (todo "WAITING")
                         (not (ts :from ,cutoff)))
                   :title (format "Stale WAITING (>%d days)" my/review-stale-days))))

(defun my/review-references-retained ()
  "Find references retained but not yet triaged (`status: raw').
Ripgrep — works across .org / .md / .html references."
  (interactive)
  (consult-ripgrep dl-notes-references-dir "status:\\s+raw"))

(defun my/review-references-untrusted ()
  "Find references explicitly marked untrusted or unreviewed for trust."
  (interactive)
  (consult-ripgrep dl-notes-references-dir "(:untrusted:|trust:\\s+unreviewed)"))

(provide 'dl-review)
;;; dl-review.el ends here
