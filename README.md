# lazyvim-nix

A bleeding edge Nix flake for [LazyVim](https://www.lazyvim.org/) that automatically tracks LazyVim releases and provides zero-configuration setup for NixOS and home-manager users.

**🚀 Always up-to-date**: Automatically tracks LazyVim releases and uses the latest plugin versions at the time of each LazyVim release.

[![Documentation](https://img.shields.io/badge/docs-wiki-blue)](https://github.com/pfassina/lazyvim-nix/wiki)

## Quick Start

Add to your flake inputs:

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

Enable in your home-manager configuration:

```nix
{
  imports = [ lazyvim.homeManagerModules.default ];
  programs.lazyvim.enable = true;
}
```

That's it! Open `nvim` and enjoy LazyVim.

## Basic Configuration

### Language Support

```nix
programs.lazyvim = {
  enable = true;

  extras = {
    lang.nix.enable = true;
    lang.python.enable = true;
  };

  # Required for syntax highlighting
  treesitterParsers = with pkgs.tree-sitter-grammars; [
    tree-sitter-nix
    tree-sitter-python
  ];

  # Language servers, formatters, linters (since Mason is disabled)
  extraPackages = with pkgs; [
    nixd       # Nix LSP
    pyright    # Python LSP
    alejandra  # Nix formatter
  ];
};
```

**Note:** LazyVim extras install Neovim plugins (LSP configs, syntax highlighting) but NOT the actual language tools (LSP servers, formatters, linters). You must provide these via `extraPackages`.

### Custom Configuration

```nix
programs.lazyvim = {
  enable = true;

  config = {
    options = ''
      vim.opt.relativenumber = false
      vim.opt.wrap = true
    '';

    keymaps = ''
      vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save" })
    '';
  };

  plugins = {
    colorscheme = ''
      return {
        "catppuccin/nvim",
        opts = { flavour = "mocha" },
      }
    '';
  };
};
```

### Configuration via Lua Modules

You can also organize your configuration in separate lua files using the included Lua module loader:

```nix
# modules/editors/neovim.nix
{
  pkgs,
  lib,
  lazyvim,
  ...
}:

let
  # Path to your Lua configuration directory
  luaPath = ../../config/nvim/lua;
  luaLoader = (pkgs.callPackage "${lazyvim}/lib/lua.nix" {
    inherit pkgs lib;
  }).moduleLoader luaPath;
  inherit (luaLoader) require importSpecs; #
in
{
  imports = [ lazyvim.homeManagerModules.default ];

  programs.lazyvim = {
    enable = true;

    # Load config from external Lua files
    config = importSpecs "config" [
      "options"    # Loads config/nvim/lua/config/options.lua
      "keymaps"    # Loads config/nvim/lua/config/keymaps.lua
      "autocmds"   # Loads config/nvim/lua/config/autocmds.lua
    ];

    # Load plugin overrides from external Lua files
    plugins =
      importSpecs "plugins" [
        "colorscheme"      # Loads config/nvim/lua/plugins/colorscheme.lua
        "nvim-treesitter"  # Loads config/nvim/lua/plugins/nvim-treesitter.lua
        "lsp"              # Loads config/nvim/lua/plugins/lsp.lua
      ]
      // {
        # Can still mix with inline configs
        custom-plugin = ''
          return {
            "author/plugin.nvim",
            opts = {},
          }
        '';
      };
  };
}
```

#### Example File Structure

```
config/nvim/lua/
├── config/
│   ├── options.lua
│   ├── keymaps.lua
│   └── autocmds.lua
└── plugins/
    ├── colorscheme.lua
    ├── nvim-treesitter.lua
    └── lsp.lua
```

The lua loader uses `package.searchpath` at build time to resolve module paths with the same logic as runtime Lua, ensuring consistency between Nix builds and Neovim's require system. Files are read during home-manager activation, so syntax errors are caught at build time rather than when starting Neovim.

## Key Features

- 🚀 **Always up-to-date** - Automatically tracks LazyVim releases with latest plugin versions
- ✅ **Zero-configuration setup** - Just enable and go
- 🤖 **Reproducible builds** - All plugins managed through Nix

## Documentation

📖 **[Getting Started](https://github.com/pfassina/lazyvim-nix/wiki/Getting-Started)** - Complete setup guide

⚙️ **[Configuration Reference](https://github.com/pfassina/lazyvim-nix/wiki/Configuration-Reference)** - All available options

🎯 **[LazyVim Extras](https://github.com/pfassina/lazyvim-nix/wiki/LazyVim-Extras)** - Language and feature support

🏗️ **[Architecture](https://github.com/pfassina/lazyvim-nix/wiki/Architecture-and-How-It-Works)** - How it works under the hood

🚨 **[Troubleshooting](https://github.com/pfassina/lazyvim-nix/wiki/Troubleshooting)** - Common issues and solutions

## Updating

```bash
nix flake update          # Update to latest LazyVim
home-manager switch       # Apply changes
```

## Acknowledgments

- [LazyVim](https://github.com/LazyVim/LazyVim) by [@folke](https://github.com/folke)
- Inspired by [@azuwis](https://github.com/azuwis)'s Nix setup

## License

MIT
