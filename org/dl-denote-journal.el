;;; dl-denote-journal.el --- Daily / weekly journal notes (Denote-named) -*- lexical-binding: t; -*-

;; Roll-own journal helpers: denote 4.1.3 ships without the
;; `denote-journal' submodule (it was split off in 4.x).  These functions
;; produce filenames in the Denote convention so they sort and search
;; alongside everything else under `dl-notes-root'.
;;
;; Personal:
;;   Daily:  journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__journal.org
;;   Weekly: weekly/<monday-id>--YYYY-w<NN>__weekly_journal.org
;;
;; Work:
;;   Daily:  work/journal/YYYYMMDDT000000--YYYY-MM-DD-<weekday>__work_journal.org
;;   Weekly: work/weekly/<monday-id>--YYYY-w<NN>__work_weekly_journal.org
;;
;; All variants share `my/journal--today-file', `my/journal--week-file',
;; `my/journal--day-skeleton', `my/journal--week-skeleton' parameterised
;; by directory, suffix, and filetags.  The 0-arg `*-ensure-today'
;; functions are stable entry points the capture templates can name.

(require 'dl-notes-paths)

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

(defun my/journal--day-skeleton (tags)
  "Return the skeleton string for a newly-created daily journal file.
TAGS is the `#+filetags:' line value (e.g. \":journal:\")."
  (let ((now (current-time)))
    (concat "#+title:    " (format-time-string "%Y-%m-%d %A" now) "\n"
            "#+filetags: " tags "\n"
            "#+date:     " (format-time-string "[%Y-%m-%d %a]" now) "\n\n"
            "* Focus\n\n* Notes\n\n* Log\n")))

(defun my/journal--week-skeleton (tags)
  "Return the skeleton string for a newly-created weekly journal file.
TAGS is the `#+filetags:' line value (e.g. \":weekly:journal:\")."
  (let ((monday (my/journal--iso-monday (current-time))))
    (concat "#+title:    " (format-time-string "Week %G-W%V" monday) "\n"
            "#+filetags: " tags "\n"
            "#+date:     " (format-time-string "[%Y-%m-%d %a]" monday) "\n\n"
            "* Review\n\n* Projects\n\n* Notes promoted\n\n* Next week\n")))

(defun my/journal--ensure-file (file skeleton)
  "Ensure FILE exists with SKELETON contents; return its path."
  (unless (file-exists-p file)
    (with-temp-buffer
      (insert skeleton)
      (write-region (point-min) (point-max) file)))
  file)

(defun my/journal--open (file skeleton)
  "Open FILE; if empty, insert SKELETON."
  (find-file file)
  (when (= (point-max) 1)
    (insert skeleton)))

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

;; Bindings (`C-c n j', `C-c n w', `C-c n W j', `C-c n W w', etc.) live
;; in `core/dl-keymap.el' under `my-notes-map' and `my-notes-work-map'.
;; The global `<f1>' shortcut for `my/journal-quick-capture' lives in
;; `core/dl-keybind.el' (which also relocates `help-command' to C-<f1>).

(provide 'dl-denote-journal)
;;; dl-denote-journal.el ends here
