default: home-switch

home-switch:
  cd ~/flakes && git add . && nix flake update panopticon emacs-config satan-patcher satan-attrd && just home-switch

used:
  @rg use-package -g '*.el' -I --trim | egrep -v '^;' | cut -d ' ' -f 2 | tr ')' ' ' | sort | uniq

# Run the ERT suite in the live Emacs server. DB-backed tests skip
# unless their test database (satan_memory_test, ...) is reachable.
check:
  @emacsclient --eval '(dl-test-run-suite)' | tee /dev/stderr | grep -q PASS

clean:
  @find ~/.emacs.d -name '*.elc' -delete

wc:
  @find ~/.emacs.d/{core,lisp,dev,lang,editing,completion,apps,org,satan} -name '*.el' | xargs wc -l ;

