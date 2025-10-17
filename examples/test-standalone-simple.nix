# Simple Standalone Mode Test
# Directly tests the build-standalone.nix function
{ pkgs ? import <nixpkgs> {} }:

let
  # Create minimal test inputs
  lazyConfig = ''
    -- Test LazyVim Config
    require("lazy").setup({})
  '';

  devPath = pkgs.runCommand "test-dev-path" {} ''
    mkdir -p $out
    echo "test dev path" > $out/.test
  '';

  treesitterGrammars = null;  # No parsers for minimal test

  extrasConfigFiles = {};  # No extras

  # Build the standalone config
  standaloneConfig = pkgs.callPackage ./lib/build-standalone.nix {} {
    inherit lazyConfig devPath treesitterGrammars extrasConfigFiles;

    autocmds = ''
      -- Test autocmds
      vim.api.nvim_create_autocmd("BufWritePre", {
        pattern = "*",
        command = "echo 'test'",
      })
    '';

    keymaps = ''
      -- Test keymaps
      vim.keymap.set("n", "<leader>t", "<cmd>echo 'test'<cr>")
    '';

    options = ''
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

      another-plugin = ''
        return {
          "nvim-telescope/telescope.nvim",
        }
      '';
    };

    name = "test-lazyvim-standalone";
  };

in {
  # Expose the standalone config
  inherit standaloneConfig;

  # Test 1: Verify structure
  testStructure = pkgs.runCommand "test-standalone-structure" {} ''
    echo "=== Testing Standalone Config Structure ==="

    # Verify init.lua exists
    if [ ! -f "${standaloneConfig}/init.lua" ]; then
      echo "❌ ERROR: init.lua not found"
      exit 1
    fi
    echo "✓ init.lua exists"

    # Verify lua/config/ directory and files
    if [ ! -d "${standaloneConfig}/lua/config" ]; then
      echo "❌ ERROR: lua/config directory not found"
      exit 1
    fi
    echo "✓ lua/config directory exists"

    for file in autocmds keymaps options; do
      if [ ! -f "${standaloneConfig}/lua/config/$file.lua" ]; then
        echo "❌ ERROR: lua/config/$file.lua not found"
        exit 1
      fi
      echo "✓ lua/config/$file.lua exists"
    done

    # Verify lua/plugins/ directory and files
    if [ ! -d "${standaloneConfig}/lua/plugins" ]; then
      echo "❌ ERROR: lua/plugins directory not found"
      exit 1
    fi
    echo "✓ lua/plugins directory exists"

    if [ ! -f "${standaloneConfig}/lua/plugins/test-plugin.lua" ]; then
      echo "❌ ERROR: lua/plugins/test-plugin.lua not found"
      exit 1
    fi
    echo "✓ lua/plugins/test-plugin.lua exists"

    if [ ! -f "${standaloneConfig}/lua/plugins/another-plugin.lua" ]; then
      echo "❌ ERROR: lua/plugins/another-plugin.lua not found"
      exit 1
    fi
    echo "✓ lua/plugins/another-plugin.lua exists"

    # Verify marker file
    if [ ! -f "${standaloneConfig}/.lazyvim-standalone" ]; then
      echo "❌ ERROR: .lazyvim-standalone marker not found"
      exit 1
    fi
    echo "✓ .lazyvim-standalone marker exists"

    echo ""
    echo "=== All Structure Tests Passed ==="
    echo "Standalone config location: ${standaloneConfig}"
    touch $out
  '';

  # Test 2: Verify content
  testContent = pkgs.runCommand "test-standalone-content" {} ''
    echo "=== Testing Standalone Config Content ==="

    # Check init.lua
    if ! grep -q "require.*lazy" "${standaloneConfig}/init.lua"; then
      echo "❌ ERROR: init.lua doesn't contain lazy setup"
      exit 1
    fi
    echo "✓ init.lua contains lazy setup"

    # Check autocmds
    if ! grep -q "BufWritePre" "${standaloneConfig}/lua/config/autocmds.lua"; then
      echo "❌ ERROR: autocmds.lua doesn't contain expected content"
      exit 1
    fi
    echo "✓ autocmds.lua contains expected content"

    # Check keymaps
    if ! grep -q "leader.*t" "${standaloneConfig}/lua/config/keymaps.lua"; then
      echo "❌ ERROR: keymaps.lua doesn't contain expected content"
      exit 1
    fi
    echo "✓ keymaps.lua contains expected content"

    # Check options
    if ! grep -q "vim.opt.number" "${standaloneConfig}/lua/config/options.lua"; then
      echo "❌ ERROR: options.lua doesn't contain expected content"
      exit 1
    fi
    echo "✓ options.lua contains expected content"

    # Check plugins
    if ! grep -q "tokyonight" "${standaloneConfig}/lua/plugins/test-plugin.lua"; then
      echo "❌ ERROR: test-plugin.lua doesn't contain expected content"
      exit 1
    fi
    echo "✓ test-plugin.lua contains expected content"

    if ! grep -q "telescope" "${standaloneConfig}/lua/plugins/another-plugin.lua"; then
      echo "❌ ERROR: another-plugin.lua doesn't contain expected content"
      exit 1
    fi
    echo "✓ another-plugin.lua contains expected content"

    echo ""
    echo "=== All Content Tests Passed ==="
    touch $out
  '';

  # Test 3: Display full structure
  showStructure = pkgs.runCommand "show-standalone-structure" {} ''
    echo "=== Standalone Config File Tree ==="
    echo ""
    ls -laR "${standaloneConfig}"
    echo ""
    echo "=== init.lua Preview ==="
    head -20 "${standaloneConfig}/init.lua"
    echo ""
    echo "=== Config Files ==="
    for f in "${standaloneConfig}"/lua/config/*.lua; do
      echo "--- $(basename $f) ---"
      cat "$f"
      echo ""
    done
    echo ""
    echo "=== Plugin Files ==="
    for f in "${standaloneConfig}"/lua/plugins/*.lua; do
      echo "--- $(basename $f) ---"
      cat "$f"
      echo ""
    done
    touch $out
  '';
}
