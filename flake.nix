{
  description = "flake for doing emacs";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Wrapped Emacs (the manual package list). Own pins, no follows, so
    # every devshell shares one build.
    emacs.url = "github:davidlee/nix-config?dir=flakes/emacs";
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
      zigPackage = zig-overlay.packages.${system}."default";

      doctrine-pkg = doctrine.packages.${system}.default;
      wrappedEmacs = inputs.emacs.packages.${system}.default;
      # The tool set, exported as `packages.dev-tools`; dev-envs builds the jails,
      # forms and shell from it. The oubliette room's `toolsPackage` is
      # `packages.capsule-tools`, the same set plus doctrine, where the agents
      # come from the room (IMP-025).
      devToolPkgs = with pkgs; [
        zigPackage # ghostel compile
        nodejs_latest # acp
        just
        postgresql_18
        wrappedEmacs
        emacsclient-commands
        sqlite
        socat
        bun
        gdb # debugging emacs
        alejandra # dl-nix formatter; matches treefmt
      ];
    in {
      packages = {
        # The devshell's tool set as one closure, so the VM and the devshell
        # can't drift.
        dev-tools = pkgs.buildEnv {
          name = "emacs-config-dev-tools";
          paths = devToolPkgs;
          ignoreCollisions = true;
        };
        capsule-tools = pkgs.buildEnv {
          name = "emacs-config-capsule-tools";
          paths = devToolPkgs ++ [doctrine-pkg];
          ignoreCollisions = true;
        };
      };

      devShell = pkgs.mkShell {packages = devToolPkgs;};
    };

    perSystem = nixpkgs.lib.genAttrs systems mkSystem;
  in {
    packages = nixpkgs.lib.mapAttrs (_: value: value.packages) perSystem;
    devShells = nixpkgs.lib.mapAttrs (_: value: {default = value.devShell;}) perSystem;
  };
}
