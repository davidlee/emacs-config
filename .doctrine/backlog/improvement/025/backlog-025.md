# IMP-025: Export a dev-tools closure for the microvm capsule

<!-- Backlog item body — context, detail, links. The structured, queried fields
     live in the sister `backlog-NNN.toml`; this prose is free-form and is never
     structurally parsed (the storage rule). -->

Raised 2026-10-16. Export the devshell tool set as one closure, so the
oubliette microvm capsule can take this repo as a target (`toolsPackage =
"dev-tools"` in oubliette `targets/<name>.nix`; contract:
oubliette `docs/contract-target.md`).

## Shape (as doctrine, satan, panopticon)

```
devToolPkgs  (tools only — no jailed or unjailed agent CLIs)
   ├─▶ devshell / jails:  projectPkgs = devToolPkgs ++ agents
   └─▶ packages.dev-tools = pkgs.buildEnv { name = "<repo>-dev-tools";
                                            paths = devToolPkgs;
                                            ignoreCollisions = true; }
```

Agents stay out: the capsule supplies them, and a bwrap wrapper binding host
paths is meaningless in a VM. Reference: satan `flake.nix` (satan IMP-036).

## Repo-specific
- `projectPkgs` mixes agents in three ways: `jailLib.unjailed.codex`,
  `jailLib.unjailed.claude`, and the Linux-only `jailLib.agentsByName.{claude,pi}`.
  All four leave `devToolPkgs`.
- Its tool list near-duplicates satan's (zig, nodejs, just, postgresql_18,
  supabase-cli, wrappedEmacs, emacsclient-commands, sqlite, socat, bun, doctrine).
  Since SL-012 (satan extraction), check what this repo still needs: postgres/
  supabase are likely satan leftovers. Keep helix and gdb.
- `baseline` for a capsule target would be `just check`; `db-start`/`db-stop`
  are host supabase recipes the guest can't use.

## Done when

`nix build .#dev-tools` succeeds; the devshell still evaluates; anything the
devshell was borrowing from the host (python3, rg, …) is added to the list.
