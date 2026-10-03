;;; dl-denote-blog-test.el --- ert tests for dl-denote-blog -*- lexical-binding: t; -*-

;; Each test builds a throwaway blog (a justfile standing in for
;; doctrine.engineering's scaffolder) and a throwaway denote directory,
;; so nothing touches ~/notes or the real blog.

(require 'ert)
(require 'dl-denote-blog)

(defconst dl-denote-blog-test--justfile
  "new title:
  @printf -- '---\\ntitle: %s\\ndate: 2026-10-03\\ntags: [ai]\\ndraft: true\\n---\\nbody\\n' {{ quote(title) }} > entry.typ
  @echo \"$PWD/entry.typ\"

snack words=\"\":
  @printf -- '---\\nkind: snack\\ndate: 2026-10-03\\ntags: []\\n---\\nbody\\n' > snack.typ
  @echo \"$PWD/snack.typ\"

link url title=\"\":
  @echo 'that slug is taken' >&2
  @exit 1
"
  "Stands in for the blog's justfile: `new' and `snack' scaffold, `link' fails.")

(defmacro dl-denote-blog-test--with-blog (&rest body)
  "Run BODY with a fake blog root and an empty denote directory."
  (declare (indent 0) (debug t))
  `(let* ((dl-denote-blog-root (make-temp-file "blog" t))
          (denote-directory (file-name-as-directory (make-temp-file "notes" t)))
          (dl-notes-blog-dir (expand-file-name "blog" denote-directory)))
     (skip-unless (and (executable-find "direnv") (executable-find "just")))
     (with-temp-file (expand-file-name "justfile" dl-denote-blog-root)
       (insert dl-denote-blog-test--justfile))
     (unwind-protect (progn ,@body)
       (delete-directory dl-denote-blog-root t)
       (delete-directory denote-directory t))))

(ert-deftest dl-denote-blog/links-entry-under-denote-name ()
  (dl-denote-blog-test--with-blog
    (let ((link (dl-denote-blog-new "article" "A Test Post")))
      (should (equal (file-truename link)
                     (file-truename (expand-file-name "entry.typ" dl-denote-blog-root))))
      (should (equal (file-name-directory link)
                     (file-name-as-directory dl-notes-blog-dir)))
      (should (string-match-p "--a-test-post__article_blog\\.typ\\'" link))
      (should (member link (denote-directory-files))))))

(ert-deftest dl-denote-blog/untitled-entry-gets-untitled-link ()
  (dl-denote-blog-test--with-blog
    (let ((link (dl-denote-blog-new "snack" "")))
      (should (string-match-p "/[0-9T]+__blog_snack\\.typ\\'" link)))))

(ert-deftest dl-denote-blog/scaffold-failure-reports-blog-message ()
  (dl-denote-blog-test--with-blog
    (let ((err (should-error (dl-denote-blog-new "link" "https://x.test/" "")
                             :type 'user-error)))
      (should (string-match-p "that slug is taken" (cadr err)))
      (should-not (file-exists-p dl-notes-blog-dir)))))

(ert-deftest dl-denote-blog/denote-reads-title-not-blog-tags ()
  (dl-denote-blog-test--with-blog
    (let ((link (dl-denote-blog-new "article" "A Test Post")))
      (should (eq (denote-filetype-heuristics link) 'typst))
      (should (equal (denote-retrieve-front-matter-title-value link 'typst)
                     "A Test Post"))
      (should-not (denote-retrieve-front-matter-keywords-value link 'typst)))))

(ert-deftest dl-denote-blog/rename-rewrites-title-only ()
  ;; The blog build rejects a timestamp in `date:' and any word in
  ;; `tags:' outside site.yml's vocabulary.
  (dl-denote-blog-test--with-blog
    (let* ((link (dl-denote-blog-new "article" "A Test Post"))
           (entry (file-truename link))
           (denote-rename-confirmations nil)
           (denote-save-buffers t))
      (denote-rename-file link "Retitled" '("article" "blog" "extra") ""
                          (current-time) (denote-retrieve-filename-identifier link))
      (let ((source (with-temp-buffer (insert-file-contents entry) (buffer-string))))
        (should (string-match-p "^title: +\"?Retitled\"?$" source))
        (should (string-match-p "^date: 2026-10-03$" source))
        (should (string-match-p "^tags: \\[ai\\]$" source)))
      (let ((renamed (denote-directory-files)))
        (should (= (length renamed) 1))
        (should (string-match-p "--retitled__article_blog_extra\\.typ\\'" (car renamed)))
        (should (equal (file-truename (car renamed)) entry))))))

(provide 'dl-denote-blog-test)
;;; dl-denote-blog-test.el ends here
