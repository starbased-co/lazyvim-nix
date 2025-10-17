# Proof of Concept Test for Standalone Mode
# This test validates that the standalone mode builds correctly
{
  pkgs ? import <nixpkgs> {},
  lib ? pkgs.lib,
}:

let
  # Mock home-manager config structure
  config = {
    home.homeDirectory = "/home/test";
    programs.lazyvim.finalConfig = null;
  };

  # Evaluate the module
  moduleEval = lib.evalModules {
    modules = [
      { _module.args = { inherit pkgs; }; }
      ./module.nix
      {
        programs.lazyvim = {
          enable = true;

          # Enable standalone mode
          standalone = {
            enable = true;
            outputName = "test-lazyvim-standalone";
          };

          # Minimal configuration for testing
          config.options = ''
            -- Test options
            vim.opt.number = true
            vim.opt.relativenumber = true
          '';

          plugins = {
            test-plugin = ''
              return {
                "folke/tokyonight.nvim",
                opts = {
                  style = "night",
                },
              }
            '';
          };

          # No extras or parsers for minimal PoC
          extras = {};
          treesitterParsers = [];
        };
      }
    ];
  };

  # Extract the built standalone config
  standaloneConfig = moduleEval.config.programs.lazyvim.finalConfig;

in {
  # Test 1: Standalone config should be built
  inherit standaloneConfig;

  # Test 2: Verify it's a derivation
  isDerivation = lib.isDerivation standaloneConfig;

  # Test 3: Verify structure (will fail if build fails)
  testBuild = pkgs.runCommand "test-standalone-structure" {} ''
    # Verify init.lua exists
    if [ ! -f "${standaloneConfig}/init.lua" ]; then
      echo "ERROR: init.lua not found"
      exit 1
    fi

    # Verify lua/config/options.lua exists
    if [ ! -f "${standaloneConfig}/lua/config/options.lua" ]; then
      echo "ERROR: lua/config/options.lua not found"
      exit 1
    fi

    # Verify lua/plugins/test-plugin.lua exists
    if [ ! -f "${standaloneConfig}/lua/plugins/test-plugin.lua" ]; then
      echo "ERROR: lua/plugins/test-plugin.lua not found"
      exit 1
    fi

    # Verify marker file exists
    if [ ! -f "${standaloneConfig}/.lazyvim-standalone" ]; then
      echo "ERROR: .lazyvim-standalone marker not found"
      exit 1
    fi

    echo "✓ All structure tests passed"
    echo "Standalone config built at: ${standaloneConfig}"
    touch $out
  '';

  # Test 4: Content validation
  testContent = pkgs.runCommand "test-standalone-content" {} ''
    # Check if options file contains our test content
    if ! grep -q "vim.opt.number = true" "${standaloneConfig}/lua/config/options.lua"; then
      echo "ERROR: options.lua doesn't contain expected content"
      exit 1
    fi

    # Check if plugin file contains tokyonight
    if ! grep -q "tokyonight" "${standaloneConfig}/lua/plugins/test-plugin.lua"; then
      echo "ERROR: test-plugin.lua doesn't contain expected content"
      exit 1
    fi

    echo "✓ All content tests passed"
    touch $out
  '';

  # Test 5: Normal mode still works (standalone = false)
  normalModeTest = let
    normalEval = lib.evalModules {
      modules = [
        { _module.args = { inherit pkgs; }; }
        ./module.nix
        {
          programs.lazyvim = {
            enable = true;
            standalone.enable = false;  # Normal mode
            config.options = ''vim.opt.number = true'';
          };
        }
      ];
    };
  in {
    # In normal mode, finalConfig should be null
    finalConfigIsNull = normalEval.config.programs.lazyvim.finalConfig == null;

    # In normal mode, xdg.configFile should be set
    hasXdgConfigFile = normalEval.config.xdg.configFile ? "nvim/init.lua";
  };
}
