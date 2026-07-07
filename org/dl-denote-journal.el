;;; dl-denote-journal.el --- denote-journal -*- lexical-binding: t; -*-

;; Roll-own journal helpers: denote 4.1.3 ships without the
;; `denote-journal' submodule (it was split off in 4.x).  These functions
;; produce filenames in the Denote convention so they sort and search
;; alongside everything else under `dl-notes-root'.
;;
;; File naming:
;;
;;   Personal daily:  journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org
;;   Personal weekly: weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org
;;   Work daily:      work/journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__work_journal.org
;;   Work weekly:     work/weekly/<monday-id>--YYYY-w<NN>__work_weekly_journal.org
;;
;; All variants share `my/journal--today-file', `my/journal--week-file',
;; `my/journal--day-skeleton', `my/journal--week-skeleton' parameterised
;; by directory, suffix, and filetags.  The 0-arg `*-ensure-today'
;; functions are stable entry points the capture templates can name.
;;
;; Link navigation (idempotent :NAV: drawer):
;;
;;   :NAV:
;;   prev-day | WkNN | *Realm* | Cross-realm | next-day
;;   :END:
;;
;; Weekly middle slot links to Monday's daily note instead of the week
;; (which would self-link).  All links are absolute `file:' paths since
;; both realms share the same YYYYMMDDT000000 identifier for the same date.

(require 'dl-notes-paths)
(declare-function org-with-wide-buffer "org-macs" (&rest body))

(defun my/journal--iso-monday (time)
  "Return TIME shifted back to the Monday of its ISO week."
  (let ((dow (string-to-number (format-time-string "%u" time))))
    (time-subtract time (days-to-time (1- dow)))))

(defun my/journal--today-file (dir suffix)
  "Return today's Denote-named journal file path under DIR with SUFFIX.
SUFFIX is the bit between `__' and `.org', e.g. \"journal\" or \"work_journal\"."
  (let* ((now  (current-time))
          (id   (format-time-string "%Y%m%dT000000" now))
          (slug (downcase (format-time-string "%Y-%m-%d-%A" now))))
    (expand-file-name
      (format "%s--%s__%s.org" id slug suffix)
      dir)))

(defun my/journal--week-file (dir suffix)
  "Return this week's Denote-named weekly file path under DIR with SUFFIX.
Identifier is anchored on the ISO-week Monday."
  (let* ((monday (my/journal--iso-monday (current-time)))
          (id     (format-time-string "%Y%m%dT000000" monday))
          (slug   (downcase (format-time-string "%Y-w%V" monday))))
    (expand-file-name
      (format "%s--%s__%s.org" id slug suffix)
      dir)))

;;; Link helpers — realm detection, filename parsing, cross-realm path

(defun my/journal--buffer-realm ()
  "Return (REALM TYPE) for the current buffer's journal file.
REALM is `personal' or `work'; TYPE is `daily' or `weekly'.
Returns nil if the buffer isn't visiting a known journal path."
  (when-let* ((file (buffer-file-name)))
    (cond ((string-prefix-p (expand-file-name dl-notes-journal-dir) file)
            '(personal daily))
      ((string-prefix-p (expand-file-name dl-notes-weekly-dir) file)
        '(personal weekly))
      ((string-prefix-p (expand-file-name dl-notes-work-journal-dir) file)
        '(work daily))
      ((string-prefix-p (expand-file-name dl-notes-work-weekly-dir) file)
        '(work weekly)))))

(defun my/journal--parse-basename (basename)
  "Parse BASENAME of a denote journal file.
Returns (ID SLUG SUFFIX) or nil.
E.g. \"20260521T000000--2026-05-21-thursday__journal.org\"
→ (\"20260521T000000\" \"2026-05-21-thursday\" \"journal\")"
  (when (string-match "\\`\\([0-9T]+\\)--\\(.+?\\)__\\(.+?\\)\\.org\\'" basename)
    (list (match-string 1 basename)
      (match-string 2 basename)
      (match-string 3 basename))))

(defun my/journal--slug-date (slug)
  "Parse SLUG as YYYY-MM-DD-Weekday, return the date as time value or nil."
  (when (string-match "\\`\\([0-9]\\{4\\}-[0-9]\\{2\\}-[0-9]\\{2\\}\\)" slug)
    (date-to-time (match-string 1 slug))))

