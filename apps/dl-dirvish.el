;;; dl-dirvish.el --- Dirvish + yazi/broot wrappers -*- lexical-binding: t; -*-

;; `dired' core config lives in `apps/dl-dired.el'.

(use-package dirvish
  :init

  :custom
  (dirvish-quick-access-entries ; It's a custom option, `setq' won't work
    '( ("h" "~/"                          "Home")
       ("d" "~/dev/"                      "dev")
       ("D" "~/Downloads/"                "Downloads")
       ("n" "~/notes/"                    "notes")
       ("c" "~/.config/"                  "config")

       ("t" "~/.local/share/Trash/files/" "TrashCan")))
  :config
  (dirvish-override-dired-mode) 
  ;; (dirvish-peek-mode) ; Preview files in minibuffer
  ;; (dirvish-side-follow-mode) ; similar to `treemacs-follow-mode'
  (setq dirvish-mode-line-format
    '(:left (sort symlink) :right (omit yank index)))
  (setq dirvish-attributes           ; The order *MATTERS* for some attributes
    '(vc-state subtree-state nerd-icons collapse git-msg file-time file-size)
    dirvish-side-attributes
    '(vc-state nerd-icons collapse file-size))
  ;; open large directory (over 20000 files) asynchronously with `fd' command
  (setq dirvish-large-directory-threshold 20000)
  :bind ; Bind `dirvish-fd|dirvish-side|dirvish-dwim' as you see fit
  (:map dirvish-mode-map                ; Dirvish inherits `dired-mode-map'
    (";"   . dired-up-directory)        ; So you can adjust `dired' bindings here
    ("?"   . dirvish-dispatch)          ; [?] a helpful cheatsheet
    ("a"   . dirvish-setup-menu)        ; [a]ttributes settings:`t' toggles mtime, `f' toggles fullframe, etc.
    ("f"   . dirvish-file-info-menu)    ; [f]ile info
    ("o"   . dirvish-quick-access)      ; [o]pen `dirvish-quick-access-entries'
    ("s"   . dirvish-quicksort)         ; [s]ort flie list
    ("r"   . dirvish-history-jump)      ; [r]ecent visited
    ("l"   . dirvish-ls-switches-menu)  ; [l]s command flags
    ("v"   . dirvish-vc-menu)           ; [v]ersion control commands
    ("*"   . dirvish-mark-menu)
    ("y"   . dirvish-yank-menu)
    ("N"   . dirvish-narrow)
    ("^"   . dirvish-history-last)
    ("TAB" . dirvish-subtree-toggle)
    ("M-f" . dirvish-history-go-forward)
    ("M-b" . dirvish-history-go-backward)
    ("M-e" . dirvish-emerge-menu)))

(declare-function ghostel-exec "ghostel" (buffer program &optional args))

(defun my/file-manager-directory ()
  "Useful starting directory for external file-manager commands."
  (if buffer-file-name
    (file-name-directory buffer-file-name)
    default-directory))

(defun my/file-manager--launch (program args buffer-prefix on-exit-file
                                 on-exit-handler)
  "Run PROGRAM ARGS in a ghostel buffer; call ON-EXIT-HANDLER with ON-EXIT-FILE.

ARGS already contains the temp-file flag (e.g. \\='--cwd-file\\=' for yazi).
When the program finishes the sentinel reads ON-EXIT-FILE, calls
ON-EXIT-HANDLER with its trimmed contents, deletes the temp file, and
kills the ghostel buffer."
  (let* ((dir (my/file-manager-directory))
          (buf (get-buffer-create
                 (format "*%s:%s*" buffer-prefix
                   (file-name-nondirectory (directory-file-name dir))))))
    (with-current-buffer buf (setq default-directory dir))
    (pop-to-buffer buf)
    (ghostel-exec buf program args)
    (set-process-sentinel
      (get-buffer-process buf)
      (lambda (proc event)
        (when (string-match-p "\\(finished\\|exited\\)" event)
          (let ((pbuf (process-buffer proc))
                 (value (when (file-readable-p on-exit-file)
                          (prog1 (string-trim
                                   (with-temp-buffer
                                     (insert-file-contents on-exit-file)
                                     (buffer-string)))
                            (delete-file on-exit-file)))))
            (when (buffer-live-p pbuf)
              (let ((kill-buffer-query-functions nil))
                (kill-buffer pbuf)))
            (when (and value (not (string-empty-p value)))
              (funcall on-exit-handler value))))))))

(defun my/yazi-here ()
  "Open Yazi in a ghostel buffer; on exit, jump Dired to its cwd."
  (interactive)
  (let ((tmp (make-temp-file "yazi-cwd-")))
    (my/file-manager--launch
      "yazi" (list "--cwd-file" tmp) "yazi" tmp
      (lambda (path)
        (when (file-directory-p path) (dired path))))))

(defun my/broot--parse-outcmd (text)
  "Extract a path from broot --outcmd TEXT.
Broot's `:cd' verb writes a shell `cd PATH' line; quoted or bare. We
treat the rest of the line as the target."
  (when (string-match "\\`[[:space:]]*cd[[:space:]]+\\(.+?\\)[[:space:]]*\\'" text)
    (let ((arg (match-string 1 text)))
      (cond
        ((string-match "\\`\"\\(.*\\)\"\\'" arg) (match-string 1 arg))
        ((string-match "\\`'\\(.*\\)'\\'" arg) (match-string 1 arg))
        (t arg)))))

(defun my/broot-here ()
  "Open Broot in a ghostel buffer; on exit, dired the chosen directory.
Use alt-enter (broot\\='s `:cd' verb) on a directory to select it."
  (interactive)
  (let ((tmp (make-temp-file "broot-out-")))
    (my/file-manager--launch
      "broot" (list "--outcmd" tmp) "broot" tmp
      (lambda (text)
        (when-let ((path (my/broot--parse-outcmd text)))
          (cond ((file-directory-p path) (dired path))
            ((file-exists-p path) (find-file path))))))))

(provide 'dl-dirvish)
