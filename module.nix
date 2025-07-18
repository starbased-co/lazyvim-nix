{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.lazyvim;
  
  # Load plugin data and mappings
  pluginData = pkgs.lazyvimPluginData or (builtins.fromJSON (builtins.readFile ./plugins.json));
  pluginMappings = pkgs.lazyvimPluginMappings or (import ./plugin-mappings.nix);
  pluginOverrides = pkgs.lazyvimOverrides or (import ./overrides/default.nix { inherit pkgs; });
  
  # Helper function to resolve plugin names
  resolvePluginName = lazyName:
    let
      mapping = pluginMappings.${lazyName} or null;
    in
      if mapping == null then
        # Try automatic resolution
        let
          parts = lib.splitString "/" lazyName;
          repoName = if length parts == 2 then elemAt parts 1 else lazyName;
          # Convert repo-name to repo_name and repo.nvim to repo-nvim
          nixName = lib.replaceStrings ["-" "."] ["_" "-"] repoName;
        in nixName
      else if builtins.isString mapping then
        mapping
      else
        mapping.package;
  
  # Helper function to detect multi-module plugins
  detectMultiModulePlugins = pluginSpecs:
    let
      isMultiModulePlugin = pluginSpec:
        let
          mapping = pluginMappings.${pluginSpec.name} or null;
        in
          mapping != null && builtins.isAttrs mapping && mapping ? module;
    in
      filter isMultiModulePlugin pluginSpecs;
  
  # Helper function to expand multi-module plugins into individual entries
  expandMultiModulePlugins = pluginSpecs:
    let
      multiModulePlugins = detectMultiModulePlugins pluginSpecs;
      regularPlugins = filter (spec: 
        let
          mapping = pluginMappings.${spec.name} or null;
        in
          mapping == null || builtins.isString mapping || !(mapping ? module)
      ) pluginSpecs;
      
      # Create individual entries for multi-module plugins
      expandedEntries = map (pluginSpec:
        let
          mapping = pluginMappings.${pluginSpec.name};
          nixName = resolvePluginName pluginSpec.name;
          plugin = pkgs.vimPlugins.${nixName} or null;
        in
          if plugin == null then
            null
          else
            {
              name = mapping.module;  # Use module name for LazyVim to find
              nixName = nixName;
              plugin = plugin;
              originalSpec = pluginSpec;
            }
      ) multiModulePlugins;
    in
      {
        regular = regularPlugins;
        expanded = filter (entry: entry != null) expandedEntries;
      };

  # Helper function to create dev path with proper symlinks for all plugins
  createDevPath = allPluginSpecs: allResolvedPlugins: extraSpecs: extraPlugins:
    let
      # Extract repository name from plugin spec (e.g., "owner/repo.nvim" -> "repo.nvim")
      getRepoName = specName:
        let parts = lib.splitString "/" specName;
        in if length parts == 2 then elemAt parts 1 else specName;
      
      # Create symlinks using the repository names that LazyVim expects
      mainLinks = lib.zipListsWith (spec: plugin:
        if plugin != null then
          let repoName = getRepoName spec.name;
          in "ln -sf ${plugin} $out/${repoName}"
        else
          null
      ) allPluginSpecs allResolvedPlugins;
      
      # Create symlinks for extra plugins
      extraLinks = lib.zipListsWith (spec: plugin:
        if plugin != null then
          let repoName = getRepoName spec.name;
          in "ln -sf ${plugin} $out/${repoName}"
        else
          null
      ) extraSpecs extraPlugins;
      
      # Filter out null entries and combine
      validLinks = filter (link: link != null) (mainLinks ++ extraLinks);
    in
      pkgs.runCommand "lazyvim-dev-path" {} ''
        mkdir -p $out
        ${lib.concatStringsSep "\n" validLinks}
      '';

  # Expand multi-module plugins and separate regular plugins
  pluginSeparation = expandMultiModulePlugins (pluginData.plugins or []);
  
  # Build the list of all plugins from plugins.json
  allPluginSpecs = pluginData.plugins or [];
  
  # Resolve all plugins to their nixpkgs equivalents
  resolvedPlugins = map (pluginSpec:
    let
      nixName = resolvePluginName pluginSpec.name;
      plugin = pkgs.vimPlugins.${nixName} or null;
    in
      if plugin == null then
        builtins.trace "Warning: Could not find plugin ${pluginSpec.name} (tried ${nixName})" null
      else
        plugin
  ) allPluginSpecs;
  
  # Resolve extra plugins from user configuration
  resolvedExtraPlugins = map (pluginSpec:
    let
      nixName = resolvePluginName pluginSpec.name;
      plugin = pkgs.vimPlugins.${nixName} or null;
    in
      if plugin == null then
        builtins.trace "Warning: Could not find extra plugin ${pluginSpec.name} (tried ${nixName})" null
      else
        plugin
  ) (cfg.extraPlugins or []);
  
  # Create the dev path with proper symlinks
  devPath = createDevPath allPluginSpecs resolvedPlugins (cfg.extraPlugins or []) resolvedExtraPlugins;
  
  # Generate lazy.nvim configuration
  lazyConfig = ''
    -- LazyVim Nix Configuration
    -- This file is auto-generated by the lazyvim-nix flake
    
    local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
    if not vim.loop.fs_stat(lazypath) then
      vim.fn.system({
        "git",
        "clone",
        "--filter=blob:none",
        "https://github.com/folke/lazy.nvim.git",
        "--branch=stable",
        lazypath,
      })
    end
    vim.opt.rtp:prepend(lazypath)
    
    -- Configure lazy.nvim to use pre-fetched plugins
    require("lazy").setup({
      defaults = { lazy = true },
      dev = {
        path = "${devPath}",
        patterns = { "." },  -- Match all plugins in the dev path
        fallback = false,
      },
      spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins", dev = true },
        -- Disable Mason.nvim in Nix environment
        { "williamboman/mason.nvim", enabled = false },
        { "williamboman/mason-lspconfig.nvim", enabled = false },
        { "jay-babu/mason-nvim-dap.nvim", enabled = false },
        -- Disable treesitter auto-install - simple approach like your old config
        { 
          "nvim-treesitter/nvim-treesitter", 
          opts = function(_, opts)
            opts.ensure_installed = {}
          end,
          dev = true,
        },
        -- User plugins
        { import = "plugins" },
      },
      performance = {
        rtp = {
          disabled_plugins = {
            "gzip",
            "matchit",
            "matchparen",
            "netrwPlugin",
            "tarPlugin",
            "tohtml",
            "tutor",
            "zipPlugin",
          },
        },
      },
    })
    
    -- Apply user settings
    ${optionalString (cfg.settings != {}) ''
      -- User settings
      ${if cfg.settings ? colorscheme && cfg.settings.colorscheme != null then "vim.cmd.colorscheme('${cfg.settings.colorscheme}')" else ""}
      ${optionalString (cfg.settings ? options) (
        concatStringsSep "\n" (mapAttrsToList (name: value: 
          "vim.opt.${name} = ${if isBool value then (if value then "true" else "false") else toString value}"
        ) cfg.settings.options)
      )}
    ''}
  '';
  
  # Treesitter configuration - exact same approach as your old implementation  
  treesitterGrammars = let
    parsers = pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (plugins: 
        map (name: pkgs.tree-sitter-grammars."tree-sitter-${name}" or 
          (builtins.trace "Warning: Treesitter parser '${name}' not found" null)
        ) (filter (p: p != null) cfg.treesitterParsers)
      )).dependencies;
    };
  in parsers;

