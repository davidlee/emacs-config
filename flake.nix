{
  description = "flake for doing emacs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    emacs-overlay.url = "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
    pub = {
      url = "path:/home/david/flakes/pub";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.emacs-overlay.follows = "emacs-overlay";
    };
    llm-agents.url = "github:numtide/llm-agents.nix";
    doctrine.url = "github:davidlee/doctrine";
    zig-overlay.url = "github:mitchellh/zig-overlay";
  };

  outputs = inputs @ {
    nixpkgs,
    doctrine, # doctrine
    zig-overlay, # for building ghostel
    ...
  }: let
    systems = [
      "x86_64-linux"
      "aarch64-darwin"
    ];

    mkSystem = system: let
      pkgs = import nixpkgs {inherit system;};
      inherit (pkgs) lib stdenv;
      isLinux = stdenv.isLinux;
      zigPackage = zig-overlay.packages.${system}."default";

      jailLib =
        if isLinux
        then
          inputs.pub.lib.${system}.mkJailedAgents {
            inherit (inputs) llm-agents;
            gitIdentity = {
              authorName = "David Lee's clanker";
              authorEmail = "clanker+dav@davlee.com";
              committerName = "David Lee";
              committerEmail = "dav@davlee.com";
            };
          }
        else {};
      doctrine-pkg = doctrine.packages.${system}.default;
      wrappedEmacs = inputs.pub.packages.${system}.emacs;
      projectPkgs = with pkgs;
        [
          zigPackage
          nodejs
          just
          postgresql_18
          supabase-cli
          wrappedEmacs
          emacsclient-commands
          sqlite
          socat
          bun
          codex
          helix
          gdb # debugging emacs
        ]
        ++ [doctrine-pkg]
        ++ lib.optionals isLinux [
          jailLib.agentsByName.claude
          jailLib.agentsByName.pi
        ];

      mcpJailOptions = with jailLib.combinators; [
        # expose SATAN MCP
        (try-readwrite "/run/user/1000/satan/mcp/mcp.sock")
        (try-fwd-env "XDG_RUNTIME_DIR")
        (try-fwd-env "SATAN_MCP_SOCKET")
        # (allow arbitrary elisp execution):
        (try-readwrite "/run/user/1000/emacs/server")
      ];

      apiKeyJailOptions = with jailLib.combinators; [
        (try-fwd-env "OPENROUTER_API_KEY")
        (ro-bind "/usr/bin/env" "/usr/bin/env")
        pulse
        (try-readonly "/mnt/500G/home/david/.local/share/Steam/friends/voice_hang_up.wav")
      ];

      supabaseJailOptions = with jailLib.combinators; [
        (try-fwd-env "DOCKER_HOST")
        (try-readwrite "/run/user/1000/podman/podman.sock")
        (set-env "SATAN_DB_HOST" "127.0.0.1")
        (set-env "PGHOST" "127.0.0.1")
        (set-env "PGPORT" "54322")
        (set-env "PGUSER" "postgres")
        (set-env "PGPASSWORD" "postgres")
      ];

      jailEnvOptions = apiKeyJailOptions ++ supabaseJailOptions ++ mcpJailOptions;
      # workspaceDeps = [ "/home/david/.emacs.d/" ];
      workspaceDeps = [
        "/home/david/flakes/"
        "/home/david/notes/"
        "/home/david/.local/state/behaviour/"
        "/home/david/dev/satan-attrd/"
        "/home/david/dev/satan-patcher/"
        "/home/david/dev/panopticon/"
      ];

      # SATAN harness + jail options moved to the standalone satan repo
      # flake (~/dev/satan) at SL-012 PHASE-04. The jailed harness is
      # provisioned onto PATH via ~/flakes home.packages, not from here.

      jailPkgs = lib.optionalAttrs isLinux {
        jailed-pi = jailLib.makeJailedPi {
          profile = "specDev";
          allowSelfAsSubagent = true;
          maxSubagentDepth = 2;
          extraPkgs = projectPkgs;
          extraOptions = jailEnvOptions;
          inherit workspaceDeps;
          # Patch-agent adapter pre-resolves op:// refs via
          # `my/op-read-env' (Emacs session cache) and exports the
          # plaintext into `process-environment' before spawning, so
          # skip the outer `op run' wrapper that would prompt
          # biometric per launch.  `passApiKeysFromEnv = true' keeps
          # the bwrap `--setenv VAR "$VAR"' forwarding so the
          # caller-side env still flows into the jail.
          useOpEnv = false;
          passApiKeysFromEnv = true;
        };
        jailed-pi-research = jailLib.makeJailedPi {
          name = "pi-research";
          profile = "research";
          extraPkgs = projectPkgs;
          extraOptions = apiKeyJailOptions;
          subagents = ["pi" "dirge" "claude"];
          inherit workspaceDeps;
        };
        jailed-opencode = jailLib.makeJailedOpencode {
          profile = "specDev";
          extraPkgs = projectPkgs;
          extraOptions = jailEnvOptions;
          subagents = ["pi" "dirge" "claude"];
          inherit workspaceDeps;
        };
        jailed-claude = jailLib.makeJailedClaude {
          profile = "specDev";
          extraPkgs = projectPkgs;
          extraOptions = jailEnvOptions;
          subagents = ["pi" "dirge" "claude"];
          inherit workspaceDeps;
        };
        jailed-dirge = jailLib.makeJailedDirge {
          profile = "specDev";
          extraPkgs = projectPkgs;
          extraOptions = apiKeyJailOptions;
          subagents = ["pi" "dirge" "claude"];
          inherit workspaceDeps;
        };
        # jailed-codex = jailLib.makeJailedCodex {
        #   profile = "specDev";
        #   extraPkgs = projectPkgs;
        #   extraOptions = jailEnvOptions;
        #   inherit workspaceDeps;
        # };
        # jailed-zero = jailLib.makeJailedZerostack {
        #   profile = "specDev";
        #   extraPkgs = projectPkgs;
        #   extraOptions = jailEnvOptions;
        #   inherit workspaceDeps;
        # };
        jailed-shell = jailLib.makeJailedAgent {
          name = "shell";
          agent = pkgs.zsh;
          profile = "specDev";
          extraPkgs = projectPkgs;
          subagents = ["pi" "dirge" "claude"];
          extraOptions = jailEnvOptions;
        };
        bubblewrap = pkgs.bubblewrap;
      };

      mkCommand = name: text:
        pkgs.writeShellApplication {
          inherit name text;
        };

      portableCommands = [
        (mkCommand "d" ''
          exec doctrine "$@"
        '')
        (mkCommand "sdr" ''
          exec spec-driver "$@"
        '')
      ];

      linuxCommands = lib.optionals isLinux [
        (mkCommand "jpi" ''
          exec op run -- jailed-pi "$@"
        '')
        (mkCommand "jcl" ''
          case "''${1:-}" in
            marketplace|update|config|mcp) exec jailed-claude "$@" ;;
            *) exec jailed-claude --dangerously-skip-permissions "$@" ;;
          esac
        '')
        (mkCommand "jail-zsh" ''
          exec jailed-shell "$@"
        '')
      ];
    in {
      packages = lib.optionalAttrs isLinux jailPkgs;

      devShell = pkgs.mkShell {
        packages =
          projectPkgs
          ++ lib.optionals isLinux (lib.attrValues jailPkgs)
          ++ portableCommands
          ++ linuxCommands;
      };
    };

    perSystem = nixpkgs.lib.genAttrs systems mkSystem;
  in {
    packages = nixpkgs.lib.mapAttrs (_: value: value.packages) perSystem;
    devShells = nixpkgs.lib.mapAttrs (_: value: {default = value.devShell;}) perSystem;
  };
}
