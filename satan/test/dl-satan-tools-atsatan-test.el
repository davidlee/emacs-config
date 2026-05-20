;;; dl-satan-tools-atsatan-test.el --- @satan scan/done tool tests -*- lexical-binding: t; -*-

;; Run from CLI:
;;   emacs --batch \
;;     -L ~/.emacs.d/core -L ~/.emacs.d/satan -L ~/.emacs.d/satan/test \
;;     -l ert -l dl-satan-tools-atsatan-test \
;;     --eval '(ert-run-tests-batch-and-exit "notes-at-satan-")'

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-tools-atsatan)

(defmacro dl-satan-tools-atsatan-test--with-root (root-sym &rest body)
  "Bind ROOT-SYM to a fresh temp dir, let-bind it as the scan root, cleanup on exit."
  (declare (indent 1))
  `(let* ((,root-sym (make-temp-file "satan-atsatan-test-" 'dir))
          (dl-satan-tools-atsatan-root ,root-sym))
     (unwind-protect (progn ,@body)
       (delete-directory ,root-sym 'recursive))))

(ert-deftest notes-at-satan/scan-then-done-then-rescan ()
  "Full round-trip: scan finds a match, done claims it, rescan excludes it."
  (dl-satan-tools-atsatan-test--with-root root
    (let* ((file (expand-file-name "trip.org" root))
           (ctx  (list :id "TEST-RUN" :capabilities '(write-notes))))
      ;; Seed file.
      (let ((coding-system-for-write 'utf-8))
        (write-region "* H\nfirst line\n- @satan summarise me\nlast line\n"
                      nil file))
      ;; Scan: one match.
      (let* ((res (dl-satan-tool/notes-at-satan-scan nil ctx)))
        (should (eq (car res) 'ok))
        (let* ((payload (cdr res))
               (matches (plist-get payload :matches))
               (m       (car matches))
               (id      (plist-get m :id)))
          (should (= 1 (length matches)))
          (should (string-match-p "summarise me" (plist-get m :content)))
          (should (equal "* H" (plist-get m :headline)))
          ;; Done: claim it.
          (let ((done (dl-satan-tool/notes-at-satan-done
                       (list :match-id id :comment "ok")
                       ctx)))
            (should (eq (car done) 'ok))
            (should (equal "done" (plist-get (cdr done) :status))))
          ;; File now bears @satan-done with the run-id.
          (with-temp-buffer
            (insert-file-contents file)
            (should (string-match-p "@satan-done(TEST-RUN,ok)"
                                    (buffer-string))))
          ;; Idempotent: second done is a no-op.
          (let ((done2 (dl-satan-tool/notes-at-satan-done
                        (list :match-id id) ctx)))
            (should (equal "already-done"
                           (plist-get (cdr done2) :status))))
          ;; Rescan: no matches.
          (let ((rescan (dl-satan-tool/notes-at-satan-scan nil ctx)))
            (should (eq (car rescan) 'ok))
            (should (zerop (plist-get (cdr rescan) :count)))))))))

(ert-deftest notes-at-satan-scan/excludes-satan-dir ()
  "Files under <root>/satan/ are excluded by the !satan/** glob."
  (dl-satan-tools-atsatan-test--with-root root
    (let* ((subdir (expand-file-name "satan" root))
           (file   (expand-file-name "x.org" subdir))
           (ctx    (list :id "TEST-RUN" :capabilities '(write-notes))))
      (make-directory subdir t)
      (let ((coding-system-for-write 'utf-8))
        (write-region "@satan x\n" nil file))
      (let ((res (dl-satan-tool/notes-at-satan-scan nil ctx)))
        (should (eq (car res) 'ok))
        (should (zerop (plist-get (cdr res) :count)))))))

(ert-deftest notes-at-satan-scan/markdown-headline ()
  "Markdown `## H' headings are returned in :headline."
  (dl-satan-tools-atsatan-test--with-root root
    (let* ((file (expand-file-name "foo.md" root))
           (ctx  (list :id "TEST-RUN" :capabilities '(write-notes))))
      (let ((coding-system-for-write 'utf-8))
        (write-region "## Onboarding\n@satan x\n" nil file))
      (let* ((res (dl-satan-tool/notes-at-satan-scan nil ctx))
             (m   (car (plist-get (cdr res) :matches))))
        (should (eq (car res) 'ok))
        (should (equal "## Onboarding" (plist-get m :headline)))))))

(ert-deftest notes-at-satan-scan/context-window ()
  "Context window of ±2 around the match line spans lines 3-7 of a 10-line file."
  (dl-satan-tools-atsatan-test--with-root root
    (let* ((file (expand-file-name "ctx.org" root))
           (ctx  (list :id "TEST-RUN" :capabilities '(write-notes)))
           (body (concat "l1\nl2\nl3\nl4\n@satan here\nl6\nl7\nl8\nl9\nl10\n")))
      (let ((coding-system-for-write 'utf-8))
        (write-region body nil file))
      (let* ((res (dl-satan-tool/notes-at-satan-scan
                   (list :context-lines 2) ctx))
             (m   (car (plist-get (cdr res) :matches)))
             (window (plist-get m :context)))
        (should (eq (car res) 'ok))
        (should (equal "l3\nl4\n@satan here\nl6\nl7" window))))))

(ert-deftest notes-at-satan-done/refuses-without-capability ()
  "Done refuses when ctx :capabilities lacks 'write-notes."
  (dl-satan-tools-atsatan-test--with-root root
    (let* ((file (expand-file-name "trip.org" root))
           (scan-ctx (list :id "TEST-RUN" :capabilities '(write-notes)))
           (no-cap-ctx (list :id "TEST-RUN" :capabilities '())))
      (let ((coding-system-for-write 'utf-8))
        (write-region "@satan x\n" nil file))
      (let* ((res (dl-satan-tool/notes-at-satan-scan nil scan-ctx))
             (id  (plist-get (car (plist-get (cdr res) :matches)) :id))
             (done (dl-satan-tool/notes-at-satan-done
                    (list :match-id id) no-cap-ctx)))
        (should (eq (car done) 'error))
        (should (string-match-p "capability" (cdr done)))))))

(provide 'dl-satan-tools-atsatan-test)
;;; dl-satan-tools-atsatan-test.el ends here