in {
  options.programs.lazyvim = {
    enable = mkEnableOption "LazyVim - A Neovim configuration framework";
    
    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [];
      example = literalExpression ''
        with pkgs; [
          rust-analyzer
          gopls
          nodePackages.typescript-language-server
        ]
      '';
      description = ''
        Additional packages to be made available to LazyVim.
        This should include LSP servers, formatters, linters, and other tools.
      '';
    };
    
    treesitterParsers = mkOption {
      type = types.listOf types.str;
      default = [ "lua" "vim" "vimdoc" "query" "markdown" "markdown_inline" ];
      example = [ "rust" "go" "typescript" "tsx" "python" ];
      description = ''
        List of Treesitter parsers to install.
        Parser names should match those available in nixpkgs.
      '';
    };
    
    settings = mkOption {
      type = types.submodule {
        options = {
          colorscheme = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "catppuccin";
            description = "The colorscheme to use";
          };
          
          options = mkOption {
            type = types.attrsOf types.anything;
            default = {};
            example = {
              relativenumber = false;
              tabstop = 2;
              shiftwidth = 2;
            };
            description = "Vim options to set";
          };
        };
      };
      default = {};
      description = "LazyVim settings";
    };
    
    extraPlugins = mkOption {
      type = types.listOf types.attrs;
      default = [];
      example = literalExpression ''
        [
          {
            name = "github/copilot.vim";
            lazy = false;
          }
        ]
      '';
      description = ''
        Additional plugin specifications for lazy.nvim.
        These will be added to the spec after LazyVim's default plugins.
      '';
    };
  };
  
  config = mkIf cfg.enable {
    # Ensure neovim is enabled
    programs.neovim = {
      enable = true;
      package = pkgs.neovim-unwrapped;
      
      viAlias = true;
      vimAlias = true;
      vimdiffAlias = true;
      
      withNodeJs = true;
      withPython3 = true;
      withRuby = false;
      
      # Add all required packages
      extraPackages = cfg.extraPackages ++ (with pkgs; [
        # Required by LazyVim
        git
        ripgrep
        fd
        
        # Language servers and tools can be added by the user
      ]);
      
      # Add lazy.nvim as a plugin
      plugins = [ pkgs.vimPlugins.lazy-nvim ];
    };
    
    # Create LazyVim configuration
    xdg.configFile = {
      "nvim/init.lua".text = lazyConfig;
      
      # Link treesitter parsers - exact same approach as your old config
      "nvim/parser".source = "${treesitterGrammars}/parser";
      
      # Add extra plugin configurations if provided
      "nvim/lua/plugins/nix-extra.lua" = mkIf (cfg.extraPlugins != []) {
        text = let
          # Convert plugin specs to Lua format
          pluginToLua = plugin: 
            let
              # For lazy.nvim, the first element should be the plugin name
              name = plugin.name;
              otherAttrs = lib.filterAttrs (n: v: n != "name" && v != null) plugin;
              attrToLua = name: value:
                if value == true then "${name} = true"
                else if value == false then "${name} = false"
                else if builtins.isString value then ''${name} = "${value}"''
                else "${name} = ${toString value}";
              luaAttrs = lib.concatStringsSep ", " (lib.mapAttrsToList attrToLua otherAttrs);
            in
              if luaAttrs == "" then ''"${name}"''
              else ''{ "${name}", ${luaAttrs} }'';
          pluginsLua = lib.concatMapStringsSep ",\n  " pluginToLua cfg.extraPlugins;
        in ''
          -- Extra plugins configured via Nix
          return {
            ${pluginsLua}
          }
        '';
      };
    };
    
    # Set up environment
    home.sessionVariables = {
      EDITOR = "nvim";
    };
  };
}