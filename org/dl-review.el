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
;; Each command has a work counterpart (`my/review-work-*') that runs
;; the same shape against the work compartment.
;;
;; Bound under `C-c n v …' (personal) and `C-c n W v …' (work) in
;; `core/dl-keymap.el'.

(require 'dl-notes-paths)
(require 'org-ql)

(defvar my/review-stale-days 7
  "Days a WAITING item must be untouched before it counts as stale.
Used by `my/review-stale' and `my/review-work-stale'.")

(defun my/review--notes-files ()
  "Return the personal Org files / dirs that the review queries scan."
  (list dl-notes-inbox-file
         dl-notes-projects-dir
         dl-notes-areas-dir
         dl-notes-sources-dir
         dl-notes-slips-dir
         dl-notes-journal-dir
         dl-notes-weekly-dir))

(defun my/review--work-notes-files ()
  "Return the work Org files / dirs that the review queries scan."
  (list dl-notes-work-inbox-file
         dl-notes-work-projects-dir
         dl-notes-work-areas-dir
         dl-notes-work-sources-dir
         dl-notes-work-slips-dir
         dl-notes-work-journal-dir
         dl-notes-work-weekly-dir
         dl-notes-work-meetings-dir
         dl-notes-work-people-dir))

(defun my/review--stale-cutoff ()
  "Date string `my/review-stale-days' ago, for `ts :from'."
  (format-time-string "%Y-%m-%d"
                      (time-subtract nil (days-to-time my/review-stale-days))))

(defun my/review--open-inbox (file)
  "Open inbox FILE and jump to the first TODO heading."
  (find-file file)
  (goto-char (point-min))
  (unless (re-search-forward "^\\*+ TODO\\b" nil t)
    (goto-char (point-min))))

(defun my/review--dired-newest (dir)
  "Open Dired on DIR sorted by mtime descending."
  (let ((dired-listing-switches "-laht"))
    (dired dir)))

(defun my/review--weekly-with-waiting (weekly-fn files title)
  "Open the weekly note via WEEKLY-FN, side-by-side with WAITING in FILES.
TITLE labels the org-ql buffer."
  (funcall weekly-fn)
  (split-window-right)
  (other-window 1)
  (org-ql-search files '(todo "WAITING") :title title))

;; Personal review surfaces.

(defun my/review-inbox ()
  "Open `inbox.org' and jump to the first TODO heading."
  (interactive)
  (my/review--open-inbox dl-notes-inbox-file))

(defun my/review-intake ()
  "Open Dired on the intake directory, newest first."
  (interactive)
  (my/review--dired-newest dl-notes-intake-dir))

(defun my/review-weekly ()
  "Open this week's weekly note alongside an `org-ql' WAITING report."
  (interactive)
  (my/review--weekly-with-waiting
   #'my/weekly-note (my/review--notes-files) "Open WAITING items"))

(defun my/review-stale ()
  "Show WAITING items with no timestamp in the last `my/review-stale-days'.
Approximation: an item is stale if no timestamp (active or inactive)
in its subtree falls within the window."
  (interactive)
  (org-ql-search (my/review--notes-files)
                 `(and (todo "WAITING")
                       (not (ts :from ,(my/review--stale-cutoff))))
                 :title (format "Stale WAITING (>%d days)" my/review-stale-days)))

(defun my/review-references-retained ()
  "Find references retained but not yet triaged (`status: raw').
Ripgrep — works across .org / .md / .html references."
  (interactive)
  (consult-ripgrep dl-notes-references-dir "status:\\s+raw"))

(defun my/review-references-untrusted ()
  "Find references explicitly marked untrusted or unreviewed for trust."
  (interactive)
  (consult-ripgrep dl-notes-references-dir "(:untrusted:|trust:\\s+unreviewed)"))

;; Work review surfaces — 1:1 with the personal commands above.

(defun my/review-work-inbox ()
  "Open `work/inbox.org' and jump to the first TODO heading."
  (interactive)
  (my/review--open-inbox dl-notes-work-inbox-file))

(defun my/review-work-intake ()
  "Open Dired on the work intake directory, newest first."
  (interactive)
  (my/review--dired-newest dl-notes-work-intake-dir))

(defun my/review-work-weekly ()
  "Open this week's work weekly note alongside an `org-ql' WAITING report."
  (interactive)
  (my/review--weekly-with-waiting
   #'my/work-weekly-note (my/review--work-notes-files) "Open work WAITING items"))

(defun my/review-work-stale ()
  "Work-scope variant of `my/review-stale'."
  (interactive)
  (org-ql-search (my/review--work-notes-files)
                 `(and (todo "WAITING")
                       (not (ts :from ,(my/review--stale-cutoff))))
                 :title (format "Stale work WAITING (>%d days)" my/review-stale-days)))

(defun my/review-work-references-retained ()
  "Find work references retained but not yet triaged (`status: raw')."
  (interactive)
  (consult-ripgrep dl-notes-work-references-dir "status:\\s+raw"))

(defun my/review-work-references-untrusted ()
  "Find work references explicitly marked untrusted or unreviewed for trust."
  (interactive)
  (consult-ripgrep dl-notes-work-references-dir "(:untrusted:|trust:\\s+unreviewed)"))

;; Work-scoped org-ql entry point bound to `C-c n W q'.

(defun my/work-org-ql-find ()
  "Run `org-ql-find' over the work agenda file set."
  (interactive)
  (let ((org-agenda-files my/org-agenda-work-files))
    (call-interactively #'org-ql-find)))

(provide 'dl-review)
;;; dl-review.el ends here
