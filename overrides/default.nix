# Nix-specific overrides for LazyVim plugins
# These handle path issues, binary dependencies, and other Nix-specific quirks

{ pkgs }:

{
  # Telescope needs ripgrep and fd for file searching
  "telescope.nvim" = {
    dependencies = with pkgs; [ ripgrep fd ];
  };
  
  # Treesitter parsers are managed separately in Nix
  "nvim-treesitter" = {
    config = ''
      opts = function(_, opts)
        opts.ensure_installed = {}
        opts.auto_install = false
        return opts
      end
    '';
  };
  
  # Neo-tree needs some system utilities
  "neo-tree.nvim" = {
    dependencies = with pkgs; [ 
      # For file operations
      coreutils
      findutils
    ];
  };
  
  # Noice.nvim might need terminal utilities
  "noice.nvim" = {
    dependencies = with pkgs; [ ncurses ];
  };
  
  # Conform.nvim formatters need to be in PATH
  "conform.nvim" = {
    config = ''
      opts = function(_, opts)
        -- Formatters will be provided via extraPackages
        opts.formatters_by_ft = opts.formatters_by_ft or {}
        return opts
      end
    '';
  };
  
  # nvim-lint linters need to be in PATH  
  "nvim-lint" = {
    config = ''
      opts = function(_, opts)
        -- Linters will be provided via extraPackages
        return opts
      end
    '';
  };
  
  # Mason is completely disabled in Nix
  "mason.nvim" = {
    enabled = false;
  };
  
  "mason-lspconfig.nvim" = {
    enabled = false;
  };
  
  "mason-nvim-dap.nvim" = {
    enabled = false;
  };
  
  # Git-related plugins might need git in PATH
  "gitsigns.nvim" = {
    dependencies = with pkgs; [ git ];
  };
  
  "diffview.nvim" = {
    dependencies = with pkgs; [ git ];
  };
  
  "neogit" = {
    dependencies = with pkgs; [ git ];
  };
  
  "lazygit.nvim" = {
    dependencies = with pkgs; [ lazygit ];
  };
  
  # LSP configuration handled via extraPackages
  "nvim-lspconfig" = {
    config = ''
      opts = function(_, opts)
        -- LSP servers will be provided via extraPackages
        opts.servers = opts.servers or {}
        return opts
      end
    '';
  };
  
  # DAP adapters need to be in PATH
  "nvim-dap" = {
    config = ''
      opts = function(_, opts)
        -- Debug adapters will be provided via extraPackages
        return opts
      end
    '';
  };
  
  # Toggleterm might need shell utilities
  "toggleterm.nvim" = {
    dependencies = with pkgs; [ 
      bash
      coreutils
    ];
  };
}