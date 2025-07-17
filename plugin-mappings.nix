# Mappings from LazyVim plugin names to nixpkgs vimPlugins names
# This file handles the cases where automatic name resolution fails

{
  # Core LazyVim plugins
  "LazyVim/LazyVim" = "LazyVim";
  "folke/lazy.nvim" = "lazy-nvim";
  
  # Folke's plugins (common pattern: plugin.nvim -> plugin-nvim)
  "folke/tokyonight.nvim" = "tokyonight-nvim";
  "folke/which-key.nvim" = "which-key-nvim";
  "folke/trouble.nvim" = "trouble-nvim";
  "folke/todo-comments.nvim" = "todo-comments-nvim";
  "folke/noice.nvim" = "noice-nvim";
  "folke/flash.nvim" = "flash-nvim";
  "folke/neodev.nvim" = "neodev-nvim";
  "folke/neoconf.nvim" = "neoconf-nvim";
  "folke/persistence.nvim" = "persistence-nvim";
  
  # Telescope ecosystem
  "nvim-telescope/telescope.nvim" = "telescope-nvim";
  "nvim-telescope/telescope-fzf-native.nvim" = "telescope-fzf-native-nvim";
  
  # Treesitter
  "nvim-treesitter/nvim-treesitter" = "nvim-treesitter";
  "nvim-treesitter/nvim-treesitter-textobjects" = "nvim-treesitter-textobjects";
  "nvim-treesitter/nvim-treesitter-context" = "nvim-treesitter-context";
  
  # LSP and completion
  "neovim/nvim-lspconfig" = "nvim-lspconfig";
  "hrsh7th/nvim-cmp" = "nvim-cmp";
  "hrsh7th/cmp-nvim-lsp" = "cmp-nvim-lsp";
  "hrsh7th/cmp-buffer" = "cmp-buffer";
  "hrsh7th/cmp-path" = "cmp-path";
  "saadparwaiz1/cmp_luasnip" = "cmp_luasnip";
  "L3MON4D3/LuaSnip" = "luasnip";
  "rafamadriz/friendly-snippets" = "friendly-snippets";
  
  # Mason (disabled in Nix, but mapping for completeness)
  "williamboman/mason.nvim" = "mason-nvim";
  "williamboman/mason-lspconfig.nvim" = "mason-lspconfig-nvim";
  "jay-babu/mason-nvim-dap.nvim" = "mason-nvim-dap";
  
  # UI plugins
  "nvim-lualine/lualine.nvim" = "lualine-nvim";
  "akinsho/bufferline.nvim" = "bufferline-nvim";
  "lukas-reineke/indent-blankline.nvim" = "indent-blankline-nvim";
  "echasnovski/mini.indentscope" = { package = "mini-nvim"; module = "mini.indentscope"; };
  "rcarriga/nvim-notify" = "nvim-notify";
  "stevearc/dressing.nvim" = "dressing-nvim";
  "akinsho/toggleterm.nvim" = "toggleterm-nvim";
  
  # File management
  "nvim-neo-tree/neo-tree.nvim" = "neo-tree-nvim";
  "nvim-tree/nvim-web-devicons" = "nvim-web-devicons";
  "MunifTanjim/nui.nvim" = "nui-nvim";
  
  # Git
  "lewis6991/gitsigns.nvim" = "gitsigns-nvim";
  "sindrets/diffview.nvim" = "diffview-nvim";
  "TimUntersberger/neogit" = "neogit";
  "kdheepak/lazygit.nvim" = "lazygit-nvim";
  
  # Editing support
  "echasnovski/mini.ai" = { package = "mini-nvim"; module = "mini.ai"; };
  "echasnovski/mini.pairs" = { package = "mini-nvim"; module = "mini.pairs"; };
  "echasnovski/mini.surround" = { package = "mini-nvim"; module = "mini.surround"; };
  "echasnovski/mini.comment" = { package = "mini-nvim"; module = "mini.comment"; };
  "echasnovski/mini.bufremove" = { package = "mini-nvim"; module = "mini.bufremove"; };
  "JoosepAlviste/nvim-ts-context-commentstring" = "nvim-ts-context-commentstring";
  
  # Formatting and linting
  "stevearc/conform.nvim" = "conform-nvim";
  "mfussenegger/nvim-lint" = "nvim-lint";
  
  # DAP (Debug Adapter Protocol)
  "mfussenegger/nvim-dap" = "nvim-dap";
  "rcarriga/nvim-dap-ui" = "nvim-dap-ui";
  "theHamsta/nvim-dap-virtual-text" = "nvim-dap-virtual-text";
  
  # Testing
  "nvim-neotest/neotest" = "neotest";
  "nvim-neotest/neotest-go" = "neotest-go";
  "nvim-neotest/neotest-python" = "neotest-python";
  "nvim-neotest/neotest-plenary" = "neotest-plenary";
  "nvim-neotest/neotest-vim-test" = "neotest-vim-test";
  
  # Colorschemes
  "catppuccin/nvim" = "catppuccin-nvim";
  "rebelot/kanagawa.nvim" = "kanagawa-nvim";
  "EdenEast/nightfox.nvim" = "nightfox-nvim";
  "rose-pine/neovim" = "rose-pine";
  
  # Dependencies
  "nvim-lua/plenary.nvim" = "plenary-nvim";
  
  # Language specific
  "simrat39/rust-tools.nvim" = "rust-tools-nvim";
  "akinsho/flutter-tools.nvim" = "flutter-tools-nvim";
  "jose-elias-alvarez/typescript.nvim" = "typescript-nvim";
  "b0o/SchemaStore.nvim" = "SchemaStore-nvim";
  
  # Misc
  "dstein64/vim-startuptime" = "vim-startuptime";
  "kevinhwang91/nvim-ufo" = "nvim-ufo";
  "kevinhwang91/promise-async" = "promise-async";
  "Wansmer/treesj" = "treesj";
  "cshuaimin/ssr.nvim" = "ssr-nvim";
  "smjonas/inc-rename.nvim" = "inc-rename-nvim";
  "windwp/nvim-autopairs" = "nvim-autopairs";
  "windwp/nvim-ts-autotag" = "nvim-ts-autotag";
  "RRethy/vim-illuminate" = "vim-illuminate";
  "nvimdev/dashboard-nvim" = "dashboard-nvim";
  "goolord/alpha-nvim" = "alpha-nvim";
}