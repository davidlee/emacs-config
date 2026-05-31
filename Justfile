export SATAN_DB_HOST := "127.0.0.1"
export PGHOST := "127.0.0.1"
export PGPORT := "54322"
export PGUSER := "postgres"
export PGPASSWORD := "postgres"

default: home-switch

home-switch:
  cd ~/flakes && git add . && nix flake update pub panopticon emacs-config satan-patcher satan-attrd && just home-switch

used:
  @rg use-package -g '*.el' -I --trim | egrep -v '^;' | cut -d ' ' -f 2 | tr ')' ' ' | sort | uniq

# Run the full ERT suite in batch mode (the default).
# SATAN_DB_HOST redirects DB tests to the test DB; without it the
# chokepoint guard refuses the production socket loudly.
check:
  @emacs --batch -Q --init-directory="{{justfile_directory()}}" \
    -L core -L lisp -L org -L editing -L completion -L apps -L lang -L dev -L satan -L satan/test -L lisp/test \
    -l dev/dl-test.el \
    --eval '(princ (dl-test-run-suite))' 2>&1 | tee /dev/stderr | grep -q PASS

db-start:
  supabase start

db-stop:
  supabase stop

db-status:
  supabase status

db-init db="satan_memory_test":
  #!/usr/bin/env bash
  set -euo pipefail
  cd "{{justfile_directory()}}"
  dropdb --if-exists --maintenance-db=postgres "{{db}}"
  createdb --maintenance-db=postgres "{{db}}"
  emacs --batch -Q --init-directory="{{justfile_directory()}}" \
    -L satan \
    -l satan/dl-satan-memory-migrate.el \
    --eval '(let ((dl-satan-memory-migrate-host (or (getenv "SATAN_DB_HOST") "127.0.0.1"))) (dl-satan-memory-migrate-apply "{{db}}"))'

# Run the ERT suite in the live Emacs server, redirecting DB tests to
# the test DB via a let-binding on dl-satan-db-host-override.
# The redirect lasts only the suite's dynamic extent; the live
# broker's production connection is untouched.
check-interactive:
  @emacsclient --eval '(let ((dl-satan-db-host-override (or (getenv "SATAN_DB_HOST") "127.0.0.1"))) (dl-test-run-suite))' | tee /dev/stderr | grep -q PASS

clean:
  @find ~/.emacs.d -name '*.elc' -delete

wc:
  @find ~/.emacs.d/{core,lisp,dev,lang,editing,completion,apps,org,satan} -name '*.el' | xargs wc -l ;

hello-satan:
  emacsclient -e "(my/hello-satan)"
  jpi -e .pi/extensions/satan.ts

