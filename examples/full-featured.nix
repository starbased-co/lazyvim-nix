# Full-featured LazyVim configuration example
# This demonstrates all available options and common use cases

{ config, pkgs, ... }:

{
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
      rust-analyzer
      gopls
      nodePackages.typescript-language-server
      nodePackages.vscode-langservers-extracted # HTML, CSS, JSON, ESLint
      pyright
      nil # Nix LSP
      clangd
      zls # Zig LSP
      
      # Formatters
      stylua
      rustfmt
      gofumpt
      prettierd
      black
      isort
      nixpkgs-fmt
      shfmt
      
      # Linters
      shellcheck
      hadolint
      golangci-lint
      eslint_d
      ruff
      
      # Tools
      ripgrep
      fd
      lazygit
      gh # GitHub CLI
      delta # Better git diffs
      
      # Debug adapters
      delve # Go debugger
      lldb # C/C++ debugger
    ];
    
    # Treesitter parsers for syntax highlighting
    treesitterParsers = [
      "bash"
      "c"
      "cpp"
      "css"
      "dockerfile"
      "go"
      "gomod"
      "gowork"
      "html"
      "javascript"
      "json"
      "lua"
      "make"
      "markdown"
      "markdown_inline"
      "nix"
      "python"
      "rust"
      "toml"
      "tsx"
      "typescript"
      "vim"
      "vimdoc"
      "yaml"
      "zig"
    ];
    
    # LazyVim settings
    settings = {
      colorscheme = "tokyonight-night";
      options = {
        relativenumber = true;
        tabstop = 2;
        shiftwidth = 2;
        expandtab = true;
        wrap = false;
        cursorline = true;
        signcolumn = "yes";
        scrolloff = 8;
        sidescrolloff = 8;
      };
    };
    
    # Additional plugins not included in LazyVim by default
    extraPlugins = [
      # GitHub Copilot
      {
        name = "github/copilot.vim";
        lazy = false;
        config = ''
          vim.g.copilot_no_tab_map = true
          vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
            expr = true,
            replace_keycodes = false
          })
        '';
      }
      
      # Better escape
      {
        name = "max397574/better-escape.nvim";
        event = "InsertEnter";
        config = ''
          require("better_escape").setup({
            mapping = {"jk", "jj"},
            timeout = 200,
          })
        '';
      }
      
      # Zen mode for distraction-free writing
      {
        name = "folke/zen-mode.nvim";
        cmd = "ZenMode";
        config = ''
          require("zen-mode").setup({
            window = {
              width = 120,
              options = {
                number = false,
                relativenumber = false,
              },
            },
          })
        '';
      }
      
      # Markdown preview
      {
        name = "iamcco/markdown-preview.nvim";
        ft = ["markdown"];
        build = "cd app && npm install";
        config = ''
          vim.g.mkdp_auto_start = 0
          vim.g.mkdp_auto_close = 1
        '';
      }
    ];
  };
  
  # You can still add custom Lua configurations
  xdg.configFile = {
    # Custom keymaps
    "nvim/lua/config/keymaps.lua".text = ''
      -- Additional keymaps
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
    
    # Custom autocmds
    "nvim/lua/config/autocmds.lua".text = ''
      -- Autocommands
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
    
    # Language-specific plugin configurations
    "nvim/lua/plugins/languages.lua".text = ''
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
}