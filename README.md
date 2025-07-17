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
  treesitterParsers = [
    "rust"
    "go" 
    "typescript"
    "tsx"
  ];
};
```

### Customizing LazyVim

```nix
programs.lazyvim = {
  enable = true;
  
  # LazyVim settings
  settings = {
    colorscheme = "catppuccin";
    options = {
      relativenumber = false;
      tabstop = 2;
    };
  };
  
  # Add extra plugins
  extraPlugins = [
    {
      name = "github/copilot.vim";
      lazy = false;
    }
  ];
};
```

### Using Your Own Plugin Configs

Place your custom plugin configurations in `~/.config/nvim/lua/plugins/` as you would with a standard LazyVim setup:

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
  
  settings = {
    colorscheme = "tokyonight";
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