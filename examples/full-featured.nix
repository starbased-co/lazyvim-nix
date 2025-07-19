# Full-featured LazyVim configuration example
# This demonstrates all available options and common use cases
{pkgs, ...}: {
  # Import the LazyVim module
  imports = [
    # In a real flake, this would be:
    # inputs.lazyvim.homeManagerModules.default
    ../module.nix
  ];

  programs.lazyvim = {
    enable = true;

    # LSP servers, formatters, linters, and tools
    extraPackages = with pkgs; [
      # LSP servers
      lua-language-server
      nil
      nixd
      pyright
      ruff
      clang
      yaml-language-server

      # Formatters
      alejandra
      stylua
      ruff

      # Tools
      ripgrep
      fd
      git
      lua5_1
      luarocks

      # Image preview tools
      viu
      chafa

      # SQLite for Snacks.picker frecency/history
      sqlite
      lua51Packages.luasql-sqlite3

      # Tools for Snacks.image rendering
      ghostscript # for PDF rendering
      tectonic # for LaTeX math expressions
      mermaid-cli # for Mermaid diagrams
    ];

    # Treesitter parsers for syntax highlighting
    treesitterParsers = with pkgs.tree-sitter-grammars; [
      tree-sitter-bash
      tree-sitter-css
      tree-sitter-html
      tree-sitter-javascript
      tree-sitter-json
      tree-sitter-latex
      tree-sitter-lua
      tree-sitter-markdown
      tree-sitter-nix
      tree-sitter-nu
      tree-sitter-python
      tree-sitter-regex
      tree-sitter-scss
      tree-sitter-toml
      tree-sitter-tsx
      tree-sitter-typescript
      tree-sitter-yaml
    ];

    # LazyVim configuration structure
    config = {
      options = ''
        vim.opt.relativenumber = true
        vim.opt.tabstop = 2
        vim.opt.shiftwidth = 2
        vim.opt.expandtab = true
        vim.opt.wrap = false
        vim.opt.cursorline = true
        vim.opt.signcolumn = "yes"
        vim.opt.scrolloff = 8
        vim.opt.sidescrolloff = 8
        vim.cmd.colorscheme("tokyonight-night")
      '';

      keymaps = ''
        local map = vim.keymap.set

        -- Better window navigation
        map("n", "<C-h>", "<C-w>h", { desc = "Go to left window" })
        map("n", "<C-j>", "<C-w>j", { desc = "Go to lower window" })
        map("n", "<C-k>", "<C-w>k", { desc = "Go to upper window" })
        map("n", "<C-l>", "<C-w>l", { desc = "Go to right window" })

        -- Resize windows with arrows
        map("n", "<C-Up>", ":resize +2<CR>", { desc = "Increase window height" })
        map("n", "<C-Down>", ":resize -2<CR>", { desc = "Decrease window height" })
        map("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Decrease window width" })
        map("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Increase window width" })
      '';

      autocmds = ''
        local augroup = vim.api.nvim_create_augroup
        local autocmd = vim.api.nvim_create_autocmd

        -- Highlight on yank
        autocmd("TextYankPost", {
          group = augroup("highlight_yank", { clear = true }),
          callback = function()
            vim.highlight.on_yank({ timeout = 200 })
          end,
        })

        -- Auto-format on save for specific filetypes
        autocmd("BufWritePre", {
          group = augroup("auto_format", { clear = true }),
          pattern = { "*.go", "*.rs", "*.nix" },
          callback = function()
            vim.lsp.buf.format({ async = false })
          end,
        })
      '';
    };

    # Plugin configurations
    plugins = {
      # GitHub Copilot
      copilot = ''
        return {
          "github/copilot.vim",
          lazy = false,
          config = function()
            vim.g.copilot_no_tab_map = true
            vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
              expr = true,
              replace_keycodes = false
            })
          end,
        }
      '';

      # Better escape
      better-escape = ''
        return {
          "max397574/better-escape.nvim",
          event = "InsertEnter",
          opts = {
            mapping = {"jk", "jj"},
            timeout = 200,
          },
        }
      '';

      # Zen mode for distraction-free writing
      zen-mode = ''
        return {
          "folke/zen-mode.nvim",
          cmd = "ZenMode",
          opts = {
            window = {
              width = 120,
              options = {
                number = false,
                relativenumber = false,
              },
            },
          },
        }
      '';

      # Markdown preview
      markdown-preview = ''
        return {
          "iamcco/markdown-preview.nvim",
          ft = "markdown",
          build = "cd app && npm install",
          config = function()
            vim.g.mkdp_auto_start = 0
            vim.g.mkdp_auto_close = 1
          end,
        }
      '';

      # Language-specific configurations
      languages = ''
        return {
          -- Rust enhancements
          {
            "simrat39/rust-tools.nvim",
            ft = "rust",
            opts = {
              tools = {
                inlay_hints = {
                  auto = true,
                },
              },
            },
          },

          -- Go enhancements
          {
            "ray-x/go.nvim",
            ft = "go",
            config = function()
              require("go").setup({
                lsp_inlay_hints = {
                  enable = true,
                },
              })
            end,
          },
        }
      '';
    };
  };
}

