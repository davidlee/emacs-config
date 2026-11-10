;;; dl-bough.el --- Bough snapshot adapter -*- lexical-binding: t; -*-

;; Exports org-mode headings and denote notes as Bough-consumable
;; snapshot JSON files.  Bough reads these via `bough sync import';
;; this module never calls Bough — it only writes JSON.
;;
;; Org export uses org-ql to select headings, extracts org-id (creating
;; if absent), and writes the snapshot contract (version 1).  Denote
;; export enumerates `denote-directory-files' and extracts identifiers.

(require 'json)
(require 'org)
(require 'org-id)
(require 'dl-notes-paths)

(declare-function org-ql-select "org-ql")
(declare-function denote-directory-files "denote")
(declare-function denote-retrieve-filename-identifier "denote")
(declare-function denote-retrieve-filename-title "denote")
(declare-function denote-extract-keywords-from-path "denote")

;;; Configuration

(defgroup dl-bough nil
  "Bough snapshot export for org-mode and denote."
  :group 'tools)

(defcustom dl-bough-program
  (or (executable-find "bough")
      (expand-file-name "~/.cargo/bin/bough"))
  "Path to the bough binary (used by sync commands)."
  :type 'string
  :group 'dl-bough)

(defcustom dl-bough-org-files nil
  "Org files to include in snapshot export.
When nil, falls back to `my/org-agenda-combined-files'."
  :type '(repeat file)
  :group 'dl-bough)

(defcustom dl-bough-org-snapshot-path
  (expand-file-name "~/.cache/bough/org-snapshot.json")
  "Output path for the org snapshot file."
  :type 'file
  :group 'dl-bough)

(defcustom dl-bough-denote-snapshot-path
  (expand-file-name "~/.cache/bough/denote-snapshot.json")
  "Output path for the denote snapshot file."
  :type 'file
  :group 'dl-bough)

(defcustom dl-bough-org-predicate '(todo)
  "org-ql predicate selecting headings to export.
Default `(todo)' matches active TODO headings.  Use `(or (todo) (done))'
to include completed items."
  :type 'sexp
  :group 'dl-bough)

(defcustom dl-bough-auto-export nil
  "When non-nil, re-export org snapshot on save for in-scope files."
  :type 'boolean
  :group 'dl-bough)

;;; Internal helpers

(defun dl-bough--org-files ()
  "Return the list of org files to export."
  (or dl-bough-org-files
      (and (boundp 'my/org-agenda-combined-files)
           my/org-agenda-combined-files)
      (user-error "No org files configured — set `dl-bough-org-files' or load dl-org-agenda")))

(defun dl-bough--file-uri (path)
  "Return a file:// URI for PATH."
  (concat "file://" (expand-file-name path)))

(defun dl-bough--plist-compact (&rest pairs)
  "Build a plist from PAIRS, dropping keys whose value is nil."
  (let (result)
    (while pairs
      (let ((k (pop pairs))
            (v (pop pairs)))
        (when v
          (push k result)
          (push v result))))
    (nreverse result)))

(defun dl-bough--org-ts-to-iso (raw)
  "Parse org timestamp RAW to ISO date string \"YYYY-MM-DD\".
Returns nil if RAW is nil or unparseable."
  (when (and raw (string-match "\\([0-9]\\{4\\}\\)-\\([0-9]\\{2\\}\\)-\\([0-9]\\{2\\}\\)" raw))
    (match-string 0 raw)))

(defun dl-bough--org-heading-to-item ()
  "Convert the org heading at point to a Bough snapshot item plist.
Intended as the :action for `org-ql-select'.  Creates an org-id
if the heading lacks one."
  (let* ((id (or (org-entry-get nil "ID")
                 (org-id-get-create)))
         (title (org-get-heading t t t t))
         (todo (org-get-todo-state))
         (tags (org-get-tags nil t))
         (priority (org-entry-get nil "PRIORITY"))
         (scheduled (dl-bough--org-ts-to-iso (org-entry-get nil "SCHEDULED")))
         (deadline (dl-bough--org-ts-to-iso (org-entry-get nil "DEADLINE")))
         (file (buffer-file-name))
         (outline-path (org-get-outline-path t)))
    (dl-bough--plist-compact
     :provider "org"
     :scheme "org-id"
     :external_id id
     :title title
     :status todo
     :tags (when tags (vconcat tags))
     :scheduled_for scheduled
     :deadline deadline
     :locators (vector (list :kind "file" :value (dl-bough--file-uri file)))
     :metadata (dl-bough--plist-compact
                :todo todo
                :priority priority
                :outline_path (when outline-path (vconcat outline-path))))))

(defun dl-bough--denote-file-to-item (file)
  "Convert a denote FILE to a Bough snapshot item plist.
Returns nil if FILE has no denote identifier."
  (let* ((id (denote-retrieve-filename-identifier file))
         (title (or (denote-retrieve-filename-title file) ""))
         (keywords (denote-extract-keywords-from-path file)))
    (when (and id (not (string-empty-p id)))
      (dl-bough--plist-compact
       :provider "denote"
       :scheme "denote"
       :external_id id
       :title title
       :kind_hint "note"
       :tags (when keywords (vconcat keywords))
       :locators (vector (list :kind "file" :value (dl-bough--file-uri file)))
       :metadata (dl-bough--plist-compact
                  :denote_type (file-name-extension file))))))

(defun dl-bough--write-snapshot (snapshot path)
  "Serialize SNAPSHOT plist as JSON and write to PATH."
  (let ((dir (file-name-directory path)))
    (unless (file-directory-p dir)
      (make-directory dir t)))
  (with-temp-file path
    (insert (json-serialize snapshot))))

(defun dl-bough--file-in-scope-p (file)
  "Return non-nil if FILE is in the configured org export scope."
  (and file
       (member (expand-file-name file)
               (mapcar #'expand-file-name (dl-bough--org-files)))))

(defun dl-bough--import (snapshot-path provider)
  "Asynchronously import SNAPSHOT-PATH into Bough as PROVIDER."
  (let ((proc (start-process "bough-import" "*bough-import*"
                             dl-bough-program
                             "sync" "import"
                             "--from" (expand-file-name snapshot-path)
                             "--provider" provider)))
    (set-process-sentinel
     proc
     (lambda (p event)
       (when (string-match-p "finished" event)
         (with-current-buffer (process-buffer p)
           (message "Bough: %s" (string-trim (buffer-string)))))
       (when (string-match-p "exited abnormally" event)
         (message "Bough import failed — see *bough-import* buffer"))))))

;;; Interactive commands

(defun my/bough-export-org ()
  "Walk `dl-bough-org-files' and write one Bough snapshot JSON.
Selects headings matching `dl-bough-org-predicate' (default: active
TODO items) via org-ql.  Creates org-ids for headings that lack one.
Output: `dl-bough-org-snapshot-path' (~/.cache/bough/org-snapshot.json)."
  (interactive)
  (let* ((files (dl-bough--org-files))
         (items (org-ql-select files
                  dl-bough-org-predicate
                  :action #'dl-bough--org-heading-to-item))
         (snapshot (list :adapter "org"
                         :version 1
                         :generated_at (format-time-string "%FT%TZ" nil t)
                         :items (vconcat items))))
    (dl-bough--write-snapshot snapshot dl-bough-org-snapshot-path)
    (message "Bough: exported %d org items → %s" (length items) dl-bough-org-snapshot-path)))

(defun my/bough-export-denote ()
  "Walk `denote-directory-files' and write one Bough snapshot JSON.
Extracts denote identifiers, titles, and keywords from filenames.
All items get kind_hint \"note\".
Output: `dl-bough-denote-snapshot-path' (~/.cache/bough/denote-snapshot.json)."
  (interactive)
  (let* ((files (denote-directory-files))
         (items (delq nil (mapcar #'dl-bough--denote-file-to-item files)))
         (snapshot (list :adapter "denote"
                         :version 1
                         :generated_at (format-time-string "%FT%TZ" nil t)
                         :items (vconcat items))))
    (dl-bough--write-snapshot snapshot dl-bough-denote-snapshot-path)
    (message "Bough: exported %d denote items → %s" (length items) dl-bough-denote-snapshot-path)))

(defun my/bough-sync-org ()
  "Export org snapshot and import into Bough."
  (interactive)
  (my/bough-export-org)
  (dl-bough--import dl-bough-org-snapshot-path "org"))

(defun my/bough-sync-denote ()
  "Export denote snapshot and import into Bough."
  (interactive)
  (my/bough-export-denote)
  (dl-bough--import dl-bough-denote-snapshot-path "denote"))

;;; After-save hook

(defun dl-bough--maybe-export-on-save ()
  "Re-export org snapshot if saving an in-scope org file.
Active only when `dl-bough-auto-export' is non-nil."
  (when (and dl-bough-auto-export
             (derived-mode-p 'org-mode)
             (dl-bough--file-in-scope-p (buffer-file-name)))
    (my/bough-export-org)))

(add-hook 'after-save-hook #'dl-bough--maybe-export-on-save)

(provide 'dl-bough)
;;; dl-bough.el ends here
