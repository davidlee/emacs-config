{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zig-overlay.url = "github:mitchellh/zig-overlay";
    # zls-overlay.url = "github:omega-800/zls-overlay";
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      zig-overlay,
      # zls-overlay,
    }:
    flake-utils.lib.eachSystem
      [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ]
      (
        system:
        let
          zigPackage = zig-overlay.packages.${system}."default";
          pkgs = nixpkgs.legacyPackages.${system};
          # packageName = "zsdl3";
          # isLinux = pkgs.stdenv.isLinux;
          isDarwin = pkgs.stdenv.isDarwin;

          # Linux-specific packages
          linuxPackages = with pkgs; [
            # vulkan-validation-layers #
            # imagemagick
          ];

          # Linux LD_LIBRARY_PATH dependencies
          linuxLibs = with pkgs; [
            # stdenv.cc.cc.lib # libstdc++ for pip packages with native extensions
            # mesa
            # alsa-lib
            # libdecor
            # libusb1
            # libxkbcommon
            # vulkan-loader
            # wayland
            # xorg.libX11
            # xorg.libXext
            # xorg.libXi
            # xorg.libXrandr
            # xorg.libXinerama
            # xorg.libXcursor
            # xorg.libXfixes
            # udev
            # dbus
            # wayland-protocols
          ];

          # Linux packages (includes zig/zls from nix)
          linuxToolchain = [
            pkgs.pyright
            # zls-overlay.packages.${system}."0.15.0"
            pkgs.zls
            zigPackage

            # pkgs.cue

            # python
            pkgs.uv
            pkgs.python312Packages.python-lsp-server
            pkgs.python312Packages.python-lsp-ruff
            pkgs.pyright

            # treesitter
            pkgs.tree-sitter
          ];

          # Darwin: don't use nix develop at all - see doc/issues/macos_sdl.md
          darwinToolchain = [ ];

          # Linux shell: use mkShell with full toolchain
          linuxShell = pkgs.mkShell {
            #name = packageName;
            packages = linuxToolchain ++ linuxPackages;
            LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath linuxLibs;
          };

          # Darwin: nix shell breaks Zig's framework detection.
          # Just use Homebrew zig/zls directly - don't use nix develop.
          # See: doc/issues/macos_sdl.md
          darwinShell = pkgs.mkShellNoCC {
            #name = packageName;
            packages = darwinToolchain;
            shellHook = ''
              echo ""
              echo "NOTE: On macOS, don't use nix develop."
              echo "      The nix shell environment breaks SDL3 framework detection."
              echo "      See: doc/issues/macos_sdl.md"
              echo ""
              echo "      brew install zig zls"
              echo "      zig build"
              echo ""
            '';
          };
        in
        {
          formatter = pkgs.nixpkgs-fmt;

          devShells.default = if isDarwin then darwinShell else linuxShell;
        }
      );
}
