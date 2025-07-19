# lazyvim-nix

A Nix flake for LazyVim that just works

## What is this?

This flake lets you use [LazyVim](https://www.lazyvim.org/) on NixOS with minimal configuration. It automatically manages plugins and provides the full LazyVim experience without manual maintenance.

## Quick Start

1. Add the flake to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    lazyvim.url = "github:pfassina/lazyvim-nix";
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

## Acknowledgments

This flake is heavily inspired by the setup from [@azuwis](https://github.com/azuwis). Thank you for the great foundation!

## License

MIT
