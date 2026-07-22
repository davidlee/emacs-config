export SATAN_DB_HOST := "127.0.0.1"
export PGHOST := "127.0.0.1"
export PGPORT := "54322"
export PGUSER := "postgres"
export PGPASSWORD := "postgres"

default: home-switch

home-switch:
  cd ~/flakes && git add . && nix flake update pub panopticon emacs-config satan-patcher satan-attrd && just home-switch
  @cd ~/.emacs.d && just clean-eln

used:
  @rg use-package -g '*.el' -I --trim | egrep -v '^;' | cut -d ' ' -f 2 | tr ')' ' ' | sort | uniq

# Run the full ERT suite in batch mode (the default).
# SATAN_DB_HOST redirects DB tests to the test DB; without it the
# chokepoint guard refuses the production socket loudly.
check:
  @emacs --batch -Q --init-directory="{{justfile_directory()}}" \
    -L core -L lisp -L org -L editing -L completion -L apps -L lang -L dev -L lisp/test -L ~/dev/satan/satan \
    -l dev/dl-test.el \
    --eval '(princ (dl-test-run-suite))' 2>&1 | tee /dev/stderr | grep -q PASS

db-start:
  supabase start

db-stop:
  supabase stop

db-status:
  supabase status

clean: clean-eln
  @find ~/.emacs.d -name '*.elc' -delete

# `home-manager switch` mints a new ABI gen dir per emacs rebuild and never
# removes the old ones; executing a mismatched/stale .eln SIGSEGVs the editor
# (jump-to-garbage). Keep the interactive emacs's current gen plus anything
# touched in the last week (protects a recently-used devshell gen); drop the
# rest. Safe: eln-cache is fully regenerable — a purged gen recompiles on demand.
# Purge stale native-comp (.eln) generations from the user cache.
clean-eln:
  #!/usr/bin/env bash
  set -uo pipefail
  cache="$HOME/.emacs.d/eln-cache"
  [ -d "$cache" ] || exit 0
  live=$(timeout 30 "$HOME/.nix-profile/bin/emacs" -Q --batch \
           --eval '(princ comp-native-version-dir)' 2>/dev/null || true)
  for d in "$cache"/*/; do
    n=$(basename "$d")
    if [ "$n" = "$live" ] || [ -n "$(find "$d" -maxdepth 1 -mtime -7 -print -quit 2>/dev/null)" ]; then
      echo "keep  $n"
    else
      echo "purge $n"; rm -rf "$d"
    fi
  done

wc:
  @find ~/.emacs.d/{core,lisp,dev,lang,editing,completion,apps,org} -name '*.el' | xargs wc -l ;

hello-satan:
  emacsclient -e "(my/hello-satan)"
  cd ~/notes && jpi -e .pi/extensions/satan.ts

