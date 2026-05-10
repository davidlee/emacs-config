;;; dl-package.el --- package manager -*- lexical-binding: t; -*-

(setopt package-enable-at-startup nil
	use-package-always-ensure t)

(require 'package)

(add-to-list 'package-archives
	     '("gnu"    . "https://elpa.gnu.org/packages/") t)
(add-to-list 'package-archives
	     '("nongnu" . "https://elpa.nongnu.org/packages/") t)
(add-to-list 'package-archives
	     '("melpa"  . "https://melpa.org/packages/") t)

(package-initialize)

(unless package-archive-contents
  (package-refresh-contents))

(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(require 'use-package)

(provide 'dl-package-loader)
