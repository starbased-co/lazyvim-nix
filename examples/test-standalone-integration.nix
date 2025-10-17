# Integration Test for Standalone Mode
# Tests full functionality including treesitter, extras, and plugins
{ pkgs ? import <nixpkgs> {} }:

let
  # Test all major features of standalone mode
  fullTestConfig = pkgs.callPackage ./lib/build-standalone.nix {} {
    # LazyVim core configuration
    lazyConfig = ''
      -- LazyVim Nix Configuration
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
        spec = {
          { "LazyVim/LazyVim", import = "lazyvim.plugins", dev = true },
          { import = "plugins" },
        },
      })
    '';

    # Dev path with test plugins
    devPath = pkgs.runCommand "test-dev-path" {} ''
      mkdir -p $out
      echo "test dev path for integration" > $out/.test
    '';

    # Treesitter parsers
    treesitterGrammars = let
      parsers = pkgs.symlinkJoin {
        name = "test-treesitter-parsers";
        paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
          p.tree-sitter-lua
          p.tree-sitter-nix
          p.tree-sitter-vim
        ])).dependencies;
      };
    in parsers;

    # Extras configuration files
    extrasConfigFiles = {
      "nvim/lua/plugins/extras-lang-lua.lua" = {
        text = ''
          -- Extra configuration for lang.lua
          return {
            opts = {
              servers = {
                lua_ls = {
                  settings = {
                    Lua = {
                      workspace = { checkThirdParty = false },
                      diagnostics = { globals = { "vim" } },
                    },
                  },
                },
              },
            },
          }
        '';
      };
    };

    # User configuration
    autocmds = ''
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "lua",
        callback = function()
          vim.opt_local.tabstop = 2
        end,
      })
    '';

    keymaps = ''
      vim.keymap.set("n", "<leader>t", "<cmd>echo 'Integration test'<cr>")
    '';

    options = ''
      vim.opt.number = true
      vim.opt.relativenumber = true
    '';

    plugins = {
      theme = ''
        return { "folke/tokyonight.nvim" }
      '';
      telescope = ''
        return { "nvim-telescope/telescope.nvim" }
      '';
    };

    name = "test-lazyvim-integration";
  };

in {
  inherit fullTestConfig;

  # Test 1: All directories exist
  testStructure = pkgs.runCommand "test-integration-structure" {} ''
    echo "=== Integration Test: Structure ==="

    # Core files
    test -f "${fullTestConfig}/init.lua" || exit 1
    echo "✓ init.lua"

    # Config directory
    test -d "${fullTestConfig}/lua/config" || exit 1
    test -f "${fullTestConfig}/lua/config/autocmds.lua" || exit 1
    test -f "${fullTestConfig}/lua/config/keymaps.lua" || exit 1
    test -f "${fullTestConfig}/lua/config/options.lua" || exit 1
    echo "✓ lua/config/"

    # Plugins directory
    test -d "${fullTestConfig}/lua/plugins" || exit 1
    test -f "${fullTestConfig}/lua/plugins/theme.lua" || exit 1
    test -f "${fullTestConfig}/lua/plugins/telescope.lua" || exit 1
    test -f "${fullTestConfig}/lua/plugins/extras-lang-lua.lua" || exit 1
    echo "✓ lua/plugins/"

    # Treesitter parsers
    test -d "${fullTestConfig}/parser" || exit 1
    test -f "${fullTestConfig}/parser/lua.so" || exit 1
    test -f "${fullTestConfig}/parser/nix.so" || exit 1
    echo "✓ parser/"

    echo "✓ All structure tests passed"
    touch $out
  '';

  # Test 2: Treesitter parsers are valid symlinks
  testTreesitter = pkgs.runCommand "test-integration-treesitter" {} ''
    echo "=== Integration Test: Treesitter ==="

    # Check parsers are symlinks to store
    for parser in lua nix vim; do
      if [ -L "${fullTestConfig}/parser/$parser.so" ]; then
        target=$(readlink "${fullTestConfig}/parser/$parser.so")
        if [[ "$target" == /nix/store/* ]]; then
          echo "✓ $parser.so -> $target"
        else
          echo "✗ $parser.so not pointing to /nix/store"
          exit 1
        fi
      else
        echo "✗ $parser.so not a symlink"
        exit 1
      fi
    done

    echo "✓ All treesitter tests passed"
    touch $out
  '';

  # Test 3: Extras config files are generated
  testExtras = pkgs.runCommand "test-integration-extras" {} ''
    echo "=== Integration Test: Extras ==="

    # Check extras file exists
    test -f "${fullTestConfig}/lua/plugins/extras-lang-lua.lua" || exit 1
    echo "✓ extras-lang-lua.lua exists"

    # Check extras content
    if grep -q "lua_ls" "${fullTestConfig}/lua/plugins/extras-lang-lua.lua"; then
      echo "✓ extras content valid"
    else
      echo "✗ extras content invalid"
      exit 1
    fi

    echo "✓ All extras tests passed"
    touch $out
  '';

  # Test 4: Full validation
  testComplete = pkgs.runCommand "test-integration-complete" {
    buildInputs = [ pkgs.neovim ];
  } ''
    echo "=== Integration Test: Complete Validation ==="

    # Test Neovim can load the config (headless)
    ${pkgs.neovim}/bin/nvim \
      -u ${fullTestConfig}/init.lua \
      --headless \
      +'lua print("Config loaded successfully")' \
      +quit \
      || exit 1
    echo "✓ Neovim loads config"

    # Check marker file
    test -f "${fullTestConfig}/.lazyvim-standalone" || exit 1
    echo "✓ Marker file present"

    echo ""
    echo "=== All Integration Tests Passed ==="
    echo "Config: ${fullTestConfig}"
    touch $out
  '';
}
