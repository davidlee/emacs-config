;;; dl-zmx.el --- project terminals in zmx sessions -*- lexical-binding: t; -*-

;; A ghostel buffer `term-PROJECT.ID' attached to zmx session `PROJECT.ID'
;; running `dl-zmx-shell'.  Sessions survive Emacs, and killing a buffer only
;; detaches: `exit' in the shell or `my/zmx-kill' ends a session.
;;
;;   `my/zmx-new'          next numbered session, at `default-directory'
;;   `my/zmx-new-at-root'  the same, at the project root
;;   `my/zmx-resume'       this project's latest session, or a new one
;;   `my/zmx-project'      a session with an identifier you type
;;   `my/zmx-switch'       any running session: its buffer, or reattach
;;   `my/zmx-kill'         end a running session
;;
;; Outside a project, the directory's name stands in for PROJECT.  A TRAMP
;; directory gets a plain ghostel, as zmx is local.
;;
;;   ghostel term-P.ID  (cwd: project root)
;;     `-- zmx attach P.ID nu
;;           (nu's pre_prompt hook loads direnv)
;;
;; `zmx' is the zmux wrapper, installed by overlay.  From the name it writes the
;; `project' and `id' labels and starts the session in its own systemd scope,
;; which is what survives an `emacs.service' restart.  So this file composes
;; `PROJECT.ID' and attaches.  The wrapper refuses a name with a second dot, so a
;; dotted project folds to `_' here, as zp's does.  An identifier keeps its dots:
;; a new one is refused in the buffer, and an existing session stays reachable.

(require 'seq)
(require 'subr-x)
(require 'project)
(require 'url-util)
(autoload 'ghostel-exec "ghostel")   ; ghostel only autoloads its commands
(declare-function ghostel "ghostel")

(defgroup dl-zmx nil
  "Persistent project terminals via zmx."
  :group 'terminals)

(defcustom dl-zmx-command "zmx"
  "Command used to invoke zmx.
Use the zmux wrapper: it supplies labels and a scope."
  :type 'string)

(defcustom dl-zmx-shell "nu"
  "Shell zmx runs in a new session."
  :type 'string)

;;; Names

(defun dl-zmx--label-safe (string)
  "Return STRING with characters zmx labels reject replaced by `-'."
  (replace-regexp-in-string "[^a-zA-Z0-9._-]" "-" string))

(defun dl-zmx--project-key (project)
  "Return PROJECT's name as used in session names."
  (string-replace "." "_"
                  (dl-zmx--label-safe (string-trim-left project "\\.+"))))

(defun dl-zmx-session-name (project identifier)
  "Return the zmx session name for PROJECT and IDENTIFIER."
  (format "%s.%s" (dl-zmx--project-key project) (dl-zmx--label-safe identifier)))

