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
          bubblewrap = pkgs.bubblewrap;
        };
      in {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
        };

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
