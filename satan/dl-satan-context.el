;;; dl-satan-context.el --- Build the run input bundle -*- lexical-binding: t; -*-

;; A context function returns the input-bundle plist that gets written to
;; `bundle.json' under the run directory.  Bundle is what the harness sees;
;; it is also frozen for audit.

(require 'subr-x)
(require 'dl-notes-paths)
(require 'dl-denote-journal)

(defcustom dl-satan-system-scaffold-file
  (expand-file-name "satan/system/scaffold.txt" dl-notes-root)
  "Shared system-prompt scaffold prepended to every mode prompt.
Canonical text lives under `~/notes/satan/system/'; dotfiles must
not be the source of truth for behavioural framing."
  :type 'file :group 'dl-satan)

(defcustom dl-satan-system-framing-file
  (expand-file-name "satan/system/framing.txt" dl-notes-root)
  "Bundle-section headers for context blocks the broker appends to `:prompt'.
Each call to a context-fn reads this file fresh to assemble the
`# Now' / `# Today (raw)' / `# Source files' headers added after the
scaffold + mode prompt.  Mind owns these strings; dotfiles only own
the value substitution."
  :type 'file :group 'dl-satan)

(defun dl-satan-context--read-file-or-empty (path)
  "Return contents of PATH, or empty string if missing.
Use for optional context (e.g. today's note) — never for required
model-facing text; use `dl-satan-context--read-required' for that."
  (if (file-readable-p path)
      (with-temp-buffer
        (let ((coding-system-for-read 'utf-8))
          (insert-file-contents path))
        (buffer-string))
    ""))

(defun dl-satan-context--read-required (path)
  "Return contents of PATH; signal if missing.
Use for canonical model-facing text where silent emptiness would be
a misconfiguration: mode prompts, the system scaffold."
  (unless (file-readable-p path)
    (error "SATAN: required model-facing file missing: %s" path))
  (with-temp-buffer
    (let ((coding-system-for-read 'utf-8))
      (insert-file-contents path))
    (buffer-string)))

(defun dl-satan-context--assemble-prompt (mode-spec)
  "Return MODE-SPEC's assembled system prompt: scaffold + mode prompt.
Both halves are required; missing files signal an error so a run
cannot start with degraded behavioural framing."
  (let* ((prompt-path (plist-get mode-spec :prompt-file))
         (scaffold (string-trim-right
                    (dl-satan-context--read-required
                     dl-satan-system-scaffold-file)))
         (prompt (string-trim-right
                  (dl-satan-context--read-required prompt-path))))
    (concat scaffold "\n\n" prompt)))

(defun dl-satan-context--parse-framing (text)
  "Parse TEXT as `key=value' lines; return an alist.
Lines starting with `#' or that contain no `=' are ignored."
  (let (acc)
    (dolist (line (split-string text "\n"))
      (let ((trimmed (string-trim line)))
        (unless (or (string-empty-p trimmed)
                    (string-prefix-p "#" trimmed))
          (let ((eq (string-search "=" line)))
            (when eq
              (push (cons (string-trim (substring line 0 eq))
                          (substring line (1+ eq)))
                    acc))))))
    (nreverse acc)))

(defun dl-satan-context--framing ()
  "Return framing alist loaded from `dl-satan-system-framing-file'.
Required keys: `now', `today', `sources'.  Missing file signals."
  (let ((alist (dl-satan-context--parse-framing
                (dl-satan-context--read-required
                 dl-satan-system-framing-file))))
    (dolist (key '("now" "today" "sources"))
      (unless (assoc key alist)
        (error "SATAN: framing.txt missing required key: %s" key)))
    alist))

(defun dl-satan-context--render-now (framing now)
  "Return the rendered `# Now' block as a list of lines.
NOW is the bundle `:now' plist, FRAMING the parsed framing alist.
Returns nil when NOW is empty."
  (when (and (plistp now) now)
    (let* ((iso-date  (or (plist-get now :iso_date)  ""))
           (weekday   (or (plist-get now :weekday)   ""))
           (iso-week  (or (plist-get now :iso_week)  ""))
           (hm        (or (plist-get now :time)      ""))
           (tz-offset (or (plist-get now :tz_offset) ""))
           (tz-name   (or (plist-get now :tz_name)   ""))
           (suffix-bits (delq nil
                              (list (and (not (string-empty-p weekday)) weekday)
                                    (and (not (string-empty-p iso-week))
                                         (concat "ISO " iso-week)))))
           (suffix (if suffix-bits
                       (format " (%s)" (mapconcat #'identity suffix-bits ", "))
                     ""))
           (tz (string-trim
                (concat tz-offset (if (and (not (string-empty-p tz-offset))
                                           (not (string-empty-p tz-name)))
                                      " " "")
                        tz-name)))
           (lines (list (cdr (assoc "now" framing)))))
      (unless (string-empty-p iso-date)
        (push (format "date: %s%s" iso-date suffix) lines))
      (unless (string-empty-p hm)
        (push (format "time: %s%s" hm (if (string-empty-p tz) "" (concat " " tz)))
              lines))
      (nreverse lines))))

(defun dl-satan-context--render-today (framing today-text)
  "Return rendered `# Today (raw)' block as a list of lines, or nil if empty."
  (when (and (stringp today-text) (not (string-empty-p today-text)))
    (list (cdr (assoc "today" framing)) today-text)))

(defun dl-satan-context--render-sources (framing sources)
  "Return rendered `# Source files' block as a list of lines, or nil if empty."
  (when sources
    (let ((lines (list (cdr (assoc "sources" framing)))))
      (dolist (item sources)
        (let ((path (or (plist-get item :path) "?"))
              (content (or (plist-get item :content) "")))
          (push "" lines)
          (push (format "## %s" path) lines)
          (push "```" lines)
          (push content lines)
          (push "```" lines)))
      (nreverse lines))))

(defun dl-satan-context--render-prompt (assembled bundle)
  "Return the fully-rendered system prompt for the harness.
ASSEMBLED is the scaffold + mode-prompt string (no framing yet).
BUNDLE is the context plist providing `:now', `:today_text', `:sources'.
Missing framing.txt signals — there is no canonical fallback."
  (let* ((framing (dl-satan-context--framing))
         (parts (list (string-trim-right assembled)))
         (blocks (delq nil
                       (list
                        (dl-satan-context--render-now
                         framing (plist-get bundle :now))
                        (dl-satan-context--render-today
                         framing (plist-get bundle :today_text))
                        (dl-satan-context--render-sources
                         framing (plist-get bundle :sources))))))
    (dolist (block blocks)
      (push "" parts)
      (dolist (line block)
        (push line parts)))
    (mapconcat #'identity (nreverse parts) "\n")))

(defun dl-satan-context-now (&optional time)
  "Return the canonical `:now' plist for TIME (default `current-time').
Every bundle includes this so the model has consistent date/time/tz
framing regardless of mode.  Keys: :iso_date, :weekday, :iso_week,
:time, :tz_offset, :tz_name."
  (let ((time (or time (current-time))))
    (list :iso_date  (format-time-string "%Y-%m-%d" time)
          :weekday   (format-time-string "%A"       time)
          :iso_week  (format-time-string "%G-W%V"   time)
          :time      (format-time-string "%H:%M"    time)
          :tz_offset (format-time-string "%z"       time)
          :tz_name   (format-time-string "%Z"       time))))

(defun dl-satan-context--finalize-prompt (bundle assembled)
  "Replace BUNDLE's `:prompt' with the fully-rendered prompt.
ASSEMBLED is the scaffold + mode-prompt string the caller built.
The harness consumes `:prompt' verbatim; other bundle keys remain
for audit but are no longer read by the harness."
  (plist-put bundle :prompt (dl-satan-context--render-prompt assembled bundle)))

(defun dl-satan-context-morning (mode-spec)
  "Bundle for the morning mode: prompt + today's note text."
  (let* ((today (progn (my/journal--ensure-today)
                       (my/journal--today-file dl-notes-journal-dir "journal")))
         (assembled (dl-satan-context--assemble-prompt mode-spec))
         (bundle (list :prompt     ""
                       :mode       (plist-get mode-spec :name)
                       :now        (dl-satan-context-now)
                       :today_path today
                       :today_text (dl-satan-context--read-file-or-empty today))))
    (dl-satan-context--finalize-prompt bundle assembled)))

(defun dl-satan-context-motd (mode-spec)
  "Bundle for the motd mode."
  (let* ((assembled (dl-satan-context--assemble-prompt mode-spec))
         (bundle (list :prompt ""
                       :mode   (plist-get mode-spec :name)
                       :now    (dl-satan-context-now))))
    (dl-satan-context--finalize-prompt bundle assembled)))

(defun dl-satan-context-tick (mode-spec)
  "Bundle for a tick mode.  Same shape as motd."
  (let* ((assembled (dl-satan-context--assemble-prompt mode-spec))
         (bundle (list :prompt ""
                       :mode   (plist-get mode-spec :name)
                       :now    (dl-satan-context-now))))
    (dl-satan-context--finalize-prompt bundle assembled)))

(defcustom dl-satan-self-edit-mech-roots
  (list (expand-file-name "satan" user-emacs-directory))
  "Roots whose source is included in the `self-edit-mech' bundle.
Mech = the broker / handlers / harness / tests — Emacs-side
machinery that runs the SATAN protocol."
  :type '(repeat directory) :group 'dl-satan)

(defcustom dl-satan-self-edit-mind-roots
  (list (expand-file-name "satan/prompts" (or (bound-and-true-p dl-notes-root)
                                              (expand-file-name "~/notes")))
        (expand-file-name "satan/system"  (or (bound-and-true-p dl-notes-root)
                                              (expand-file-name "~/notes")))
        (expand-file-name "satan/tools"   (or (bound-and-true-p dl-notes-root)
                                              (expand-file-name "~/notes"))))
  "Roots whose source is included in the `self-edit-mind' bundle.
Mind = mode prompts, the system scaffold, tool descriptions —
model-facing text under `~/notes/satan/' that shapes behaviour."
  :type '(repeat directory) :group 'dl-satan)

(defcustom dl-satan-self-edit-source-regexp
  "\\.\\(el\\|py\\|txt\\|md\\)\\'"
  "Regexp matching filenames included in self-edit bundles."
  :type 'regexp :group 'dl-satan)

(defcustom dl-satan-self-edit-exclude-regexp
  "\\(\\.elc\\'\\|\\.original\\.md\\'\\|/test/.*\\.\\(local\\|secret\\)\\.\\)"
  "Regexp matching files to skip in self-edit bundles."
  :type 'regexp :group 'dl-satan)

(defcustom dl-satan-self-edit-bundle-char-budget 600000
  "Maximum total character count for `:sources' in a self-edit bundle.
Roughly 1 token per 4 chars in English text + code, so the default
caps at ~150k input tokens — leaving ~50k headroom under typical
200k provider context windows for the tool schemas and the model's
own output.  Files are packed alphabetically until the budget is
exhausted; overflow lands in `:dropped-files' so the model sees
what it didn't get."
  :type 'integer :group 'dl-satan)

(defun dl-satan-context-self-edit--list-files (root)
  "Return absolute paths of source files under ROOT, sorted."
  (let ((all (and (file-directory-p root)
                  (directory-files-recursively
                   root dl-satan-self-edit-source-regexp nil nil))))
    (sort (cl-remove-if
           (lambda (p)
             (string-match-p dl-satan-self-edit-exclude-regexp p))
           all)
          #'string<)))

(defun dl-satan-context-self-edit--pack-budgeted (files budget)
  "Pack FILES into a (sources . dropped) cons, capped at BUDGET chars.
SOURCES is a list of (:path ABBREVIATED :content STR); DROPPED is a
list of abbreviated paths that did not fit.  Greedy by alphabetical
order: keep until adding the next file would push total content
length over BUDGET.  Files larger than BUDGET themselves are skipped
into DROPPED rather than partially included (truncation is lossy
without context).  When BUDGET is nil, packs everything."
  (let ((spent 0) sources dropped)
    (dolist (f files)
      (let* ((content (dl-satan-context--read-file-or-empty f))
             (len (length content))
             (path (abbreviate-file-name f)))
        (cond
         ((null budget)
          (push (list :path path :content content) sources)
          (setq spent (+ spent len)))
         ((<= (+ spent len) budget)
          (push (list :path path :content content) sources)
          (setq spent (+ spent len)))
         (t (push path dropped)))))
    (cons (nreverse sources) (nreverse dropped))))

(defun dl-satan-context-self-edit (mode-spec)
  "Bundle for a self-edit mode: prompt + every source file under each
root in MODE-SPEC's `:source-roots' list, each as
\(:path ABBREVIATED :content STR).  Paths are abbreviated with `~/'
so the model sees `~/notes/satan/...' / `~/.emacs.d/satan/...' rather
than long relative dotwalks.

Total `:sources' content is capped by
`dl-satan-self-edit-bundle-char-budget'; anything that didn't fit
lands in `:dropped-files' so the model can see what it's missing
and (e.g.) recommend a narrower mode or a targeted read."
  (let* ((roots (or (plist-get mode-spec :source-roots)
                    (let ((var (plist-get mode-spec :source-roots-var)))
                      (and (symbolp var) (boundp var) (symbol-value var)))))
         (files (cl-loop for root in roots
                         append (dl-satan-context-self-edit--list-files root)))
         (packed (dl-satan-context-self-edit--pack-budgeted
                  files dl-satan-self-edit-bundle-char-budget))
         (sources (car packed))
         (dropped (cdr packed))
         (assembled (dl-satan-context--assemble-prompt mode-spec))
         (bundle (list :prompt  ""
                       :mode    (plist-get mode-spec :name)
                       :now     (dl-satan-context-now)
                       :roots   (mapcar #'abbreviate-file-name roots)
                       :sources sources
                       :dropped-files dropped)))
    (dl-satan-context--finalize-prompt bundle assembled)))

(provide 'dl-satan-context)
;;; dl-satan-context.el ends here
