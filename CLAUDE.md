# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **lazyvim-nix**, a Nix flake that provides LazyVim (a Neovim configuration framework) with zero-configuration setup for NixOS and home-manager users. The flake automatically manages LazyVim plugins through Nix, disables Mason.nvim, and handles Nix-specific quirks.

## Architecture

### Core Components

- **flake.nix**: Main flake definition with outputs for multiple systems
- **module.nix**: Home-manager module implementing `programs.lazyvim` options
- **plugins.json**: Generated list of LazyVim plugin specifications (auto-updated)
- **plugin-mappings.nix**: Manual mappings from LazyVim plugin names to nixpkgs vimPlugins
- **overrides/**: Nix package overrides for specific plugins

### Key Architecture Patterns

- Plugin resolution: LazyVim plugin names → nixpkgs vimPlugins via automatic resolution + manual mappings
- Treesitter management: Parsers installed via Nix instead of Mason
- LSP/tool management: Uses `extraPackages` instead of Mason.nvim
- Configuration generation: Creates `init.lua` and symlinks for plugin paths

## Common Development Tasks

### Testing
```bash
# Run full test suite
./test/test.sh

# Manual integration testing steps in docs/testing-guide.md
```

### Updating Plugins
```bash
# Update to latest LazyVim plugins
nix run . # Runs scripts/update-plugins.sh
# OR
./scripts/update-plugins.sh
```

### Flake Operations
```bash
# Show flake outputs
nix flake show

# Check flake
nix flake check

# Update flake inputs
nix flake update

# Build dev shell
nix develop
```

## Development Environment

The flake provides a dev shell with:
- neovim, lua, jq, git, ripgrep, fd

Enter with: `nix develop`

## Module Structure

The home-manager module (`module.nix`) provides these options:
- `programs.lazyvim.enable`: Enable LazyVim
- `programs.lazyvim.extraPackages`: LSP servers, formatters, tools
- `programs.lazyvim.treesitterParsers`: Treesitter parser list
- `programs.lazyvim.settings`: Colorscheme and vim options
- `programs.lazyvim.extraPlugins`: Additional lazy.nvim plugin specs

## Plugin System

1. **plugins.json**: Auto-generated from LazyVim specs by update script
2. **plugin-mappings.nix**: Manual mappings for plugins not auto-resolvable
3. **Automatic resolution**: Converts "owner/repo-name" → "repo_name" for nixpkgs lookup
4. **Overrides**: Special package handling in `overrides/default.nix`

## Important Notes

- Mason.nvim is disabled - all tools come from Nix
- Treesitter parsers managed via module options, not auto-install
- Plugin updates happen via `nix flake update`, not `:Lazy update`
- Configuration lives in `~/.config/nvim/` as normal LazyVim setup