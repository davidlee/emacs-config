;;; dl-blog.el --- blog stuff -*- lexical-binding: t; -*-

(require 'ox-publish)

(setq org-publish-project-alist
  '(("blog-posts"
      :base-directory "~/notes/"
      :base-extension "org"
      :publishing-directory "~/dev/www/blog"
      :recursive t
      :publishing-function org-html-publish-to-html

      :html-doctype "html5"
      :html-html5-fancy t
      :html-head-include-default-style nil
      :html-head-include-scripts nil
      :html-head "<link rel=\"stylesheet\" href=\"/style.css\">"

      :with-author nil
      :with-creator nil
      :with-toc nil
      :section-numbers nil
      :time-stamp-file nil)

     ("blog-static"
       :base-directory "~/"
       :base-extension "css\\|js\\|png\\|jpg\\|svg\\|woff2"
       :publishing-directory "~/dev/www/blogn"
       :recursive t
       :publishing-function org-publish-attachment)

     ("blog"
       :components ("blog-posts" "blog-static"))))

(provide 'dl-blog)
;;; dl-blog.el ends here