(defun my/journal--slug-iso-week (slug)
  "Parse SLUG as YYYY-wNN, return (YEAR WEEK) or nil."
  (when (string-match "\\`\\([0-9]\\{4\\}\\)-w\\([0-9]\\{2\\}\\)\\'" slug)
    (list (string-to-number (match-string 1 slug))
      (string-to-number (match-string 2 slug)))))

(defun my/journal--iso-week-monday (year week)
  "Return the Monday of ISO week WEEK in YEAR as a time value.
Uses the January-4th rule: ISO week 1 contains Jan 4.
Anchored at noon so DST transitions cannot shift the result across a
day boundary when callers later add fixed-length day deltas."
  (let* ((jan-4 (encode-time 0 0 12 4 1 year))
          (dow   (string-to-number (format-time-string "%u" jan-4)))
          (monday (time-subtract jan-4 (days-to-time (1- dow)))))
    (time-add monday (days-to-time (* 7 (1- week))))))

(defun my/journal--other-file ()
  "Return the cross-realm counterpart path for the current journal buffer.
E.g. from a personal daily, return the work daily for the same date.
Returns nil if the buffer isn't visiting a known journal file."
  (when-let* ((file (buffer-file-name))
               (realm-type (my/journal--buffer-realm))
               (realm (car realm-type))
               (type (cadr realm-type))
               (basename (file-name-nondirectory file))
               (parsed (my/journal--parse-basename basename))
               (id (nth 0 parsed))
               (slug (nth 1 parsed)))
    (pcase (cons realm type)
      ('(personal . daily)
        (expand-file-name (format "%s--%s__work_journal.org" id slug)
          dl-notes-work-journal-dir))
      ('(work . daily)
        (expand-file-name (format "%s--%s__journal.org" id slug)
          dl-notes-journal-dir))
      ('(personal . weekly)
        (expand-file-name (format "%s--%s__work_weekly_journal.org" id slug)
          dl-notes-work-weekly-dir))
      ('(work . weekly)
        (expand-file-name (format "%s--%s__weekly_journal.org" id slug)
          dl-notes-weekly-dir)))))

