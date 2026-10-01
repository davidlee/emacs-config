;;; dl-zmx.el --- project terminals in zmx sessions -*- lexical-binding: t; -*-

;; `my/zmx-project': a ghostel buffer `term-PROJECT-ID' attached to zmx
;; session `PROJECT-ID' running `dl-zmx-shell'.  `my/zmx-switch': pick any
;; running session; jump to its buffer, or reattach.  Sessions survive Emacs.
;;
;;   ghostel term-P-ID  (cwd: project root)
;;     `-- systemd-run --scope   (own cgroup: survives emacs.service restarts)
;;           `-- zmx attach [--labels "project=P id=ID"] P-ID nu
;;                 (nu's pre_prompt hook loads direnv)

(require 'seq)
(require 'subr-x)
(require 'project)
(require 'url-util)
(autoload 'ghostel-exec "ghostel")   ; ghostel only autoloads its commands

(defgroup dl-zmx nil
  "Persistent project terminals via zmx."
  :group 'terminals)

(defcustom dl-zmx-command "zmx"
  "Command used to invoke zmx."
  :type 'string)

(defcustom dl-zmx-shell "nu"
  "Shell zmx runs in a new session."
  :type 'string)

(defcustom dl-zmx-launcher '("systemd-run" "--user" "--scope" "--collect" "--quiet")
  "Command prefix that starts zmx outside Emacs's cgroup.
zmx's daemon detaches from its parent but stays in its cgroup, so under
`emacs.service' (KillMode=control-group) an Emacs restart kills every
session.  A transient scope per session keeps it alive.  nil: run bare."
  :type '(repeat string))

;;; Names

(defun dl-zmx--label-safe (string)
  "Return STRING with characters zmx labels reject replaced by `-'."
  (replace-regexp-in-string "[^a-zA-Z0-9._-]" "-" string))

(defun dl-zmx--project-key (project)
  "Return PROJECT's name as used in session names and labels."
  (dl-zmx--label-safe (string-trim-left project "\\.+")))

(defun dl-zmx-session-name (project identifier)
  "Return the zmx session name for PROJECT and IDENTIFIER."
  (format "%s-%s" (dl-zmx--project-key project) (dl-zmx--label-safe identifier)))

(defun dl-zmx-labels (project identifier)
  "Return zmx labels for PROJECT's session IDENTIFIER."
  (format "project=%s id=%s"
          (dl-zmx--project-key project) (dl-zmx--label-safe identifier)))

(defun dl-zmx-buffer-name (session)
  "Return the ghostel buffer name for zmx SESSION."
  (concat "term-" session))

(defun dl-zmx-attach-argv (session &optional labels)
  "Return argv attaching to SESSION, creating it if absent.
LABELS (see `dl-zmx-labels') only take effect on creation."
  (append dl-zmx-launcher
          (list dl-zmx-command "attach")
          (and labels (list "--labels" labels))
          (list session dl-zmx-shell)))

;;; Sessions: `zmx list' records, alists of field strings

(defun dl-zmx--parse-sessions (output)
  "Return running sessions in `zmx list' OUTPUT, as alists of fields.
Exited sessions stay listed with an `ended' field; they are skipped."
  (seq-remove
   (lambda (session) (assq 'ended session))
   (mapcar (lambda (line)
             (mapcar (lambda (field)
                       (let ((i (string-search "=" field)))
                         (cons (intern (substring field 0 i))
                               (substring field (1+ i)))))
                     (split-string line "[\t ]+" t)))
           (split-string output "\n" t))))

(defun dl-zmx-sessions ()
  "Return running zmx sessions, as alists of fields."
  (dl-zmx--parse-sessions
   (with-output-to-string
     (call-process dl-zmx-command nil standard-output nil "list"))))

(defun dl-zmx--session-dir (session)
  "Return SESSION's working directory, or nil if not reported."
  (when-let* ((cwd (alist-get 'cwd session)))
    (file-name-as-directory
     (url-unhex-string (replace-regexp-in-string "\\`file://[^/]*" "" cwd)))))

(defun dl-zmx--annotation (session)
  "Return a completion annotation for SESSION: project, clients, directory."
  (concat "  "
          (string-join
           (delq nil (list (alist-get 'project session)
                           (concat (alist-get 'clients session) " attached")
                           (when-let* ((dir (dl-zmx--session-dir session)))
                             (abbreviate-file-name dir))))
           "  ")))

(defun dl-zmx-project-identifiers (project names)
  "Return identifiers of PROJECT's sessions among session NAMES."
  (let ((prefix (dl-zmx-session-name project "")))
    (mapcar (lambda (name) (string-remove-prefix prefix name))
            (seq-filter (lambda (name) (string-prefix-p prefix name)) names))))

(defun dl-zmx--read-session (prompt)
  "Read a running session with PROMPT, annotated; return its record."
  (let* ((by-name (mapcar (lambda (session) (cons (alist-get 'name session) session))
                          (or (dl-zmx-sessions)
                              (user-error "No running zmx sessions"))))
         (completion-extra-properties
          (list :annotation-function
                (lambda (name)
                  (dl-zmx--annotation (alist-get name by-name nil nil #'equal))))))
    (alist-get (completing-read prompt by-name nil t) by-name nil nil #'equal)))

;;; Commands

(defun dl-zmx--open (session argv)
  "Pop to SESSION's ghostel buffer; run ARGV in it unless already running."
  (let ((buf (get-buffer-create (dl-zmx-buffer-name session))))
    (pop-to-buffer buf)              ; display first: size the PTY to the window
    (unless (process-live-p (get-buffer-process buf))
      (ghostel-exec buf (car argv) (cdr argv)))))

(defun my/zmx-project (identifier)
  "Open zmx session PROJECT-IDENTIFIER in a terminal at the project root.
Completes the identifiers of the project's running sessions."
  (interactive
   (list (completing-read "zmx session: "
                          (dl-zmx-project-identifiers
                           (project-name (project-current t))
                           (mapcar (lambda (session) (alist-get 'name session))
                                   (dl-zmx-sessions))))))
  (when (string-empty-p identifier)
    (user-error "Empty zmx session identifier"))
  (let* ((project (project-current t))
         (name (project-name project))
         (session (dl-zmx-session-name name identifier))
         (default-directory (project-root project)))
    (dl-zmx--open session
                  (dl-zmx-attach-argv session (dl-zmx-labels name identifier)))))

(defun my/zmx-switch (session)
  "Show running zmx SESSION: its buffer, or a new one reattached to it."
  (interactive (list (dl-zmx--read-session "zmx: ")))
  (let ((name (alist-get 'name session))
        (default-directory (or (dl-zmx--session-dir session) default-directory)))
    (dl-zmx--open name (dl-zmx-attach-argv name))))

;; `C-c p p' menu: switch project, then `z'.
(add-to-list 'project-switch-commands '(my/zmx-project "zmx" "z") t)

(provide 'dl-zmx)
;;; dl-zmx.el ends here