(defun dl-zmx-next-name (project names)
  "Return the session name one above PROJECT's highest number among NAMES."
  (let ((numbers (seq-filter (lambda (id) (string-match-p "\\`[0-9]+\\'" id))
                             (dl-zmx-project-identifiers project names))))
    (dl-zmx-session-name
     project
     (number-to-string (1+ (apply #'max 0 (mapcar #'string-to-number numbers)))))))

(defun dl-zmx--scope-name ()
  "Return the current project's name, or else the directory's."
  (if-let* ((project (project-current)))
      (project-name project)
    (file-name-nondirectory (directory-file-name default-directory))))

(defun dl-zmx-buffer-name (session)
  "Return the ghostel buffer name for zmx SESSION."
  (concat "term-" session))

(defun dl-zmx-attach-argv (session)
  "Return argv attaching to SESSION, creating it if absent."
  (list dl-zmx-command "attach" session dl-zmx-shell))

;;; Sessions: `zmx list' records, alists of field strings

(defun dl-zmx--parse-sessions (output)
  "Return the sessions in `zmx list' OUTPUT, as alists of fields.
An `ended' field reports the last `zmx run' task, not the session: its shell
lives on, and attaching reaches it."
  (mapcar (lambda (line)
            (mapcar (lambda (field)
                      (let ((i (string-search "=" field)))
                        (cons (intern (substring field 0 i))
                              (substring field (1+ i)))))
                    (split-string line "\t" t " +")))
          (split-string output "\n" t)))

(defun dl-zmx-sessions ()
  "Return running zmx sessions, as alists of fields.
stderr is discarded: with no sessions, zmx reports that there."
  (dl-zmx--parse-sessions
   (with-output-to-string
     (call-process dl-zmx-command nil (list standard-output nil) nil "list"))))

(defun dl-zmx--session-names ()
  "Return the names of running zmx sessions."
  (mapcar (lambda (session) (alist-get 'name session)) (dl-zmx-sessions)))

(defun dl-zmx-latest-session (project sessions)
  "Return PROJECT's newest session among SESSIONS, or nil.
Grouped by the `project' label, which is the truth a name only suggests."
  (let ((key (dl-zmx--project-key project)))
    (car (seq-sort-by
          (lambda (session) (string-to-number (alist-get 'created session "0")))
          #'>
          (seq-filter (lambda (session) (equal (alist-get 'project session) key))
                      sessions)))))

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
  "Open zmx session PROJECT.IDENTIFIER in a terminal at the project root.
Completes the identifiers of the project's running sessions."
  (interactive
   (list (completing-read "zmx session: "
                          (dl-zmx-project-identifiers
                           (project-name (project-current t))
                           (dl-zmx--session-names)))))
  (when (string-empty-p identifier)
    (user-error "Empty zmx session identifier"))
  (let* ((project (project-current t))
         (session (dl-zmx-session-name (project-name project) identifier))
         (default-directory (project-root project)))
    (dl-zmx--open session (dl-zmx-attach-argv session))))

(defun dl-zmx--reattach (session)
  "Show SESSION, a record: its buffer, or a new one reattached to it."
  (let ((name (alist-get 'name session))
        (default-directory (or (dl-zmx--session-dir session) default-directory)))
    (dl-zmx--open name (dl-zmx-attach-argv name))))

(defun my/zmx-switch (session)
  "Show running zmx SESSION: its buffer, or a new one reattached to it."
  (interactive (list (dl-zmx--read-session "zmx: ")))
  (dl-zmx--reattach session))

(defun my/zmx-new ()
  "Open a new numbered zmx session at `default-directory'."
  (interactive)
  (if (file-remote-p default-directory)
      (ghostel '(4))
    (let ((session (dl-zmx-next-name (dl-zmx--scope-name)
                                     (dl-zmx--session-names))))
      (dl-zmx--open session (dl-zmx-attach-argv session)))))

(defun my/zmx-new-at-root ()
  "Open a new numbered zmx session at the project root."
  (interactive)
  (let ((default-directory (project-root (project-current t))))
    (my/zmx-new)))

(defun my/zmx-resume ()
  "Show this project's latest zmx session, or open a new one."
  (interactive)
  (if-let* (((not (file-remote-p default-directory)))
            (session (dl-zmx-latest-session (dl-zmx--scope-name)
                                            (dl-zmx-sessions))))
      (dl-zmx--reattach session)
    (my/zmx-new)))

(defun my/zmx-kill (session)
  "End running zmx SESSION.  Its buffer closes with its shell."
  (interactive (list (dl-zmx--read-session "Kill zmx session: ")))
  (let ((name (alist-get 'name session)))
    (when (y-or-n-p (format "Kill zmx session %s? " name))
      (call-process dl-zmx-command nil nil nil "kill" name))))

;; `C-c p p' menu: switch project, then `z'.
(add-to-list 'project-switch-commands '(my/zmx-project "zmx" "z") t)

(provide 'dl-zmx)
;;; dl-zmx.el ends here
