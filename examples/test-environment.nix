# Complete Test LazyVim Environment Configuration
# This example shows how to create a comprehensive test configuration
{ pkgs ? import <nixpkgs> {}, lib ? pkgs.lib }:

let
  testLazyVim = lib.evalModules {
    modules = [
      { _module.args = { inherit pkgs; }; }
      ../module.nix
      {
        programs.lazyvim = {
          enable = true;

          # Enable standalone mode for testing
          standalone = {
            enable = true;
            outputName = "test-lazyvim-complete";
          };

          # Use latest plugin versions for testing bleeding edge
          pluginSource = "latest";

          # Development tools
          extraPackages = with pkgs; [
            # Lua development
            lua-language-server
            stylua

            # Nix development
            nil
            nixpkgs-fmt

            # General tools
            ripgrep
            fd
            git
          ];

          # Treesitter parsers for syntax highlighting
          treesitterParsers = with pkgs.tree-sitter-grammars; [
            # Core parsers (required for LazyVim)
            tree-sitter-lua
            tree-sitter-vim
            tree-sitter-vimdoc
            tree-sitter-query

            # Development languages
            tree-sitter-nix
            tree-sitter-bash
            tree-sitter-json
            tree-sitter-yaml
            tree-sitter-toml
            tree-sitter-markdown
          ];

          # Vim options for testing environment
          config.options = ''
            -- Editor behavior
            vim.opt.number = true
            vim.opt.relativenumber = true
            vim.opt.wrap = false
            vim.opt.swapfile = false
            vim.opt.backup = false

            -- Indentation
            vim.opt.tabstop = 2
            vim.opt.shiftwidth = 2
            vim.opt.expandtab = true

            -- Search
            vim.opt.ignorecase = true
            vim.opt.smartcase = true

            -- Performance
            vim.opt.updatetime = 250
            vim.opt.timeoutlen = 300

            -- UI
            vim.opt.signcolumn = "yes"
            vim.opt.cursorline = true
            vim.opt.termguicolors = true

            -- Testing specific
            vim.g.test_mode = true
          '';

          # Test-specific keymaps
          config.keymaps = ''
            -- Quick test commands
            vim.keymap.set("n", "<leader>tt", function()
              print("Test mode active!")
              print("Config: ${placeholder "out"}")
            end, { desc = "Test: Show info" })

            vim.keymap.set("n", "<leader>tr", "<cmd>source $MYVIMRC<cr>",
              { desc = "Test: Reload config" })

            -- Exit quickly in test mode
            vim.keymap.set("n", "<leader>qq", "<cmd>qa!<cr>",
              { desc = "Test: Quick exit" })
          '';

          # Test environment autocmds
          config.autocmds = ''
            -- Log when entering test mode
            vim.api.nvim_create_autocmd("VimEnter", {
              callback = function()
                print("=== LazyVim Test Environment ===")
                print("Config: ${placeholder "out"}")
                print("Leader: " .. vim.g.mapleader)
              end,
            })

            -- Auto-format on save during testing
            vim.api.nvim_create_autocmd("BufWritePre", {
              pattern = { "*.lua", "*.nix" },
              callback = function()
                vim.lsp.buf.format({ async = false })
              end,
            })

            -- Highlight yanked text
            vim.api.nvim_create_autocmd("TextYankPost", {
              callback = function()
                vim.highlight.on_yank({ timeout = 200 })
              end,
            })
          '';

          # Enable LazyVim extras for testing
          extras = {
            # Language support
            lang.lua = {
              enable = true;
              config = ''
                opts = {
                  servers = {
                    lua_ls = {
                      settings = {
                        Lua = {
                          workspace = { checkThirdParty = false },
                          telemetry = { enable = false },
                          diagnostics = {
                            globals = { "vim" },
                          },
                        },
                      },
                    },
                  },
                }
              '';
            };

            lang.nix = {
              enable = true;
              config = ''
                opts = {
                  servers = {
                    nil_ls = {
                      settings = {
                        ["nil"] = {
                          formatting = { command = { "nixpkgs-fmt" } },
                        },
                      },
                    },
                  },
                }
              '';
            };

            # Editor enhancements
            editor.telescope = {
              enable = true;
              config = ''
                opts = {
                  defaults = {
                    prompt_prefix = "🔍 ",
                    selection_caret = "➜ ",
                  },
                }
              '';
            };

            # Coding features
            coding.luasnip.enable = true;
          };

          # Custom plugins for testing
          plugins = {
            # Test theme
            theme = ''
              return {
                "folke/tokyonight.nvim",
                priority = 1000,
                opts = {
                  style = "night",
                  transparent = true,
                  terminal_colors = true,
                  styles = {
                    comments = { italic = true },
                    keywords = { italic = true },
                  },
                },
                config = function(_, opts)
                  require("tokyonight").setup(opts)
                  vim.cmd([[colorscheme tokyonight]])
                end,
              }
            '';

            # Test utilities
            test-utils = ''
              return {
                "nvim-lua/plenary.nvim",
                lazy = false,
              }
            '';
          };
        };
      }
    ];
  };

  # Extract the built config
  config = testLazyVim.config.programs.lazyvim.finalConfig;

in {
  inherit config;

  # Helper script to launch test environment
  launcher = pkgs.writeShellScriptBin "test-lazyvim" ''
    export NVIM_APPNAME="${config}"

    echo "=== LazyVim Test Environment ==="
    echo "Config: ${config}"
    echo "Starting Neovim..."
    echo ""

    exec ${pkgs.neovim}/bin/nvim "$@"
  '';

  # Quick test script
  quickTest = pkgs.writeShellScriptBin "quick-test-lazyvim" ''
    ${pkgs.neovim}/bin/nvim \
      -u ${config}/init.lua \
      --headless \
      -c "lua print('Config loaded successfully!')" \
      -c "lua print('Plugins: ' .. #require('lazy').plugins())" \
      -c "quit"
  '';
}
