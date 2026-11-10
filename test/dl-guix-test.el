;;; dl-guix-test.el --- ert tests for dl-guix -*- lexical-binding: t; -*-

;; Run: `just check' (dl-test scans test/), or M-x ert RET dl-guix RET.

(require 'ert)
(require 'cl-lib)
(require 'package)
(require 'package-vc)
(require 'use-package)
(require 'dl-guix)

(defmacro dl-guix-test--on-guix (guix-p &rest body)
  "Run BODY as if on Guix System when GUIX-P is non-nil."
  (declare (indent 1))
  `(cl-letf (((symbol-function 'dl-guix-system-p) (lambda () ,guix-p)))
     ,@body))

(ert-deftest dl-guix/ensure-is-off-on-guix ()
  "`:ensure' can't see Guix packages, so it must not try to install them."
  (let ((use-package-ensure-function 'use-package-ensure-elpa))
    (dl-guix-test--on-guix t (dl-guix-configure-packages))
    (should (eq use-package-ensure-function #'ignore))))

(ert-deftest dl-guix/ensure-is-untouched-elsewhere ()
  "Nix hosts keep their `:ensure' behaviour."
  (let ((use-package-ensure-function 'use-package-ensure-elpa))
    (dl-guix-test--on-guix nil (dl-guix-configure-packages))
    (should (eq use-package-ensure-function 'use-package-ensure-elpa))))

(ert-deftest dl-guix/install-refuses-off-guix ()
  "Nix owns the package set elsewhere, so nothing may download there."
  (dl-guix-test--on-guix nil
    (should-error (dl-guix-install-packages) :type 'user-error)))

(ert-deftest dl-guix/install-covers-archive-and-vc-packages ()
  "Every listed package is installed, from the archives or its repository."
  (let (installed vc-installed archives-during)
    (cl-letf (((symbol-function 'package-refresh-contents)
               (lambda (&rest _) (setq archives-during package-archives)))
              ((symbol-function 'package-install)
               (lambda (pkg &rest _) (push pkg installed)))
              ((symbol-function 'package-vc-install)
               (lambda (spec &rest _) (push (car spec) vc-installed)))
              ((symbol-function 'package-installed-p) #'ignore))
      (dl-guix-test--on-guix t (dl-guix-install-packages)))
    (should archives-during)
    (should (equal (sort installed #'string<)
                   (sort (copy-sequence dl-guix-archive-packages) #'string<)))
    (should (equal (sort vc-installed #'string<)
                   (sort (mapcar #'car dl-guix-vc-packages) #'string<)))))

(ert-deftest dl-guix/install-leaves-archives-off-afterwards ()
  "Runtime `package-archives' stays nil: Emacs itself never downloads."
  (let ((package-archives nil))
    (cl-letf (((symbol-function 'package-refresh-contents) #'ignore)
              ((symbol-function 'package-install) #'ignore)
              ((symbol-function 'package-vc-install) #'ignore)
              ((symbol-function 'package-installed-p) #'ignore))
      (dl-guix-test--on-guix t (dl-guix-install-packages)))
    (should-not package-archives)))

(ert-deftest dl-guix/install-skips-installed-vc-packages ()
  "Re-running must not re-clone, which would prompt to overwrite a checkout."
  (let (vc-installed)
    (cl-letf (((symbol-function 'package-refresh-contents) #'ignore)
              ((symbol-function 'package-install) #'ignore)
              ((symbol-function 'package-vc-install)
               (lambda (spec &rest _) (push (car spec) vc-installed)))
              ((symbol-function 'package-installed-p) (lambda (&rest _) t)))
      (dl-guix-test--on-guix t (dl-guix-install-packages)))
    (should-not vc-installed)))

(provide 'dl-guix-test)
;;; dl-guix-test.el ends here
