;;; dl-denote-blog.el --- Blog drafts as Denote notes -*- lexical-binding: t; -*-

;; New doctrine.engineering entries, reachable from the notes corpus.
;;
;; The blog owns its entries: `just new|link|snack' scaffolds one from
;; the blog's own skeletons, picks its slug and prints its path.  This
;; module runs that, then gives the entry a Denote identity by
;; symlinking it into `dl-notes-blog-dir' under a Denote file name:
;;
;;   ~/notes/blog/20261003T120000--a-title__article_blog.typ
;;     -> ~/dev/www/doctrine.engineering/.src/articles/a-title.typ
;;
;; One source of truth (the blog repo); the link is only an address.
;; `vc-follow-symlinks' is t so visiting a link edits the blog file in
;; the blog repo — magit, `just watch' and project commands all see
;; the blog.  Renaming an article in the blog leaves its link dangling;
;; Denote then skips it (`file-regular-p' is nil).

(require 'dl-notes-paths)
(require 'denote)

(defvar dl-denote-blog-root (expand-file-name "~/dev/www/doctrine.engineering")
  "Root of the blog repository; holds the justfile that scaffolds entries.")

(defconst dl-denote-blog-kinds
  '(("article" "new"   "Title")
    ("link"    "link"  "URL" "Title (optional)")
    ("snack"   "snack" "Words (optional)"))
  "Blog entry kinds as (KIND RECIPE PROMPT...).
RECIPE is the blog's `just' recipe; each PROMPT reads one of its
arguments.  The blog validates them, so no prompt here does.")

;; Typst entries open with YAML front matter, so reading is
;; `markdown-yaml''s.  Writing is not: Denote rewrites only components
;; its template names, and the blog build rejects a timestamp in
;; `date:' or a tag outside site.yml — so the template names `title'
;; alone.  Tags are the blog's, not Denote keywords; the inert key
;; keeps Denote from reading them as such.  The overrides come first
;; in the plist, and `plist-get' takes the first match.
(add-to-list 'denote-file-types
             `(typst ,@(append '(:extension ".typ"
                                 :get-file-type-function nil
                                 :front-matter "---\ntitle: %s\n---\n"
                                 :keywords-key-regexp "^denote-keywords\\s-*:")
                               (alist-get 'markdown-yaml denote-file-types))))

(setq vc-follow-symlinks t)

(defun dl-denote-blog--scaffold (recipe args)
  "Run the blog's `just RECIPE ARGS'; return the entry path it prints.
Runs under `direnv exec' so the blog's devshell (Ruby) is loaded.
Signal a `user-error' carrying the blog's message when it fails."
  (let ((root (file-name-as-directory dl-denote-blog-root))
        (stderr (make-temp-file "dl-denote-blog")))
    (unwind-protect
        (with-temp-buffer
          (if (eq 0 (apply #'call-process "direnv" nil (list t stderr) nil
                           "exec" root "just" "--justfile"
                           (expand-file-name "justfile" root) recipe args))
              (car (last (split-string (buffer-string) "\n" t)))
            ;; The blog's message, then just's own `error: recipe …' line.
            (erase-buffer)
            (insert-file-contents stderr)
            (user-error "Blog %s: %s" recipe
                        (string-join (last (split-string (buffer-string) "\n" t) 2)
                                     " — "))))
      (delete-file stderr))))

(defun dl-denote-blog--link (entry kind)
  "Symlink ENTRY into `dl-notes-blog-dir' under a Denote name; return it.
The title is ENTRY's own, keywords are `blog' and KIND."
  (let ((link (denote-format-file-name
               (file-name-as-directory dl-notes-blog-dir)
               (funcall denote-get-identifier-function nil nil)
               (denote-keywords-sort (list "blog" kind))
               (or (denote-retrieve-front-matter-title-value entry 'typst) "")
               ".typ" "")))
    (make-directory dl-notes-blog-dir t)
    (make-symbolic-link entry link)
    link))

(defun dl-denote-blog-new (kind &rest args)
  "Scaffold a blog entry of KIND from ARGS; return its Denote link."
  (let ((recipe (nth 1 (assoc kind dl-denote-blog-kinds))))
    (dl-denote-blog--link (dl-denote-blog--scaffold recipe args) kind)))

(defun my/denote-new-blog-entry (kind)
  "Scaffold a doctrine.engineering entry of KIND and visit it.
The entry is a draft in the blog repo; preview it with `just watch'."
  (interactive
   (list (completing-read "Blog entry kind: " dl-denote-blog-kinds nil t)))
  (find-file
   (apply #'dl-denote-blog-new kind
          (mapcar (lambda (prompt) (read-string (concat prompt ": ")))
                  (nthcdr 2 (assoc kind dl-denote-blog-kinds))))))

(provide 'dl-denote-blog)
;;; dl-denote-blog.el ends here
