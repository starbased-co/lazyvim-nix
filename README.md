# lazyvim-nix

A Nix flake for LazyVim that just works™

## What is this?

This flake lets you use [LazyVim](https://www.lazyvim.org/) on NixOS with minimal configuration. It automatically manages plugins and provides the full LazyVim experience without manual maintenance.

## Quick Start

1. Add the flake to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    lazyvim.url = "github:your-username/lazyvim-nix";
  };

  outputs = { nixpkgs, home-manager, lazyvim, ... }: {
    # Your system configuration
  };
}
```

2. Enable LazyVim in your home-manager configuration:

```nix
{
  imports = [ lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;
  };
}
```

3. That's it! Open `nvim` and enjoy LazyVim.

## Configuration

### Adding Language Support

```nix
programs.lazyvim = {
  enable = true;
  
  # Add LSP servers and tools
  extraPackages = with pkgs; [
    rust-analyzer
    gopls
    nodePackages.typescript-language-server
  ];
  
  # Add treesitter parsers
  treesitterParsers = with pkgs.tree-sitter-grammars; [
    tree-sitter-rust
    tree-sitter-go
    tree-sitter-typescript
    tree-sitter-tsx
  ];
};
```

### Customizing LazyVim

```nix
programs.lazyvim = {
  enable = true;
  
  # LazyVim configuration structure
  config = {
    options = ''
      vim.opt.relativenumber = false
      vim.opt.tabstop = 2
      vim.cmd.colorscheme("catppuccin")
    '';
  };
  
  # Add plugins
  plugins = {
    copilot = ''
      return {
        "github/copilot.vim",
        lazy = false,
      }
    '';
  };
};
```

### LazyVim Directory Structure Support

Configure LazyVim using the same directory structure as a standard LazyVim setup, but directly in your Nix configuration:

```nix
programs.lazyvim = {
  enable = true;

  # Maps to lua/config/ directory
  config = {
    # Custom autocmds → lua/config/autocmds.lua
    autocmds = ''
      vim.api.nvim_create_autocmd("FocusLost", {
        command = "silent! wa",
      })
    '';

    # Custom keymaps → lua/config/keymaps.lua
    keymaps = ''
      vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { desc = "Save file" })
    '';

    # Custom options → lua/config/options.lua
    options = ''
      vim.opt.relativenumber = false
      vim.opt.wrap = true
    '';
  };

  # Maps to lua/plugins/ directory
  plugins = {
    # Each key becomes lua/plugins/{key}.lua
    custom-theme = ''
      return {
        "folke/tokyonight.nvim",
        opts = { style = "night", transparent = true },
      }
    '';
    
    lsp-config = ''
      return {
        "neovim/nvim-lspconfig",
        opts = function(_, opts)
          opts.servers.rust_analyzer = {
            settings = {
              ["rust-analyzer"] = {
                checkOnSave = { command = "clippy" },
              },
            },
          }
          return opts
        end,
      }
    '';
  };
};
```

### Using Your Own Plugin Configs

You can also place custom plugin configurations directly in `~/.config/nvim/lua/plugins/` as you would with a standard LazyVim setup:

```lua
-- ~/.config/nvim/lua/plugins/my-config.lua
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        rust_analyzer = {
          settings = {
            ["rust-analyzer"] = {
              checkOnSave = {
                command = "clippy",
              },
            },
          },
        },
      },
    },
  },
}
```

## Updating

To update to the latest LazyVim version:

```bash
nix flake update lazyvim
```

This will fetch the latest plugin configurations from LazyVim automatically.

## Examples

### Minimal Setup

```nix
programs.lazyvim.enable = true;
```

### Full-Featured Development Environment

```nix
programs.lazyvim = {
  enable = true;
  
  extraPackages = with pkgs; [
    # LSP servers
    lua-language-server
    rust-analyzer
    gopls
    nodePackages.typescript-language-server
    
    # Formatters
    stylua
    rustfmt
    gofumpt
    prettierd
    
    # Tools
    ripgrep
    fd
    lazygit
  ];
  
  treesitterParsers = [
    "bash"
    "css"
    "go"
    "html"
    "javascript"
    "json"
    "lua"
    "markdown"
    "nix"
    "python"
    "rust"
    "typescript"
    "yaml"
  ];
  
  config = {
    options = ''
      vim.opt.wrap = true
      vim.opt.conceallevel = 0
      vim.cmd.colorscheme("tokyonight")
    '';
    
    keymaps = ''
      vim.keymap.set("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
    '';
  };
  
  plugins = {
    rust-tools = ''
      return {
        "simrat39/rust-tools.nvim",
        ft = "rust",
        opts = {
          server = {
            on_attach = function(_, bufnr)
              -- Custom rust-analyzer setup
            end,
          },
        },
      }
    '';
  };
};
```

## How It Works

This flake:
- Tracks LazyVim releases automatically
- Pre-fetches all default LazyVim plugins through Nix
- Handles Nix-specific quirks (disables Mason.nvim, manages treesitter parsers)
- Provides a clean upgrade path as LazyVim evolves

## Differences from Regular LazyVim

- **No Mason.nvim**: LSP servers and tools are installed via `extraPackages`
- **Treesitter parsers**: Managed via `treesitterParsers` option
- **Plugin updates**: Happen through `nix flake update` instead of `:Lazy update`

## License

MIT