(defun my/journal--construct-path (dir suffix time &optional weekly)
  "Construct a denote journal path for TIME under DIR with SUFFIX.
If WEEKLY is non-nil, build a weekly path; otherwise a daily path.
DIR is the target directory (e.g. `dl-notes-journal-dir'),
SUFFIX is the denote file suffix (e.g. \"journal\" or \"work_journal\")."
  (if weekly
    (let* ((monday (my/journal--iso-monday time))
            (id   (format-time-string "%Y%m%dT000000" monday))
            (slug (downcase (format-time-string "%Y-w%V" monday))))
      (expand-file-name (format "%s--%s__%s.org" id slug suffix) dir))
    (let* ((id   (format-time-string "%Y%m%dT000000" time))
            (slug (downcase (format-time-string "%Y-%m-%d-%A" time))))
      (expand-file-name (format "%s--%s__%s.org" id slug suffix) dir))))

;;; Link insertion — idempotent :NAV: drawer (single-line pipe-separated)

(defun my/journal--links-string-for-file (file)
  "Return the :NAV: drawer string for FILE, visiting it in a temp buffer.
FILE must be a denote journal file path.  Returns nil if the file isn't
a known journal path or if parsing fails."
  (with-temp-buffer
    (setq buffer-file-name file)
    (my/journal--links-string)))

(defun my/journal--links-string ()
  "Return the :NAV: drawer string for the current buffer.
Pipe-separated navigation bar in an org drawer:

For dailies:  prev-day | week | *Realm* | other-realm | next-day
For weeklies: prev-week | *Realm* | other-realm | next-week
              [Mon 18] [Tue 19] [Wed 20] [Thu 21] [Fri 22] [Sat 23] [Sun 24]

All links use `file:' with absolute paths to avoid identifier
collisions between personal and work realms.
Returns nil when the buffer isn't a journal file."
  (when-let* ((realm-type (my/journal--buffer-realm))
               (realm (car realm-type))
               (type (cadr realm-type))
               (file (buffer-file-name))
               (basename (file-name-nondirectory file))
               (parsed (my/journal--parse-basename basename))
               (slug (nth 1 parsed)))
    (let (prev next mid cross-link day-links)
      ;; --- prev/next/mid depending on type ---
      (pcase type
        ('daily
          (when-let* ((date (my/journal--slug-date slug)))
            (let* ((dir (if (eq realm 'personal)
                          dl-notes-journal-dir
                          dl-notes-work-journal-dir))
                    (suffix (if (eq realm 'personal) "journal" "work_journal"))
                    (prev-time (time-subtract date (days-to-time 1)))
                    (next-time (time-add date (days-to-time 1)))
                    (prev-path (my/journal--construct-path dir suffix prev-time))
                    (next-path (my/journal--construct-path dir suffix next-time)))
              (setq prev (format "[[file:%s][← %s]]" prev-path
                           (downcase (format-time-string "%Y-%m-%d %a" prev-time)))
                next (format "[[file:%s][%s →]]" next-path
                       (downcase (format-time-string "%Y-%m-%d %a" next-time)))))
            ;; mid: week link — same-realm
            (let* ((wk-dir (if (eq realm 'personal)
                             dl-notes-weekly-dir
                             dl-notes-work-weekly-dir))
                    (wk-suffix (if (eq realm 'personal)
                                 "weekly_journal"
                                 "work_weekly_journal"))
                    (monday (my/journal--iso-monday date))
                    (wk-path (my/journal--construct-path wk-dir wk-suffix monday t)))
              (setq mid (format "[[file:%s][Wk%s]]" wk-path
                          (format-time-string "%V" monday))))))
        ('weekly
          (when-let* ((yw (my/journal--slug-iso-week slug))
                       (year (car yw))
                       (week (cadr yw))
                       (monday (my/journal--iso-week-monday year week)))
            (let* ((dir (if (eq realm 'personal)
                          dl-notes-weekly-dir
                          dl-notes-work-weekly-dir))
                    (suffix (if (eq realm 'personal)
                              "weekly_journal"
                              "work_weekly_journal"))
                    (daily-dir (if (eq realm 'personal)
                                 dl-notes-journal-dir
                                 dl-notes-work-journal-dir))
                    (daily-suffix (if (eq realm 'personal)
                                    "journal"
                                    "work_journal"))
                    (prev-monday (time-subtract monday (days-to-time 7)))
                    (next-monday (time-add monday (days-to-time 7)))
                    (prev-path (my/journal--construct-path dir suffix prev-monday t))
                    (next-path (my/journal--construct-path dir suffix next-monday t)))
              (setq prev (format "[[file:%s][← Wk%s]]" prev-path
                           (format-time-string "%V" prev-monday))
                next (format "[[file:%s][Wk%s →]]" next-path
                       (format-time-string "%V" next-monday))
                day-links
                (mapconcat
                  (lambda (offset)
                    (let* ((day (time-add monday (days-to-time offset)))
                            (day-path (my/journal--construct-path daily-dir daily-suffix day)))
                      (format "[[file:%s][%s %s]]" day-path
                        (format-time-string "%a" day)
                        (format-time-string "%d" day))))
                  (number-sequence 0 6) " | "))))))
      ;; --- cross-realm link ---
      (when-let* ((other (my/journal--other-file)))
        (setq cross-link (format "[[file:%s][%s]]" other
                           (if (eq realm 'personal) "Work" "Personal"))))
      ;; --- assemble: pipe-delimited, wrapped in :NAV: drawer ---
      (let* ((realm-label (format "*%s*" (capitalize (symbol-name realm))))
              (parts (delq nil
                       (pcase type
                         ('daily (list prev mid realm-label cross-link next))
                         ('weekly (list prev realm-label cross-link next))))))
        (when parts
          (concat ":NAV:\n"
            (string-join parts " | ")
            (if day-links (concat "\n" day-links) "")
            "\n:END:\n"))))))

(defun my/journal--insert-links ()
  "Insert or update a :NAV: drawer in the current journal buffer.
Idempotent — finds or creates :NAV:/:END: and replaces its content.
Does nothing if the buffer isn't a journal file."
  (interactive)
  (if-let* ((links (my/journal--links-string)))
    (org-with-wide-buffer
      (goto-char (point-min))
      (if (re-search-forward "^:NAV:" nil t)
        ;; Replace entire drawer from :NAV: through :END:
        (let ((beg (match-beginning 0))
               (end (progn (forward-line 1)
                      (if (re-search-forward "^:END:" nil t)
                        (progn (forward-line 1) (point))
                        (point-max)))))
          (delete-region beg end)
          (insert links))
        ;; Insert before the first top-level heading (or at buffer end)
        (goto-char (point-min))
        (if (re-search-forward "^\\* " nil t)
          (forward-line -1)
          (goto-char (point-max)))
        (unless (bolp) (insert "\n"))
        (insert "\n" links)))
    (when (called-interactively-p 'any)
      (message "Not a journal buffer — skipping links"))))

;;; Skeletons

(defun my/journal--day-skeleton (tags &optional time)
  "Return the skeleton string for a newly-created daily journal file.
TAGS is the `#+filetags:' line value (e.g. \":journal:\").
When TIME is non-nil, use it as the reference date;
otherwise use `current-time'."
  (let ((t0 (or time (current-time))))
    (concat "#+title:    " (format-time-string "%Y-%m-%d %A" t0) "\n"
      "#+filetags: " tags "\n"
      "#+date:     " (format-time-string "[%Y-%m-%d %a]" t0) "\n\n"
      "* Focus\n\n* Notes\n\n* Log\n")))

(defun my/journal--week-skeleton (tags &optional time)
  "Return the skeleton string for a newly-created weekly journal file.
TAGS is the `#+filetags:' line value (e.g. \":weekly:journal:\").
When TIME is non-nil, shift it to the ISO Monday and use as reference;
otherwise use `current-time'."
  (let ((monday (my/journal--iso-monday (or time (current-time)))))
    (concat "#+title:    " (format-time-string "Week %G-W%V" monday) "\n"
      "#+filetags: " tags "\n"
      "#+date:     " (format-time-string "[%Y-%m-%d %a]" monday) "\n\n"
      "* Review\n\n* Projects\n\n* Notes promoted\n\n* Next week\n")))

(defun my/journal--ensure-file (file skeleton)
  "Ensure FILE exists with SKELETON contents; return its path.
Also inserts a :NAV: drawer with navigation links on creation."
  (unless (file-exists-p file)
    (with-temp-buffer
      (insert skeleton)
      ;; Insert :NAV: drawer before the first * heading (or at end)
      (let* ((name (file-name-nondirectory file))
              (parsed (my/journal--parse-basename name))
              (links (when parsed
                       (my/journal--links-string-for-file file))))
        (when links
          (goto-char (point-min))
          (if (re-search-forward "^\\* " nil t)
            (progn
              (forward-line -1)
              (insert "\n" links))
            (goto-char (point-max))
            (insert "\n" links))))
      (write-region (point-min) (point-max) file)))
  file)

(defun my/journal--open (file skeleton)
  "Open FILE; if empty, insert SKELETON.
Then update the :NAV: drawer (creates it if missing)."
  (find-file file)
  (when (= (point-max) 1)
    (insert skeleton))
  (my/journal--insert-links))

;; Personal entry points.

(defun my/journal--ensure-today ()
  "Ensure today's personal journal exists; return its path.
Stable 0-arg entry point for the `j' capture template."
  (my/journal--ensure-file
    (my/journal--today-file dl-notes-journal-dir "journal")
    (my/journal--day-skeleton ":journal:")))

(defun my/journal-note ()
  "Open or create today's Denote-named personal daily journal note."
  (interactive)
  (my/journal--open
    (my/journal--today-file dl-notes-journal-dir "journal")
    (my/journal--day-skeleton ":journal:")))

(defun my/weekly-note ()
  "Open or create this week's Denote-named personal weekly journal note."
  (interactive)
  (my/journal--open
    (my/journal--week-file dl-notes-weekly-dir "weekly_journal")
    (my/journal--week-skeleton ":weekly:journal:")))

;; Work entry points.

(defun my/work-journal--ensure-today ()
  "Ensure today's work journal exists; return its path.
Stable 0-arg entry point for the `w j' capture template."
  (my/journal--ensure-file
    (my/journal--today-file dl-notes-work-journal-dir "work_journal")
    (my/journal--day-skeleton ":work:journal:")))

(defun my/work-journal-note ()
  "Open or create today's Denote-named work daily journal note."
  (interactive)
  (my/journal--open
    (my/journal--today-file dl-notes-work-journal-dir "work_journal")
    (my/journal--day-skeleton ":work:journal:")))

(defun my/work-weekly-note ()
  "Open or create this week's Denote-named work weekly journal note."
  (interactive)
  (my/journal--open
    (my/journal--week-file dl-notes-work-weekly-dir "work_weekly_journal")
    (my/journal--week-skeleton ":work:weekly:journal:")))

;; Quick capture — pop a small org buffer, C-c C-c / C-RET appends the
;; text as a timestamped subentry under the daily journal's `* Log'.
;; Reuses the journal-ensure machinery above so the target file is
;; created on demand with the standard skeleton.

(require 'cl-lib)
(require 'org)
(use-package posframe :defer t)
(declare-function posframe-show          "posframe")
(declare-function posframe-hide          "posframe")
(declare-function posframe-delete-frame  "posframe")
(declare-function posframe-workable-p    "posframe")
(declare-function posframe-poshandler-frame-center "posframe")
(declare-function olivetti-mode                    "olivetti")

(defvar dl-journal-quick-capture--buffer-name "*journal quick capture*")

(defvar dl-journal-quick-capture-targets
  '((personal . my/journal--ensure-today)
     (work     . my/work-journal--ensure-today))
  "Alist of LABEL → zero-arg function returning the journal file path.
The toggle command cycles through these in order.")

(defvar-local dl-journal-quick-capture--target-label nil
  "Current target label (a key in `dl-journal-quick-capture-targets').")
(defvar-local dl-journal-quick-capture--target-fn nil
  "Zero-arg function returning the journal file path to append to.")
(defvar-local dl-journal-quick-capture--olp '("Log")
  "Outline path inside the journal file under which the entry lands.")
(defvar-local dl-journal-quick-capture--prev-frame nil
  "Frame to restore focus to after the quick-capture posframe dismisses.")
(defvar-local dl-journal-quick-capture--via-posframe nil
  "Non-nil when this buffer is displayed in a posframe rather than a window.")

(defvar-keymap dl-journal-quick-capture-mode-map
  :doc "Bindings active inside a `dl-journal-quick-capture-mode' buffer."
  "C-c C-c"    #'dl-journal-quick-capture-finalize
  "C-<return>" #'dl-journal-quick-capture-finalize
  "C-c C-w"    #'dl-journal-quick-capture-toggle-target
  "C-c C-k"    #'dl-journal-quick-capture-abort)

(define-derived-mode dl-journal-quick-capture-mode org-mode "QuickCap"
  "Org-mode buffer for a fast timestamped journal append."
  ;; org-mode-hook activates olivetti, which fiddles window margins and
  ;; blows up on the narrow posframe / side-window this buffer lives in.
  ;; Same for any other mode that needs a real frame geometry.
  (when (bound-and-true-p olivetti-mode) (olivetti-mode -1)))

(defun dl-journal-quick-capture--refresh-header ()
  "Refresh `header-line-format' to reflect the current target label."
  (setq header-line-format
    (substitute-command-keys
      (format "Quick capture [%s] — \\[dl-journal-quick-capture-finalize] save · \\[dl-journal-quick-capture-toggle-target] work/personal · \\[dl-journal-quick-capture-abort] abort"
        (or dl-journal-quick-capture--target-label "personal")))))

(defun dl-journal-quick-capture--apply-target (label)
  "Set this buffer's quick-capture target to LABEL.
LABEL must be a key in `dl-journal-quick-capture-targets'."
  (let ((fn (cdr (assq label dl-journal-quick-capture-targets))))
    (unless (functionp fn)
      (user-error "Unknown quick-capture target: %s" label))
    (setq dl-journal-quick-capture--target-label label
      dl-journal-quick-capture--target-fn fn)
    (dl-journal-quick-capture--refresh-header)))

(defun dl-journal-quick-capture-toggle-target ()
  "Cycle this buffer's capture target through `dl-journal-quick-capture-targets'.
Preserves any text already typed."
  (interactive)
  (let* ((labels (mapcar #'car dl-journal-quick-capture-targets))
          (idx    (or (cl-position dl-journal-quick-capture--target-label labels)
                    0))
          (next   (nth (mod (1+ idx) (length labels)) labels)))
    (dl-journal-quick-capture--apply-target next)
    (message "Quick capture target → %s" next)))

(defun dl-journal-quick-capture--ensure-heading (top)
  "Move point to the start of the top-level `* TOP' heading, creating it if absent.
Search is anchored at point-min and assumes a wide buffer."
  (goto-char (point-min))
  (let ((re (format "^\\* %s[ \t]*\\(?::[^\n]*:\\)?[ \t]*$" (regexp-quote top))))
    (unless (re-search-forward re nil t)
      (goto-char (point-max))
      (unless (bolp) (insert "\n"))
      (unless (or (bobp) (looking-back "\n\n" 2)) (insert "\n"))
      (insert "* " top "\n"))
    (org-back-to-heading t)))

(defun dl-journal-quick-capture--insert (file olp text)
  "Append TEXT as a timestamped sub-heading under OLP in FILE."
  (with-current-buffer (find-file-noselect file)
    (org-with-wide-buffer
      (dl-journal-quick-capture--ensure-heading (car olp))
      (let* ((sub-level (1+ (org-current-level)))
              (stars     (make-string sub-level ?*))
              (stamp     (format-time-string "%Y-%m-%d %H:%M")))
        (org-end-of-subtree t t)
        (unless (bolp) (insert "\n"))
        (insert (format "%s [%s]\n%s\n\n" stars stamp (string-trim-right text)))))
    (save-buffer)))

(defun dl-journal-quick-capture--dismiss (buf)
  "Close BUF's posframe or window and kill BUF, restoring prior focus."
  (let ((prev       (buffer-local-value 'dl-journal-quick-capture--prev-frame buf))
         (posframe-p (buffer-local-value 'dl-journal-quick-capture--via-posframe buf)))
    (if posframe-p
      (when (featurep 'posframe)
        (posframe-hide buf)
        (posframe-delete-frame buf))
      (let ((win (get-buffer-window buf)))
        (when (and (window-live-p win) (not (one-window-p win)))
          (quit-window nil win))))
    (when (frame-live-p prev)
      (select-frame-set-input-focus prev))
    (when (buffer-live-p buf) (kill-buffer buf))))

(defun dl-journal-quick-capture-finalize ()
  "Append the current buffer as a timestamped Log entry and dismiss."
  (interactive)
  (let* ((text (string-trim (buffer-substring-no-properties (point-min) (point-max))))
          (target-fn dl-journal-quick-capture--target-fn)
          (olp  dl-journal-quick-capture--olp)
          (buf  (current-buffer)))
    (when (string-empty-p text)
      (user-error "Quick capture is empty"))
    (unless (functionp target-fn)
      (error "dl-journal-quick-capture: no target-fn set"))
    (let ((file (funcall target-fn)))
      (dl-journal-quick-capture--insert file olp text)
      (dl-journal-quick-capture--dismiss buf)
      (message "Captured → %s" (abbreviate-file-name file)))))

(defun dl-journal-quick-capture-abort ()
  "Discard the current quick capture without writing anything."
  (interactive)
  (dl-journal-quick-capture--dismiss (current-buffer))
  (message "Quick capture aborted"))

(defun dl-journal-quick-capture--show-popup (buf)
  "Fallback display: BUF in a side window below the selected one."
  (pop-to-buffer buf
    '((display-buffer-below-selected)
       (window-height . 10)
       (dedicated . t)))
  (select-window (get-buffer-window buf)))

(defun dl-journal-quick-capture--show-posframe (buf)
  "Display BUF as a centered, focused child frame via posframe."
  (with-current-buffer buf
    (setq dl-journal-quick-capture--via-posframe t))
  (let* ((parent-width  (frame-pixel-width))
          (parent-height (frame-pixel-height))
          (cw (frame-char-width))
          (ch (frame-char-height))
          (width  (max 40 (min 100 (/ (* parent-width 2) (* 3 cw)))))
          (height (max 6  (min 20  (/ parent-height (* 3 ch))))))
    (let ((frame (posframe-show buf
                   :poshandler #'posframe-poshandler-frame-center
                   :width width
                   :height height
                   :min-width 40
                   :min-height 4
                   :internal-border-width 8
                   :accept-focus t
                   :respect-header-line t)))
      (when (frame-live-p frame)
        (select-frame-set-input-focus frame)))))

(defun my/journal-quick-capture (&optional label)
  "Pop a buffer for a timestamped entry under the daily journal's `* Log'.
\\<dl-journal-quick-capture-mode-map>\\[dl-journal-quick-capture-finalize] \
(or C-RET) appends and closes; \\[dl-journal-quick-capture-toggle-target] \
toggles personal/work; \\[dl-journal-quick-capture-abort] aborts.

Displays as a posframe child-frame on graphical frames when posframe is
available; falls back to a below-selected side window otherwise.

LABEL is a key in `dl-journal-quick-capture-targets'; defaults to `personal'."
  (interactive)
  (let ((buf (get-buffer-create dl-journal-quick-capture--buffer-name))
         (prev-frame (selected-frame)))
    (with-current-buffer buf
      (erase-buffer)
      (dl-journal-quick-capture-mode)
      (setq dl-journal-quick-capture--prev-frame prev-frame
        dl-journal-quick-capture--via-posframe nil)
      (dl-journal-quick-capture--apply-target (or label 'personal)))
    (if (and (display-graphic-p)
          (require 'posframe nil t)
          (posframe-workable-p))
      (dl-journal-quick-capture--show-posframe buf)
      (dl-journal-quick-capture--show-popup buf))))

(defun my/work-journal-quick-capture ()
  "Quick-capture into today's work daily journal."
  (interactive)
  (my/journal-quick-capture 'work))

;;; find-file-hook — auto-populate non-existent journal files

(defun my/journal--populate-if-empty ()
  "When visiting a non-existent journal file, insert skeleton and :NAV: drawer.
Works for all six journal types (personal/work × daily/weekly).
Harmless for existing files, non-journal paths, and already-populated buffers.
Intended for use in `find-file-hook'."
  (when (and (buffer-file-name)
          (not (file-exists-p (buffer-file-name)))
          (not (save-excursion
                 (goto-char (point-min))
                 (re-search-forward ":NAV:" nil t))))
    (when-let* ((realm-type (my/journal--buffer-realm))
                 (realm (car realm-type))
                 (type (cadr realm-type))
                 (basename (file-name-nondirectory (buffer-file-name)))
                 (parsed (my/journal--parse-basename basename))
                 (slug (nth 1 parsed)))
      (let* ((tags (pcase (cons realm type)
                     ('(personal . daily)  ":journal:")
                     ('(work . daily)      ":work:journal:")
                     ('(personal . weekly) ":weekly:journal:")
                     ('(work . weekly)     ":work:weekly:journal:")))
              (time (pcase type
                      ('daily  (my/journal--slug-date slug))
                      ('weekly (when-let* ((yw (my/journal--slug-iso-week slug))
                                            (year (car yw))
                                            (week (cadr yw)))
                                 (my/journal--iso-week-monday year week)))))
              (skeleton (if (eq type 'daily)
                          (my/journal--day-skeleton tags time)
                          (my/journal--week-skeleton tags time))))
        (insert skeleton)
        (when-let* ((links (my/journal--links-string)))
          (goto-char (point-min))
          (if (re-search-forward "^\\* " nil t)
            (progn
              (forward-line -1)
              (insert "\n" links))
            (goto-char (point-max))
            (insert "\n" links)))))))

(add-hook 'find-file-hook #'my/journal--populate-if-empty)

;; Bindings (`C-c n j', `C-c n w', `C-c n W j', `C-c n W w', etc.) live
;; in `core/dl-keymap.el' under `my-notes-map' and `my-notes-work-map'.
;; The global `<f1>' shortcut for `my/journal-quick-capture' lives in
;; `core/dl-keybind.el' (which also relocates `help-command' to C-<f1>).

(provide 'dl-denote-journal)
;;; dl-denote-journal.el ends here
