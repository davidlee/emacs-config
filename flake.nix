{
  description = "flake for doing emacs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devshell.url = "github:numtide/devshell";
    pub.url = "path:/home/david/flakes/pub";
    llm-agents.url = "github:numtide/llm-agents.nix";
    # spec-driver.url = "github:davidlee/spec-driver";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = inputs @ {
    flake-parts,
    zig-overlay,
    ...
  }:
    flake-parts.lib.mkFlake {inherit inputs;} {
      imports = [
        inputs.devshell.flakeModule
      ];

      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];

      perSystem = {
        pkgs,
        system,
        ...
      }: let
        inherit (pkgs) lib stdenv;
        isLinux = stdenv.isLinux;
        zigPackage = zig-overlay.packages.${system}."default";

        jailLib =
          if isLinux
          then inputs.pub.lib.${system}.mkJailedAgents {inherit (inputs) llm-agents;}
          else {};

        projectPkgs = with pkgs; [
          zigPackage
        ];

        jailEnvOptions = with jailLib.combinators; [
          (try-fwd-env "OPENROUTER_API_KEY")
        ];

        # workspaceDeps = [ "/home/david/.emacs.d/" ];
        # workspaceDeps = [ "/home/david/flakes/" ];
        workspaceDeps = [];

        # SATAN — phase-1 fake harness.  Emits ready, one tool_call, then
        # final with one org.update_owned_block action.  Used by the
        # broker (Emacs side) to validate the JSONL contract end-to-end
        # before swapping in a real model harness.
        satanFakeHarness =
          pkgs.writers.writePython3Bin "satan-fake-harness" {} ''
            import json
            import os
            import sys
            run_id = os.environ.get("SATAN_RUN_ID", "")
            print(json.dumps({"type": "ready", "run_id": run_id}), flush=True)
            print(json.dumps({
                "type": "tool_call", "id": "c1",
                "name": "org.read_context",
                "args": {"scope": "today"},
            }), flush=True)
            sys.stdin.readline()
            print(json.dumps({
                "type": "final",
                "summary": "fake harness ack",
                "actions": [
                    {"type": "org.update_owned_block",
                     "args": {"target": "today", "block": "satan",
                              "content": "SATAN was here.\n"}}
                ],
            }), flush=True)
          '';

        satanJailOptions = with jailLib.combinators; [
          (unsafe-add-raw-args ''--ro-bind "$HOME/notes" "/satan/notes"'')
          (unsafe-add-raw-args ''--bind "$HOME/notes/satan/hippocampus" "/satan/hippocampus"'')
          (unsafe-add-raw-args ''--bind "$SATAN_RUN_DIR" "/satan/run"'')
          (try-fwd-env "SATAN_RUN_ID")
          (set-env "SATAN_NOTES_RO"    "/satan/notes")
          (set-env "SATAN_HIPPOCAMPUS" "/satan/hippocampus")
          (set-env "SATAN_RUN_DIR"     "/satan/run")
        ];

        # SATAN — phase-2 real harness.  Drives an OpenAI-compatible
        # chat-completions loop (OpenRouter v1 by default).  Speaks the
        # SATAN JSONL protocol; terminates on a `satan.final` tool call.
        # See ~/.emacs.d/satan/harness/gptel_harness.py.
        satanGptelHarness =
          pkgs.writers.writePython3Bin "satan-gptel-harness" {
            libraries = with pkgs.python3Packages; [ openai ];
            flakeIgnore = [
              "E501" # line too long — model strings carry long descriptions
              "E402" # module-level import order (we have a __future__ line)
              "W503" # line break before binary operator
              "E704" # `def f(...) -> T: ...` one-liner for abstract methods
            ];
          } (builtins.readFile ./satan/harness/gptel_harness.py);

        # Extra env passed through the bwrap jail for the real harness:
        # provider selection + cumulative token budget + per-provider keys.
        satanGptelJailOptions = satanJailOptions ++ (with jailLib.combinators; [
          (try-fwd-env "SATAN_PROVIDER")
          (try-fwd-env "SATAN_MODEL")
          (try-fwd-env "SATAN_BUDGET_TOKENS")
          (try-fwd-env "OPENROUTER_API_KEY")
          (try-fwd-env "ANTHROPIC_API_KEY")
          (try-fwd-env "OPENAI_API_KEY")
          (try-fwd-env "DEEPSEEK_API_KEY")
        ]);

        jailPkgs = lib.optionalAttrs isLinux {
          jailed-pi = jailLib.makeJailedPi {
            profile = "specDev";
            allowSelfAsSubagent = true;
            maxSubagentDepth = 2;
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-pi-research = jailLib.makeJailedPi {
            name = "pi-research";
            profile = "research";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-opencode = jailLib.makeJailedOpencode {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-claude = jailLib.makeJailedClaude {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-codex = jailLib.makeJailedCodex {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-gemini = jailLib.makeJailedGemini {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          jailed-zero = jailLib.makeJailedZerostack {
            profile = "specDev";
            extraPkgs = projectPkgs;
            extraOptions = jailEnvOptions;
            inherit workspaceDeps;
          };
          satan-jailed-fake-harness = jailLib.makeJailedAgent {
            name = "satan-fake-harness";
            agent = satanFakeHarness;
            profile = "offline";
            extraOptions = satanJailOptions;
            workspaceDeps = [];
          };
          satan-jailed-gptel-harness = jailLib.makeJailedAgent {
            name = "satan-gptel-harness";
            agent = satanGptelHarness;
            profile = "specDev";
            extraOptions = satanGptelJailOptions;
            workspaceDeps = [];
          };
          bubblewrap = pkgs.bubblewrap;
        };
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
        };

        packages = lib.optionalAttrs isLinux jailPkgs;

        devshells.default = {
          packages = projectPkgs ++ lib.optionals isLinux (lib.attrValues jailPkgs);
          commands = [
            {
              name = "jcl";
              help = "jailed-claude --dangerously-skip-permissions";
              command = "jailed-claude --dangerously-skip-permissions $@";
            }
          ];
        };
      };
    };
}
