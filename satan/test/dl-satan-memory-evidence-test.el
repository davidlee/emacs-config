;;; dl-satan-memory-evidence-test.el --- evidence assembler ert -*- lexical-binding: t; -*-

;; Tests for step 6 of memory.design.md.  Pure helpers exercised
;; directly; impure assembly exercised against tmp fixtures and the
;; canonicalizer (cross-step contract).
;;
;; Bough is silenced by pointing `dl-satan-bough-program' at a
;; non-existent path so the tool handler returns an `error' which
;; `dl-satan-memory-evidence--bough-call' swallows.

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-memory-evidence)
(require 'dl-satan-memory-canon)

(defun dl-satan-memory-evidence-test--with-tmp (body)
  (let ((tmp (make-temp-file "satan-ev-test-" t)))
    (unwind-protect (funcall body tmp)
      (delete-directory tmp t))))

(defmacro dl-satan-memory-evidence-test--in-tmp (var &rest body)
  (declare (indent 1))
  `(dl-satan-memory-evidence-test--with-tmp
    (lambda (,var)
      (let ((dl-satan-bough-program "/nonexistent/bough"))
        ,@body))))

;; ---------------------------------------------------------------------
;; Bounds
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-memory-evidence/bounds-no-run-started ()
  (let* ((b (dl-satan-memory-evidence--bounds
             "2026-05-19T10:00:00+10:00" nil)))
    (should (equal (cdr b) "2026-05-19T10:00:00+10:00"))
    (should (string-match-p "2026-05-19T09:50:00" (car b)))))

(ert-deftest dl-satan-memory-evidence/bounds-run-started-later-wins ()
  (let* ((b (dl-satan-memory-evidence--bounds
             "2026-05-19T10:00:00+10:00"
             "2026-05-19T09:55:00+10:00")))
    (should (equal (car b) "2026-05-19T09:55:00+10:00"))))

(ert-deftest dl-satan-memory-evidence/bounds-run-started-earlier-loses ()
  (let* ((b (dl-satan-memory-evidence--bounds
             "2026-05-19T10:00:00+10:00"
             "2026-05-19T09:00:00+10:00")))
    (should (string-match-p "2026-05-19T09:50:00" (car b)))))

