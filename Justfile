default: home-switch

home-switch:
  cd ~/flakes && git add ~/.emacs.d . && just home-switch

used:
  @rg use-package -g '*.el' -I --trim | egrep -v '^;' | cut -d ' ' -f 2 | tr ')' ' ' | sort | uniq

clean:
  @find ~/.emacs.d -name '*.elc' -delete
