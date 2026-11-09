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
;; `consult-buffer' offers sessions without a terminal on the narrow key `z',
;; previewing their scrollback.
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
;; a new one is refused at the prompt, as the wrapper's own refusal would close
;; the buffer before it could be read, and an existing session stays reachable.

(require 'seq)
(require 'subr-x)
(require 'project)
(require 'url-util)
(autoload 'ghostel-exec "ghostel")   ; ghostel only autoloads its commands
(autoload 'ghostel-mode "ghostel")
(declare-function ghostel "ghostel")
(declare-function consult--buffer-preview "consult")

(defgroup dl-zmx nil
  "Persistent project terminals via zmx."
  :group 'terminals)

(defcustom dl-zmx-command "zmx"
  "Command used to invoke zmx.
Use the zmux wrapper: it supplies labels and a scope."
  :type 'string)

(defcustom dl-zmx-shell "zsh" ;; TODO get from $SHELL
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

(defun dl-zmx-creatable-name-p (name)
  "Return non-nil if NAME has the wrapper's form for a new session.
That is one dot, with a part on each side."
  (string-match-p "\\`[^.]+\\.[^.]+\\'" name))

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
lives on, and attaching reaches it.  An arrow marks the caller's own session."
  (mapcar (lambda (line)
            (mapcar (lambda (field)
                      (let ((i (string-search "=" field)))
                        (cons (intern (substring field 0 i))
                              (substring field (1+ i)))))
                    (split-string line "\t" t "[ →]+")))
          (split-string output "\n" t)))

(defun dl-zmx--output (&rest args)
  "Return what zmx prints for ARGS.
stderr is discarded: with no sessions, zmx reports that there.  The caller's
directory may no longer exist, and `call-process' would refuse it."
  (let ((default-directory temporary-file-directory))
    (with-output-to-string
      (apply #'call-process dl-zmx-command nil (list standard-output nil) nil args))))

(defun dl-zmx-sessions ()
  "Return running zmx sessions, as alists of fields."
  (dl-zmx--parse-sessions (dl-zmx--output "list")))

(defun dl-zmx--session-names ()
  "Return the names of running zmx sessions."
  (mapcar (lambda (session) (alist-get 'name session)) (dl-zmx-sessions)))

(defun dl-zmx--check-reachable (name)
  "Signal a `user-error' unless NAME can be created or is already running."
  (unless (or (dl-zmx-creatable-name-p name)
              (member name (dl-zmx--session-names)))
    (user-error "Cannot create zmx session %s: a name holds one dot, between \
a project and an identifier" name)))

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
  "Return SESSION's working directory, or nil if not reported.
The shell reports it by OSC 7: `file://' percent-encodes the path, and
`kitty-shell-cwd://', from ghostel's bash and zsh integrations, does not."
  (when-let* ((cwd (alist-get 'cwd session)))
    (file-name-as-directory
     (if (string-match "\\`kitty-shell-cwd://[^/]*" cwd)
         (substring cwd (match-end 0))
       (url-unhex-string (replace-regexp-in-string "\\`file://[^/]*" "" cwd))))))

(defconst dl-zmx--state-icons
  '((nil "·" shadow)
    ("done" "●" success)
    ("working" "◐" font-lock-keyword-face)
    ("blocked" "🔔" warning)
    ("failed" "⊘" error))
  "Icon and face for each value of the `state' label; nil is an absent one.")

(defun dl-zmx--state-icon (state)
  "Return the coloured icon for STATE, a `state' label's value or nil."
  (pcase-let ((`(,icon ,face) (or (cdr (assoc state dl-zmx--state-icons))
                                  '("*" shadow))))
    (propertize icon 'face face)))

(defun dl-zmx--state-column (state)
  "Return the icon for STATE, padded so that the text after it lines up."
  (let ((icon (dl-zmx--state-icon state)))
    (concat icon (make-string (- 3 (string-width icon)) ?\s))))

(defconst dl-zmx--unpaired-fields
  '(name pid clients created cwd ended exit_code cmd project id role state)
  "`zmx list' fields kept out of the annotation's pairs.
zmx's own, which it doesn't mark apart from labels, and labels shown elsewhere.")

(defun dl-zmx--field-pairs (session)
  "Return SESSION's labels as `key:value' strings.
`exit_code' joins them beside a `state', as neither is believed alone."
  (let ((unpaired (if (alist-get 'state session)
                      (remq 'exit_code dl-zmx--unpaired-fields)
                    dl-zmx--unpaired-fields)))
    (mapcar (lambda (field) (format "%s:%s" (car field) (cdr field)))
            (seq-remove (lambda (field) (memq (car field) unpaired)) session))))

(defun dl-zmx--annotation (session)
  "Return a completion annotation for SESSION.
Its state icon, then project, clients, directory and labels.  The text carries
its own face, as the icon's stops a completion UI applying one."
  (concat "  "
          (dl-zmx--state-column (alist-get 'state session))
          (propertize
           (string-join
            (append (delq nil (list (alist-get 'project session)
                                    (concat (alist-get 'clients session) " attached")
                                    (when-let* ((dir (dl-zmx--session-dir session)))
                                      (abbreviate-file-name dir))))
                    (dl-zmx--field-pairs session))
            "  ")
           'face 'completions-annotations)))

(defun dl-zmx--widest (strings)
  "Return the width of the widest of STRINGS."
  (apply #'max 0 (mapcar #'string-width strings)))

(defun dl-zmx--candidates (sessions)
  "Return an alist of completion candidate to record for SESSIONS.
A `role' follows the name, aligned, in the candidate so that it can be searched."
  (let ((width (dl-zmx--widest (mapcar (lambda (session) (alist-get 'name session))
                                       sessions))))
    (mapcar (lambda (session)
              (let ((name (alist-get 'name session)))
                (cons (if-let* ((role (alist-get 'role session)))
                          (concat (string-pad name width) "  " role)
                        name)
                      session)))
            sessions)))

(defun dl-zmx--annotator (by-candidate)
  "Return a function annotating the keys of BY-CANDIDATE, aligned."
  (let ((width (dl-zmx--widest (mapcar #'car by-candidate))))
    (lambda (candidate)
      (concat (make-string (- width (string-width candidate)) ?\s)
              (dl-zmx--annotation (alist-get candidate by-candidate nil nil #'equal))))))

(defun dl-zmx-project-identifiers (project names)
  "Return identifiers of PROJECT's sessions among session NAMES."
  (let ((prefix (dl-zmx-session-name project "")))
    (mapcar (lambda (name) (string-remove-prefix prefix name))
            (seq-filter (lambda (name) (string-prefix-p prefix name)) names))))

(defun dl-zmx--read-session (prompt)
  "Read a running session with PROMPT, annotated; return its record."
  (let* ((by-candidate (dl-zmx--candidates
                        (or (dl-zmx-sessions)
                            (user-error "No running zmx sessions"))))
         (completion-extra-properties
          (list :annotation-function (dl-zmx--annotator by-candidate))))
    (alist-get (completing-read prompt by-candidate nil t)
               by-candidate nil nil #'equal)))

;;; Commands

(defun dl-zmx--open (session argv)
  "Pop to SESSION's ghostel buffer; run ARGV in it unless already running.
The mode comes before the display, for the terminal rule in `dl-term'."
  (let ((buf (get-buffer-create (dl-zmx-buffer-name session))))
    (with-current-buffer buf
      (unless (derived-mode-p 'ghostel-mode)
        (ghostel-mode)))
    (pop-to-buffer buf)              ; display first: size the PTY to the window
    (unless (process-live-p (get-buffer-process buf))
      (ghostel-exec buf (car argv) (cdr argv))
      ;; ghostel has no public way to name the shell, which its history needs.
      (with-current-buffer buf
        (setq-local ghostel--shell-program dl-zmx-shell)))))

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
    (dl-zmx--check-reachable session)
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
      (dl-zmx--check-reachable session)
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

;;; `consult-buffer': sessions without a terminal

(defun dl-zmx--terminal-live-p (session)
  "Return non-nil if SESSION, a record, has a live terminal buffer."
  (process-live-p (get-buffer-process
                   (dl-zmx-buffer-name (alist-get 'name session)))))

(defun dl-zmx--consult-items ()
  "Return candidates for sessions without a live terminal.
Each carries its record as a text property."
  (mapcar (pcase-lambda (`(,candidate . ,session))
            (propertize candidate 'dl-zmx-session session))
          (dl-zmx--candidates
           (seq-remove #'dl-zmx--terminal-live-p (dl-zmx-sessions)))))

(defconst dl-zmx--preview-buffer-name " *zmx preview*"
  "Buffer holding the scrollback `consult-buffer' previews.")

(defun dl-zmx--scrollback-buffer (session)
  "Return the preview buffer, holding the scrollback of SESSION, a name."
  (with-current-buffer (get-buffer-create dl-zmx--preview-buffer-name)
    (erase-buffer)
    (insert (dl-zmx--output "history" session))
    (current-buffer)))

(defun dl-zmx--show-end (buffer)
  "Move the window showing BUFFER to its end, where a terminal would be."
  (when-let* ((window (get-buffer-window buffer)))
    (set-window-point window (with-current-buffer buffer (point-max)))))

(defun dl-zmx--consult-state ()
  "Return a `consult' state function previewing a session's scrollback.
Attaching would disturb the session, and leave a terminal behind."
  (let ((preview (consult--buffer-preview)))
    (lambda (action candidate)
      (let ((buffer (when (and candidate (eq action 'preview))
                      (dl-zmx--scrollback-buffer
                       (alist-get 'name (get-text-property
                                         0 'dl-zmx-session candidate))))))
        (funcall preview action buffer)
        (when buffer (dl-zmx--show-end buffer)))
      (when-let* (((eq action 'exit))
                  (buffer (get-buffer dl-zmx--preview-buffer-name)))
        (kill-buffer buffer)))))

(defvar dl-zmx-consult-source
  `( :name     "zmx"
     :narrow   (?z . "zmx")
     :hidden   t
     :category zmx-session
     :enabled  ,(lambda () (executable-find dl-zmx-command))
     :items    ,#'dl-zmx--consult-items
     :state    ,#'dl-zmx--consult-state
     ;; Unpadded, unlike the picker's: consult aligns annotations itself.
     :annotate ,(lambda (candidate)
                  (dl-zmx--annotation (get-text-property 0 'dl-zmx-session candidate)))
     :action   ,(lambda (candidate)
                  (dl-zmx--reattach (get-text-property 0 'dl-zmx-session candidate))))
  "`consult-buffer' source of sessions without a terminal.
Live terminals are `consult-ghostel's, on the narrow key `g'.")

(defvar consult-buffer-sources)
(with-eval-after-load 'consult
  (add-to-list 'consult-buffer-sources 'dl-zmx-consult-source t))

;; `C-c p p' menu: switch project, then `z'.
(add-to-list 'project-switch-commands '(my/zmx-project "zmx" "z") t)

(provide 'dl-zmx)
;;; dl-zmx.el ends here
