;;; dl-zmx-status.el --- zmx session states in the mode line -*- lexical-binding: t; -*-

;; `dl-zmx-status-mode' counts zmx sessions, attached or not, by their `state'
;; label, with the session picker's icons: `🔔2 ◐1' is two waiting, one working.
;; Harnesses write the label (zmux), so it holds while no terminal is attached,
;; which ghostel's own status reports cannot.
;;
;;   timer, every `dl-zmx-status-interval' s
;;     `-- zmx list   (a subprocess: Emacs doesn't wait for it)
;;           `-- sentinel: parse, update `dl-zmx-status--text'
;;
;; While the mode is on, ghostel's indicator leaves zmx terminals out, so a session
;; isn't counted twice.

(require 'cl-lib)
(require 'seq)
(require 'subr-x)
(require 'dl-zmx)
(require 'dl-modeline)

(defcustom dl-zmx-status-interval 3
  "Seconds between polls of `zmx list'."
  :type 'number
  :group 'dl-zmx)

(defvar dl-zmx-status--text nil
  "Mode-line text from the last poll, or nil.")

(defvar dl-zmx-status--process nil
  "The last poll's `zmx list' process, or nil.")

(defvar dl-zmx-status--timer nil
  "The timer polling `zmx list', or nil.")

(defun dl-zmx-status-text (sessions)
  "Return the count of SESSIONS in each state, as icons, or nil.
In `dl-zmx--state-icons' order; a session without a known `state' isn't counted."
  (when-let* ((counts
               (delq nil
                     (mapcar (lambda (state)
                               (let ((count (seq-count
                                             (lambda (session)
                                               (equal (alist-get 'state session) state))
                                             sessions)))
                                 (when (> count 0)
                                   (concat (dl-zmx--state-icon state)
                                           (number-to-string count)))))
                             (delq nil (mapcar #'car dl-zmx--state-icons))))))
    (string-join counts " ")))

(defun dl-zmx-status--update (output)
  "Show the states of the sessions in `zmx list' OUTPUT."
  (let ((text (dl-zmx-status-text (dl-zmx--parse-sessions output))))
    (unless (equal text dl-zmx-status--text)
      (setq dl-zmx-status--text text)
      (force-mode-line-update t))))

(defun dl-zmx-status--poll ()
  "Start `zmx list', unless the last one is still running.
stderr goes to its own buffer, unread: with no sessions, zmx reports that there."
  (unless (process-live-p dl-zmx-status--process)
    (let* ((default-directory temporary-file-directory) ; see `dl-zmx--output'
           (out (generate-new-buffer " *zmx-status*" t))
           (err (generate-new-buffer " *zmx-status-err*" t)))
      (setq dl-zmx-status--process
            (make-process
             :name "zmx-status" :buffer out :stderr err :noquery t
             :connection-type 'pipe
             :command (list dl-zmx-command "list")
             :sentinel (lambda (process _event)
                         (unless (process-live-p process)
                           (dl-zmx-status--update
                            (with-current-buffer out (buffer-string)))
                           (kill-buffer out)
                           (let ((kill-buffer-query-functions nil))
                             (kill-buffer err)))))))))

(defun dl-zmx-status--segment ()
  "zmx session states for the active window's mode line, or nil."
  (when (and dl-zmx-status--text (dl-modeline-window-active-p))
    (concat dl-zmx-status--text " ")))

;; ghostel has no public way to leave a terminal out of its indicator.
(defun dl-zmx-status--without-zmx-terminals (indicator-text)
  "Call INDICATOR-TEXT, ghostel's, as though no zmx terminal held a status."
  (let ((buffers (symbol-function 'ghostel-status-buffers)))
    (cl-letf (((symbol-function 'ghostel-status-buffers)
               (lambda (&rest args)
                 (seq-remove #'dl-zmx-terminal-p (apply buffers args)))))
      (funcall indicator-text))))

(define-minor-mode dl-zmx-status-mode
  "Count zmx sessions by state in the mode line."
  :global t
  :group 'dl-zmx
  (when dl-zmx-status--timer
    (cancel-timer dl-zmx-status--timer)
    (setq dl-zmx-status--timer nil))
  (if dl-zmx-status-mode
      (progn
        (setq dl-zmx-status--timer
              (run-with-timer 0 dl-zmx-status-interval #'dl-zmx-status--poll))
        (add-to-list 'dl-modeline-segments #'dl-zmx-status--segment 'append)
        (advice-add 'ghostel-status--indicator-text :around
                    #'dl-zmx-status--without-zmx-terminals))
    (setq dl-zmx-status--text nil
          dl-modeline-segments (delq #'dl-zmx-status--segment dl-modeline-segments))
    (advice-remove 'ghostel-status--indicator-text
                   #'dl-zmx-status--without-zmx-terminals))
  (when (fboundp 'ghostel-status--update-indicator)
    (ghostel-status--update-indicator))
  (force-mode-line-update t))

(provide 'dl-zmx-status)
;;; dl-zmx-status.el ends here
