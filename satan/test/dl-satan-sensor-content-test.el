;;; dl-satan-sensor-content-test.el --- ert tests for dl-satan-sensor-content -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'dl-satan-attribute)           ; load before tests (defcustoms)
(require 'dl-satan-tools-content)
(require 'dl-satan-tools-content-test nil t) ; fixture macros
(require 'dl-satan-sensor-content)

;; --- Helpers ---------------------------------------------------

(defmacro dl-satan-sensor-content-test--with-temp-state (state-var &rest body)
  "Bind STATE-VAR to a temp file path for sensor-content state during BODY."
  (declare (indent 1))
  `(let ((,state-var (make-temp-file "satan-sensor-content-state-")))
     (unwind-protect
         (progn ,@body)
       (ignore-errors (delete-file ,state-var)))))

(defun dl-satan-sensor-content-test--read-state (path)
  "Read sensor-content state JSON at PATH, return plist or nil."
  (when (file-readable-p path)
    (with-temp-buffer
      (insert-file-contents path)
      (json-parse-buffer :object-type 'plist))))

(defun dl-satan-sensor-content-test--write-state (path plist)
  "Write PLIST as JSON to PATH."
  (with-temp-file path
    (insert (json-serialize plist :null-object :null :false-object :false))))

(defun dl-satan-sensor-content-test--seed-state (path watermark)
  "Write a state file at PATH with :last_inspected WATERMARK."
  (dl-satan-sensor-content-test--write-state path (list :last_inspected watermark)))

;; --- Tests -----------------------------------------------------

(ert-deftest dl-satan-sensor-content/backlog-detected-emits-and-advances ()
  "When captures exist newer than the watermark, probe emits and advances watermark."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      (let ((article1 (dl-satan-tools-content-test--article-plist
                       "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                       "https://example.com/1" "example.com"
                       "Article One" "2026-05-31T05:00:00.000Z"))
            (article2 (dl-satan-tools-content-test--article-plist
                       "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5"
                       "https://example.com/2" "example.com"
                       "Article Two" "2026-05-31T05:25:45.968Z"))
            (article3 (dl-satan-tools-content-test--article-plist
                       "c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6"
                       "https://other.example/3" "other.example"
                       "Article Three" "2026-05-31T06:00:00.000Z")))
        (dl-satan-tools-content-test--write-article-jsonl
         (list article1 article2 article3))
        (dl-satan-sensor-content-test--seed-state
         state-path "2026-05-31T05:00:00.000Z")
        (let ((dl-satan-sensor-content-state-file state-path)
              (dl-satan-sensor-content-enabled t))
          (let ((result (dl-satan-sensor-content-probe
                         :run-id "test-run-1"
                         :ts "2026-05-31T06:30:00+10:00")))
            ;; Should emit (2 captures after the seed watermark)
            (should result)
            ;; Watermark must advance to max captured_at (article3), NOT the ts
            (let ((state (dl-satan-sensor-content-test--read-state state-path)))
              (should (equal "2026-05-31T06:00:00.000Z"
                             (plist-get state :last_inspected))))))))))

(ert-deftest dl-satan-sensor-content/no-backlog-no-emit ()
  "When all captures are ≤ watermark, probe returns nil and watermark unchanged."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      (let ((article1 (dl-satan-tools-content-test--article-plist
                       "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                       "https://example.com/1" "example.com"
                       "Article One" "2026-05-31T05:00:00.000Z")))
        (dl-satan-tools-content-test--write-article-jsonl (list article1))
        ;; Watermark already ahead of all captures
        (dl-satan-sensor-content-test--seed-state
         state-path "2026-05-31T06:00:00.000Z")
        (let ((dl-satan-sensor-content-state-file state-path)
              (dl-satan-sensor-content-enabled t))
          (let ((result (dl-satan-sensor-content-probe
                         :run-id "test-run-2"
                         :ts "2026-05-31T06:30:00+10:00")))
            (should-not result)
            ;; Watermark unchanged
            (let ((state (dl-satan-sensor-content-test--read-state state-path)))
              (should (equal "2026-05-31T06:00:00.000Z"
                             (plist-get state :last_inspected))))))))))

(ert-deftest dl-satan-sensor-content/dec5-watermark-is-captured-at-not-ts ()
  "DEC-5: watermark is max captured_at string verbatim, NOT broker's formatted ts."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      (let ((article (dl-satan-tools-content-test--article-plist
                      "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                      "https://example.com/1" "example.com"
                      "Article One" "2026-05-31T05:25:45.968Z")))
        (dl-satan-tools-content-test--write-article-jsonl (list article))
        (dl-satan-sensor-content-test--seed-state state-path "")
        (let ((dl-satan-sensor-content-state-file state-path)
              (dl-satan-sensor-content-enabled t))
          (dl-satan-sensor-content-probe
           :run-id "test-dec5"
           :ts "2026-05-31T15:30:00+10:00") ; broker ts — DIFFERENT format
          (let ((wm (plist-get (dl-satan-sensor-content-test--read-state state-path)
                               :last_inspected)))
            ;; DEC-5: watermark MUST be the captured_at string, NOT the broker ts
            (should (equal "2026-05-31T05:25:45.968Z" wm))
            ;; DEC-5: watermark must NOT be the broker ts
            (should-not (equal "2026-05-31T15:30:00+10:00" wm))))))))

(ert-deftest dl-satan-sensor-content/disabled-returns-nil ()
  "When dl-satan-sensor-content-enabled is nil, probe returns nil without emit."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      (let ((article (dl-satan-tools-content-test--article-plist
                      "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                      "https://example.com/1" "example.com"
                      "Article One" "2026-05-31T05:25:45.968Z")))
        (dl-satan-tools-content-test--write-article-jsonl (list article))
        (dl-satan-sensor-content-test--seed-state state-path "")
        (let ((dl-satan-sensor-content-state-file state-path)
              (dl-satan-sensor-content-enabled nil)) ; DISABLED
          (let ((result (dl-satan-sensor-content-probe
                         :run-id "test-disabled"
                         :ts "2026-05-31T06:30:00+10:00")))
            (should-not result)
            ;; Watermark must NOT advance when disabled
            (let ((wm (plist-get (dl-satan-sensor-content-test--read-state state-path)
                                 :last_inspected)))
              (should (equal "" wm)))))))))

(ert-deftest dl-satan-sensor-content/empty-store-no-crash ()
  "Empty articles.jsonl → no emit, no crash."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      ;; No articles.jsonl written — empty store
      (dl-satan-sensor-content-test--seed-state state-path "")
      (let ((dl-satan-sensor-content-state-file state-path)
            (dl-satan-sensor-content-enabled t))
        (let ((result (dl-satan-sensor-content-probe
                       :run-id "test-empty"
                       :ts "2026-05-31T06:30:00+10:00")))
          (should-not result))))))

(ert-deftest dl-satan-sensor-content/malformed-line-skipped ()
  "Malformed jsonl lines are skipped (O-1), valid lines still counted."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      ;; Write articles.jsonl manually with a malformed line between valid ones
      (let ((path (expand-file-name "articles.jsonl"
                                    dl-satan-tools-content-test--dir)))
        (with-temp-file path
          (insert (json-serialize
                   (dl-satan-tools-content-test--article-plist
                    "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                    "https://example.com/1" "example.com"
                    "Article One" "2026-05-31T05:00:00.000Z")))
          (insert "\n")
          ;; Malformed line (half-written by concurrent append)
          (insert "{broken json\n")
          (insert (json-serialize
                   (dl-satan-tools-content-test--article-plist
                    "b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5"
                    "https://example.com/2" "example.com"
                    "Article Two" "2026-05-31T05:25:45.968Z")))
          (insert "\n")))
      (dl-satan-sensor-content-test--seed-state state-path "")
      (let ((dl-satan-sensor-content-state-file state-path)
            (dl-satan-sensor-content-enabled t))
        (let ((result (dl-satan-sensor-content-probe
                       :run-id "test-malformed"
                       :ts "2026-05-31T06:30:00+10:00")))
          ;; Should emit — 2 valid captures uninspected
          (should result)
          (let ((state (dl-satan-sensor-content-test--read-state state-path)))
            ;; Watermark should be the max captured_at of valid lines
            (should (equal "2026-05-31T05:25:45.968Z"
                           (plist-get state :last_inspected)))))))))

(ert-deftest dl-satan-sensor-content/initial-watermark-empty-string ()
  "Initial watermark is empty string, which sorts before all timestamps."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      (let ((article (dl-satan-tools-content-test--article-plist
                      "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                      "https://example.com/1" "example.com"
                      "Article One" "2026-05-31T05:25:45.968Z")))
        (dl-satan-tools-content-test--write-article-jsonl (list article))
        ;; No seed — probe reads empty state file (or non-existent) → watermark ""
        (let ((dl-satan-sensor-content-state-file state-path)
              (dl-satan-sensor-content-enabled t))
          (let ((result (dl-satan-sensor-content-probe
                         :run-id "test-initial"
                         :ts "2026-05-31T06:30:00+10:00")))
            ;; With empty watermark, every capture is uninspected
            (should result)
            (should (equal "2026-05-31T05:25:45.968Z"
                           (plist-get
                            (dl-satan-sensor-content-test--read-state state-path)
                            :last_inspected)))))))))

(ert-deftest dl-satan-sensor-content/no-run-id-guards ()
  "When run-id is nil, probe returns nil (guarded same as curiosity)."
  (dl-satan-sensor-content-test--with-temp-state state-path
    (dl-satan-tools-content-test--with-store
      (let ((article (dl-satan-tools-content-test--article-plist
                      "a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4"
                      "https://example.com/1" "example.com"
                      "Article One" "2026-05-31T05:25:45.968Z")))
        (dl-satan-tools-content-test--write-article-jsonl (list article))
        (dl-satan-sensor-content-test--seed-state state-path "")
        (let ((dl-satan-sensor-content-state-file state-path)
              (dl-satan-sensor-content-enabled t))
          (let ((result (dl-satan-sensor-content-probe
                         :run-id nil    ; no run-id
                         :ts "2026-05-31T06:30:00+10:00")))
            (should-not result)))))))

(provide 'dl-satan-sensor-content-test)
;;; dl-satan-sensor-content-test.el ends here
