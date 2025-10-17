# Plugin Testing Template
# Drop-in template for testing Neovim plugins with LazyVim
{ pkgs ? import <nixpkgs> {}
, inputs ? { lazyvim-nix = ./..; }  # Adjust path
, pluginSrc ? ./.                    # Your plugin source
}:

let
  # Build test LazyVim configuration
  testConfig = inputs.lazyvim-nix.lib.buildStandaloneConfig {
    inherit (pkgs) lib; inherit pkgs;
  } {
    # Minimal LazyVim setup
    lazyConfig = ''
      local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
      if not vim.loop.fs_stat(lazypath) then
        vim.fn.system({
          "git", "clone", "--filter=blob:none",
          "https://github.com/folke/lazy.nvim.git",
          "--branch=stable", lazypath,
        })
      end
      vim.opt.rtp:prepend(lazypath)

      require("lazy").setup({
        spec = { { import = "plugins" } },
        performance = { rtp = { disabled_plugins = {} } },
      })
    '';

    # Empty dev path (not testing other plugins)
    devPath = pkgs.runCommand "dev-path" {} "mkdir -p $out";

    # Optional: Add treesitter for syntax highlighting
    treesitterGrammars = null;  # or add parsers

    extrasConfigFiles = {};

    # Test environment options
    options = ''
      -- Disable swap files for testing
      vim.opt.swapfile = false
      vim.opt.backup = false

      -- Fast feedback
      vim.opt.updatetime = 100

      -- Test mode indicator
      vim.g.test_mode = true
    '';

    # Test-specific keymaps
    keymaps = ''
      -- Quick exit
      vim.keymap.set("n", "Q", "<cmd>qa!<cr>", { desc = "Quit all" })
    '';

    autocmds = "";

    # Load your plugin
    plugins = {
      your-plugin = ''
        return {
          -- Load from local source
          dir = "${pluginSrc}",

          -- Lazy load (optional)
          -- event = "VeryLazy",
          -- ft = "lua",

          -- Dependencies (optional)
          dependencies = {
            "nvim-lua/plenary.nvim",
          },

          -- Plugin configuration
          opts = {
            -- Your plugin options
          },

          -- Or custom config function
          config = function()
            require("your-plugin").setup({
              -- Options here
            })
          end,
        }
      '';

      -- Add test dependencies if needed
      plenary = ''
        return { "nvim-lua/plenary.nvim" }
      '';
    };

    name = "plugin-test-config";
  };

in {
  # Export test config
  inherit testConfig;

  # Test 1: Plugin loads without errors
  testLoad = pkgs.runCommand "test-plugin-load" {
    buildInputs = [ pkgs.neovim ];
  } ''
    echo "=== Testing Plugin Load ==="

    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless \
      +'lua print("✓ Plugin loaded")' \
      +quit \
      || exit 1

    echo "✓ Plugin loads successfully"
    touch $out
  '';

  # Test 2: Plugin setup works
  testSetup = pkgs.runCommand "test-plugin-setup" {
    buildInputs = [ pkgs.neovim ];
  } ''
    echo "=== Testing Plugin Setup ==="

    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless \
      +'lua require("your-plugin").setup()' \
      +'lua print("✓ Setup complete")' \
      +quit \
      || exit 1

    echo "✓ Plugin setup successful"
    touch $out
  '';

  # Test 3: Run plugin's test suite (if using plenary)
  testSuite = pkgs.runCommand "test-plugin-suite" {
    buildInputs = [ pkgs.neovim ];
  } ''
    echo "=== Running Plugin Test Suite ==="

    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless \
      +'PlenaryBustedDirectory ${pluginSrc}/tests/' \
      || exit 1

    echo "✓ Test suite passed"
    touch $out
  '';

  # Test 4: Interactive test environment
  shell = pkgs.mkShell {
    buildInputs = [ pkgs.neovim ];
    shellHook = ''
      export NVIM_APPNAME="${testConfig}"

      echo "=== Plugin Test Environment ==="
      echo "Config: ${testConfig}"
      echo "Plugin: ${pluginSrc}"
      echo ""
      echo "Run: nvim"
      echo "     nvim --headless +quit  (test load)"
      echo ""
    '';
  };

  # Test 5: Comprehensive validation
  testAll = pkgs.runCommand "test-plugin-all" {
    buildInputs = [ pkgs.neovim ];
  } ''
    echo "=== Comprehensive Plugin Tests ==="

    # Test 1: Config loads
    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless +quit || exit 1
    echo "✓ Config loads"

    # Test 2: Plugin available
    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless \
      +'lua assert(require("your-plugin"), "Plugin not found")' \
      +quit || exit 1
    echo "✓ Plugin available"

    # Test 3: Setup doesn't error
    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless \
      +'lua require("your-plugin").setup()' \
      +quit || exit 1
    echo "✓ Setup successful"

    echo ""
    echo "=== All Tests Passed ==="
    touch $out
  '';

  # CI-ready test (fast, single command)
  testCI = pkgs.runCommand "test-plugin-ci" {
    buildInputs = [ pkgs.neovim ];
  } ''
    ${pkgs.neovim}/bin/nvim \
      -u ${testConfig}/init.lua \
      --headless \
      +'lua require("your-plugin").setup()' \
      +'lua print("CI test passed")' \
      +quit && touch $out
  '';
}
