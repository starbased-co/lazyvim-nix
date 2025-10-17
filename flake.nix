{
  description = "A Nix flake for LazyVim that just works™";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages.default = pkgs.writeShellScriptBin "lazyvim-update" ''
          ${pkgs.bash}/bin/bash ${./scripts/update-plugins.sh}
        '';

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            neovim
            lua
            jq
            git
            ripgrep
            fd
          ];
        };
      })
    //
    {
      homeManagerModules.default = ./module.nix;
      homeManagerModules.lazyvim = ./module.nix;

      # Library functions for standalone usage
      lib = {
        # Build a standalone LazyVim configuration derivation
        # Usage: inputs.lazyvim-nix.lib.buildStandaloneConfig { inherit pkgs lib; } { ... }
        buildStandaloneConfig = { pkgs, lib }:
          pkgs.callPackage ./lib/build-standalone.nix { inherit lib; };
      };

      overlays.default = final: prev: {
        lazyvimPluginData = builtins.fromJSON (builtins.readFile ./plugins.json);
        lazyvimPluginMappings = import ./plugin-mappings.nix;
        lazyvimExtrasMetadata = import ./extras.nix;
        lazyvimOverrides = import ./overrides/default.nix { pkgs = final; };

        # Add standalone builder to overlay for convenience
        lazyvimStandaloneBuilder = final.callPackage ./lib/build-standalone.nix {};
      };
    };
}