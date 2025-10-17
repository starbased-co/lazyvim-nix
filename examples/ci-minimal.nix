# Minimal CI Test Template - Copy-Paste Ready
# Drop this file in your plugin repo as: tests/ci.nix
# Usage: nix-build tests/ci.nix

{ pkgs ? import <nixpkgs> {} }:

let
  # Point to lazyvim-nix (adjust as needed)
  lazyvim-nix = builtins.fetchGit {
    url = "https://github.com/pfassina/lazyvim-nix";
    # ref = "main";  # Uncomment to pin to main branch
  };

  # Build test config
  testConfig = (import lazyvim-nix {}).lib.buildStandaloneConfig {
    inherit (pkgs) lib; inherit pkgs;
  } {
    # Minimal LazyVim init
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
      require("lazy").setup({ spec = { { import = "plugins" } } })
    '';

    devPath = pkgs.runCommand "dev" {} "mkdir -p $out";
    treesitterGrammars = null;
    extrasConfigFiles = {};

    # Test environment
    options = "vim.opt.swapfile = false";
    keymaps = "";
    autocmds = "";

    # Your plugin
    plugins = {
      plugin = ''
        return {
          dir = "${./.}",  -- Current directory (your plugin)
          config = function()
            require("your-plugin").setup()
          end,
        }
      '';
    };

    name = "ci-test";
  };

in
# Single CI test: config loads and plugin setup works
pkgs.runCommand "plugin-ci-test" {
  buildInputs = [ pkgs.neovim ];
} ''
  echo "Running CI test..."

  ${pkgs.neovim}/bin/nvim \
    -u ${testConfig}/init.lua \
    --headless \
    +'lua require("your-plugin").setup()' \
    +'lua print("✓ CI test passed")' \
    +quit

  touch $out
''