;; ---------------------------------------------------------------------
;; Flatten
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-memory-evidence/flatten-nil ()
  (should (equal (dl-satan-memory-evidence--flatten-tree nil) '())))

(ert-deftest dl-satan-memory-evidence/flatten-nested ()
  (let* ((tree (list
                (list :nanoid "a"
                      :children
                      (list (list :nanoid "a1")
                            (list :nanoid "a2"
                                  :children (list (list :nanoid "a21")))))
                (list :nanoid "b")))
         (flat (dl-satan-memory-evidence--flatten-tree tree)))
    (should (equal (mapcar (lambda (n) (plist-get n :nanoid)) flat)
                   '("a" "a1" "a2" "a21" "b")))
    (should (cl-every (lambda (n) (null (plist-get n :children))) flat))))

;; ---------------------------------------------------------------------
;; Filter segments
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-memory-evidence/filter-segments-overlap ()
  (let* ((segs (list
                (list :start_ts "2026-05-19T09:40:00+10:00"
                      :end_ts   "2026-05-19T09:45:00+10:00")
                (list :start_ts "2026-05-19T09:55:00+10:00"
                      :end_ts   "2026-05-19T09:58:00+10:00")
                (list :start_ts "2026-05-19T10:05:00+10:00"
                      :end_ts   "2026-05-19T10:10:00+10:00")))
         (kept (dl-satan-memory-evidence--filter-segments
                segs
                "2026-05-19T09:50:00+10:00"
                "2026-05-19T10:00:00+10:00")))
    (should (= (length kept) 1))
    (should (equal (plist-get (car kept) :start_ts)
                   "2026-05-19T09:55:00+10:00"))))

(ert-deftest dl-satan-memory-evidence/filter-segments-empty ()
  (should (equal (dl-satan-memory-evidence--filter-segments
                  nil
                  "2026-05-19T09:50:00+10:00"
                  "2026-05-19T10:00:00+10:00")
                 nil)))

;; ---------------------------------------------------------------------
;; Truncation
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-memory-evidence/truncate-noop ()
  (let* ((ev (list :current_window (list :app_id "firefox")))
         (out (dl-satan-memory-evidence--truncate ev 4096 8192)))
    (should-not (plist-get out :truncated_at))))

(ert-deftest dl-satan-memory-evidence/truncate-drops-bough-day-bodies ()
  (let* ((big (apply #'concat (make-list 4000 "x")))
         (ev (list :current_window (list :app_id "firefox")
                   :bough_day (list :linked (list (list :nanoid "n1"))
                                    :body big)))
         (out (dl-satan-memory-evidence--truncate ev 1024 65536)))
    (should (member 'bough_day_bodies (plist-get out :truncated_at)))
    (should (plist-get (plist-get out :bough_day) :body_dropped))
    (should (equal (plist-get (plist-get out :bough_day) :linked)
                   (list (list :nanoid "n1"))))))

(ert-deftest dl-satan-memory-evidence/truncate-segments-middle ()
  (let* ((segs (cl-loop for i from 0 below 10
                        collect (list :idx i
                                      :payload
                                      (apply #'concat
                                             (make-list 200 "x")))))
         (ev (list :browser_segments segs))
         (out (dl-satan-memory-evidence--truncate ev 256 65536)))
    (should (member 'browser_segments_middle (plist-get out :truncated_at)))
    (let* ((kept (plist-get out :browser_segments))
           (sentinel (cl-find-if (lambda (s) (plist-get s :truncated)) kept)))
      (should sentinel)
      (should (= (plist-get sentinel :dropped) 4))
      (should (= (length kept) 7)))))

(ert-deftest dl-satan-memory-evidence/truncate-shrinks-bough-annotations ()
  (let* ((huge-ann (apply #'concat (make-list 500 "y")))
         (ev (list :bough_active
                   (list (list :nanoid "n1" :annotation huge-ann))))
         (out (dl-satan-memory-evidence--truncate ev 256 65536))
         (n1  (car (plist-get out :bough_active))))
    (should (member 'bough_active_annotation_bodies
                    (plist-get out :truncated_at)))
    (should (<= (length (plist-get n1 :annotation)) 260))
    (should (= 500 (plist-get n1 :annotation_len_original)))))

(ert-deftest dl-satan-memory-evidence/truncate-hard-cap-drops-bough-recent ()
  (let* ((huge (apply #'concat (make-list 200000 "x")))
         (ev (list :bough_recent (list (list :nanoid "n1" :note huge))))
         (out (dl-satan-memory-evidence--truncate ev 4096 8192)))
    (should (member 'bough_recent (plist-get out :truncated_at)))
    (should (null (plist-get out :bough_recent)))))

;; ---------------------------------------------------------------------
;; Assemble (impure; tmp fixtures + non-existent bough binary)
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-memory-evidence/assemble-shape-and-bounds ()
  (dl-satan-memory-evidence-test--in-tmp tmp
   (let* ((ctx (list :time_now "2026-05-19T10:00:00+10:00"
                     :mode_name "motd"))
          (out (dl-satan-memory-evidence-assemble
                ctx (list :behaviour_dir (file-name-as-directory tmp)
                          :cwd tmp))))
     (should (equal (plist-get out :window_end_at)
                    "2026-05-19T10:00:00+10:00"))
     (should (stringp (plist-get out :window_start_at)))
     (should (null (plist-get out :current_window)))
     (should (equal (plist-get out :focus_segments) '()))
     (should (equal (plist-get out :browser_segments) '()))
     (should (null (plist-get out :git_state)))
     (should (equal (plist-get (plist-get out :fs_state) :recent_files)
                    '())))))

(ert-deftest dl-satan-memory-evidence/assemble-cue-only-skips-heavy-probes ()
  "`:cue_only t' returns empty focus/browser segments and nil
bough_recent / bough_day even when those sources would otherwise
populate them.  Keeps current_window and bough_active."
  (dl-satan-memory-evidence-test--in-tmp tmp
   (let* ((current-dir (expand-file-name "current" tmp))
          (segments-dir (expand-file-name "segments" tmp)))
     (make-directory current-dir t)
     (make-directory segments-dir t)
     (with-temp-file (expand-file-name "sway.json" current-dir)
       (insert "{\"app_id\":\"firefox\",\"workspace\":\"main\"}"))
     (with-temp-file (expand-file-name "focus-2026-05-19.jsonl" segments-dir)
       (insert "{\"app_id\":\"firefox\",\"start_ts\":\"2026-05-19T09:55:00+10:00\",\"end_ts\":\"2026-05-19T09:58:00+10:00\",\"duration_s\":180}\n"))
     (cl-letf (((symbol-function 'dl-satan-memory-evidence--bough-recent)
                (lambda (&rest _) (error "should not be called"))))
       (cl-letf (((symbol-function 'dl-satan-memory-evidence--bough-day)
                  (lambda (&rest _) (error "should not be called"))))
         (let* ((ctx (list :time_now "2026-05-19T10:00:00+10:00"
                           :mode_name "motd"))
                (out (dl-satan-memory-evidence-assemble
                      ctx (list :behaviour_dir (file-name-as-directory tmp)
                                :cwd tmp
                                :cue_only t))))
           (should (equal (plist-get (plist-get out :current_window) :app_id)
                          "firefox"))
           (should (equal (plist-get out :focus_segments) '()))
           (should (equal (plist-get out :browser_segments) '()))
           (should (null (plist-get out :bough_recent)))
           (should (null (plist-get out :bough_day)))))))))

(ert-deftest dl-satan-memory-evidence/assemble-reads-panopticon ()
  (dl-satan-memory-evidence-test--in-tmp tmp
   (let* ((current-dir (expand-file-name "current" tmp))
          (segments-dir (expand-file-name "segments" tmp))
          (ctx (list :time_now "2026-05-19T10:00:00+10:00"
                     :mode_name "motd")))
     (make-directory current-dir t)
     (make-directory segments-dir t)
     (with-temp-file (expand-file-name "sway.json" current-dir)
       (insert "{\"app_id\":\"firefox\",\"workspace\":\"main\"}"))
     (with-temp-file (expand-file-name "focus-2026-05-19.jsonl" segments-dir)
       (insert "{\"app_id\":\"firefox\",\"start_ts\":\"2026-05-19T09:55:00+10:00\",\"end_ts\":\"2026-05-19T09:58:00+10:00\",\"duration_s\":180}\n")
       (insert "{\"app_id\":\"emacs\",\"start_ts\":\"2026-05-19T08:00:00+10:00\",\"end_ts\":\"2026-05-19T08:30:00+10:00\",\"duration_s\":1800}\n"))
     (let* ((out (dl-satan-memory-evidence-assemble
                  ctx (list :behaviour_dir (file-name-as-directory tmp)
                            :cwd tmp))))
       (should (equal (plist-get (plist-get out :current_window) :app_id)
                      "firefox"))
       ;; Only the in-window segment survives the filter.
       (should (= 1 (length (plist-get out :focus_segments))))
       (should (equal (plist-get (car (plist-get out :focus_segments))
                                 :app_id)
                      "firefox"))))))

(ert-deftest dl-satan-memory-evidence/assemble-git-state-on-repo ()
  ;; Initialize a tmp git repo so we don't depend on the host's layout
  ;; (the ambient ~/.emacs.d here is a bare-config worktree without a
  ;; nested .git/ directory).
  (skip-unless (executable-find "git"))
  (dl-satan-memory-evidence-test--in-tmp tmp
   (let ((default-directory (file-name-as-directory tmp)))
     (should (zerop (call-process "git" nil nil nil "init" "-q"
                                  "-b" "main")))
     (should (zerop (call-process "git" nil nil nil "config"
                                  "user.email" "t@example")))
     (should (zerop (call-process "git" nil nil nil "config"
                                  "user.name" "t")))
     (with-temp-file (expand-file-name "x" tmp) (insert "y"))
     (should (zerop (call-process "git" nil nil nil "add" "x")))
     (should (zerop (call-process "git" nil nil nil "commit" "-qm" "init")))
     (let* ((ctx (list :time_now "2026-05-19T10:00:00+10:00"
                       :mode_name "motd"))
            (out (dl-satan-memory-evidence-assemble
                  ctx (list :behaviour_dir "/nonexistent/"
                            :cwd tmp))))
       (let ((git (plist-get out :git_state)))
         (should git)
         (should (stringp (plist-get git :head_short)))
         (should (= 1 (length (plist-get git :commits)))))))))

;; ---------------------------------------------------------------------
;; Cross-step contract: canon eats assembler output.
;; ---------------------------------------------------------------------

(ert-deftest dl-satan-memory-evidence/canon-eats-output-minimal ()
  (dl-satan-memory-evidence-test--in-tmp tmp
   (let* ((current-dir (expand-file-name "current" tmp))
          (ctx (list :time_now "2026-05-19T10:00:00+10:00"
                     :mode_name "motd"
                     :current_grammar_version 1)))
     (make-directory current-dir t)
     (with-temp-file (expand-file-name "sway.json" current-dir)
       (insert "{\"app_id\":\"firefox\",\"workspace\":\"main\"}"))
     (let* ((ev (dl-satan-memory-evidence-assemble
                 ctx (list :behaviour_dir (file-name-as-directory tmp)
                           :cwd tmp)))
            (canon (dl-satan-memory-canon-canonicalize ev nil ctx))
            (handles (plist-get canon :handles)))
       (should (member "app:firefox" handles))
       (should (member "surface:browser" handles))
       (should (member "mode:motd" handles))
       (should (member "day:2026-05-19" handles))
       (should (member "week:2026-W21" handles))))))

(provide 'dl-satan-memory-evidence-test)
;;; dl-satan-memory-evidence-test.el ends here
