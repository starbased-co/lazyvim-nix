{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.lazyvim;

  # Load plugin data and mappings
  pluginData = pkgs.lazyvimPluginData or (builtins.fromJSON (builtins.readFile ./plugins.json));
  pluginMappings = pkgs.lazyvimPluginMappings or (import ./plugin-mappings.nix);

  # Load extras metadata
  extrasMetadata = pkgs.lazyvimExtrasMetadata or (import ./extras.nix);

  # Helper function to collect enabled extras
  getEnabledExtras = extrasConfig:
    let
      processCategory = categoryName: categoryExtras:
        let
          enabledInCategory = lib.filterAttrs (extraName: extraConfig:
            extraConfig.enable or false
          ) categoryExtras;
        in
          lib.mapAttrsToList (extraName: extraConfig:
            let
              metadata = extrasMetadata.${categoryName}.${extraName} or null;
            in
              if metadata != null then {
                inherit (metadata) name category import;
                config = extraConfig.config or "";
                hasConfig = (extraConfig.config or "") != "";
              } else
                null
          ) enabledInCategory;

      allCategories = lib.mapAttrsToList processCategory extrasConfig;
      flattenedExtras = lib.flatten allCategories;
      validExtras = lib.filter (x: x != null) flattenedExtras;
    in
      validExtras;

  # Get list of enabled extras
  enabledExtras = if cfg.enable then getEnabledExtras (cfg.extras or {}) else [];

  # Function to scan extras plugins - following the same pattern as scanUserPlugins
  scanExtrasPlugins = enabledExtrasFiles:
    let
      # Use a temporary LazyVim checkout - same pattern as the extraction scripts use
      scanResult = pkgs.runCommand "scan-extras-plugins" {
        buildInputs = [ pkgs.lua pkgs.git ];
      } ''
        # Clone LazyVim to get extras files - use git like other scripts
        git clone --depth 1 https://github.com/LazyVim/LazyVim /tmp/LazyVim

        # Copy our extraction script
        cp ${./scripts/extract-extras-plugins.lua} extract-extras-plugins.lua

        # Run the extraction
        lua extract-extras-plugins.lua \
          /tmp/LazyVim/lua/lazyvim/plugins/extras \
          $out \
          ${lib.concatStringsSep " " enabledExtrasFiles} || echo "[]" > $out
      '';

      extrasPluginsJson = builtins.readFile scanResult;
      extrasPluginsList = if extrasPluginsJson == "[]" then [] else builtins.fromJSON extrasPluginsJson;
    in
      extrasPluginsList;


  # Helper function to build a vim plugin from source
  buildVimPluginFromSource = pluginSpec:
    let
      owner = pluginSpec.owner or (builtins.elemAt (lib.splitString "/" pluginSpec.name) 0);
      repo = pluginSpec.repo or (builtins.elemAt (lib.splitString "/" pluginSpec.name) 1);
      versionInfo = pluginSpec.version_info or {};

      # Determine which version to build
      # Priority: lazyvim_version > tag > latest_version > commit
      rev = if versionInfo ? lazyvim_version && versionInfo.lazyvim_version != null && versionInfo.lazyvim_version != "*" then
              versionInfo.lazyvim_version
            else if versionInfo ? tag && versionInfo.tag != null then
              versionInfo.tag
            else if versionInfo ? latest_version && versionInfo.latest_version != null then
              versionInfo.latest_version
            else if versionInfo ? commit && versionInfo.commit != null && versionInfo.commit != "*" then
              versionInfo.commit
            else "HEAD";

      # SHA256 hash is required for fetchFromGitHub
      sha256 = versionInfo.sha256 or null;

      # For latest/HEAD, use fetchGit which doesn't require a hash
      # For pinned versions with sha256, use fetchFromGitHub
      src = if rev == "HEAD" || sha256 == null then
        builtins.fetchGit ({
          url = "https://github.com/${owner}/${repo}";
          shallow = true;
        } // lib.optionalAttrs (rev != "HEAD") {
          ref = rev;
        })
      else
        pkgs.fetchFromGitHub {
          inherit owner repo rev sha256;
        };
    in
      if owner != null && repo != null then
        pkgs.vimUtils.buildVimPlugin {
          pname = repo;
          version = rev;
          inherit src;
          doCheck = false;  # Disable require checks that may fail
          meta = {
            description = "LazyVim plugin: ${pluginSpec.name}";
            homepage = "https://github.com/${owner}/${repo}";
          };
        }
      else
        null;

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

  # Helper function to create dev path with proper symlinks for all plugins
  createDevPath = allPluginSpecs: allResolvedPlugins:
    let
      # Extract repository name from plugin spec (e.g., "owner/repo.nvim" -> "repo.nvim")
      getRepoName = specName:
        let parts = lib.splitString "/" specName;
        in if length parts == 2 then elemAt parts 1 else specName;

      # Separate multi-module plugins from regular plugins
      pluginWithType = lib.zipListsWith (spec: plugin:
        if plugin != null then
          let
            mapping = pluginMappings.${spec.name} or null;
            isMultiModule = mapping != null && builtins.isAttrs mapping && mapping ? module;
          in {
            spec = spec;
            plugin = plugin;
            isMultiModule = isMultiModule;
            linkName = if isMultiModule then mapping.module else getRepoName spec.name;
          }
        else null
      ) allPluginSpecs allResolvedPlugins;

      # Filter out null entries
      validPlugins = filter (p: p != null) pluginWithType;

      # Deduplicate multi-module plugins by module name
      deduplicatedPlugins =
        let
          # Group by link name
          grouped = lib.groupBy (p: p.linkName) validPlugins;
          # Take first entry for each unique link name
          deduplicated = lib.mapAttrsToList (linkName: plugins: lib.head plugins) grouped;
        in deduplicated;

      # Create symlink commands
      linkCommands = map (p: "ln -sf ${p.plugin} $out/${p.linkName}") deduplicatedPlugins;
    in
      pkgs.runCommand "lazyvim-dev-path" {} ''
        mkdir -p $out
        ${lib.concatStringsSep "\n" linkCommands}
      '';

  # Function to scan user plugins from LazyVim configuration
  scanUserPlugins = config_path:
    let
      # Use Nix to call the Lua scanner script
      scanResult = pkgs.runCommand "scan-user-plugins" {
        buildInputs = [ pkgs.lua pkgs.neovim ];
      } ''
        # Copy scanner script to build directory
        cp ${./scripts/scan-user-plugins.lua} scan-user-plugins.lua

        # Create a simple Lua runner script
        cat > run-scanner.lua << 'EOF'
        -- Initialize vim.loop for the scanner
        _G.vim = _G.vim or {}
        vim.loop = vim.loop or require('luv')

        -- Load the scanner
        local scanner = dofile('scan-user-plugins.lua')

        -- Scan for user plugins
        local user_plugins = scanner.scan_user_plugins("${config_path}")

        -- Output as JSON-like format for Nix to parse
        local function to_json_array(plugins)
          local result = "["
          for i, plugin in ipairs(plugins) do
            if i > 1 then result = result .. "," end
            result = result .. string.format(
              '{"name":"%s","owner":"%s","repo":"%s","source_file":"%s","user_plugin":true}',
              plugin.name, plugin.owner, plugin.repo, plugin.source_file
            )
          end
          result = result .. "]"
          return result
        end

        -- Write result
        local file = io.open("$out", "w")
        file:write(to_json_array(user_plugins))
        file:close()
        EOF

        # Run the scanner if config path exists
        if [ -d "${config_path}" ]; then
          lua run-scanner.lua 2>/dev/null || echo "[]" > $out
        else
          echo "[]" > $out
        fi
      '';
      userPluginsJson = builtins.readFile scanResult;
      userPluginsList = if userPluginsJson == "[]" then [] else builtins.fromJSON userPluginsJson;
    in
      userPluginsList;

  # Scan for user plugins from the default LazyVim config directory
  userPlugins = if cfg.enable then
    scanUserPlugins "${config.home.homeDirectory}/.config/nvim"
  else [];

  # Filter plugins by category: only build core plugins by default
  corePlugins = builtins.filter (p: p.is_core or false) (pluginData.plugins or []);

  # Get plugins from enabled extras only
  extrasPlugins =
    let
      # Get list of enabled extras files (e.g., ["extras.ai.copilot", "extras.lang.python"])
      enabledExtrasFiles = map (extra: "extras.${extra.category}.${extra.name}") enabledExtras;

      # Check if a plugin belongs to an enabled extra
      isExtraEnabled = plugin: builtins.elem (plugin.source_file or "") enabledExtrasFiles;

      # Get all non-core plugins (i.e., extras plugins)
      allExtrasPlugins = builtins.filter (p: !(p.is_core or false)) (pluginData.plugins or []);
    in
      # Only include extras that are enabled
      builtins.filter isExtraEnabled allExtrasPlugins;

  # Merge core plugins with enabled extras plugins and user plugins
  allPluginSpecs = corePlugins ++ extrasPlugins ++ userPlugins;

  # Note: Multi-module plugin expansion is handled in the final package building

  # Enhanced plugin resolver with version-aware strategy
  resolvePlugin = pluginSpec:
    let
      nixName = resolvePluginName pluginSpec.name;
      nixPlugin = pkgs.vimPlugins.${nixName} or null;
      versionInfo = pluginSpec.version_info or {};

      # Extract version information
      lazyvimVersion = versionInfo.lazyvim_version or null;
      lazyvimVersionType = versionInfo.lazyvim_version_type or null;
      latestVersion = versionInfo.latest_version or null;
      tagVersion = versionInfo.tag or null;
      commitVersion = versionInfo.commit or null;
      branchVersion = versionInfo.branch or null;
      nixpkgsVersion = if nixPlugin != null then
        nixPlugin.src.rev or nixPlugin.version or null
      else null;

      # Determine LazyVim-specified source requirements
      lazyvimRequiresBranch = lazyvimVersionType == "branch";
      lazyvimRequiresNoReleases = lazyvimVersion == false; # version = false
      lazyvimHasSpecificCommit = lazyvimVersionType == "commit";
      lazyvimHasSpecificTag = lazyvimVersionType == "tag";

      # Determine target version based on LazyVim specifications
      # Priority: respect LazyVim's exact specifications first
      targetVersion = if lazyvimVersion != null && lazyvimVersion != "*" && lazyvimVersion != false then
        lazyvimVersion
      else if tagVersion != null then
        tagVersion
      else if latestVersion != null then
        latestVersion
      else
        commitVersion;

      # Check if versions match (but respect LazyVim branch/version=false requirements)
      nixpkgsMatchesTarget =
        # Never use nixpkgs if LazyVim requires a specific branch
        if lazyvimRequiresBranch then false
        # Never use nixpkgs if LazyVim specifies version = false (no releases)
        else if lazyvimRequiresNoReleases then false
        # For other cases, check if versions match
        else targetVersion != null && nixpkgsVersion != null &&
             (targetVersion == nixpkgsVersion || targetVersion == "*");

      # Decision logic based on strategy
      useNixpkgs =
        if cfg.pluginSource == "latest" then
          # Strategy "latest": Follow LazyVim specifications exactly
          # Use nixpkgs only if it matches AND LazyVim doesn't require special handling
          nixpkgsMatchesTarget && !lazyvimRequiresBranch && !lazyvimRequiresNoReleases
        else  # cfg.pluginSource == "nixpkgs"
          # Strategy "nixpkgs": Prefer nixpkgs but respect LazyVim branch/version=false requirements
          if lazyvimRequiresBranch || lazyvimRequiresNoReleases then
            # LazyVim has specific source requirements, must build from source
            false
          else if targetVersion != null && targetVersion != "*" then
            # If we have a specific version, use nixpkgs only if it matches
            nixpkgsMatchesTarget
          else
            # No specific version required, use nixpkgs if available
            nixPlugin != null;

      # Build from source if we need a specific version not in nixpkgs
      needsSourceBuild = targetVersion != null && !useNixpkgs && versionInfo.sha256 != null;

      # Build source plugin with the target version
      sourcePlugin = if needsSourceBuild then
        buildVimPluginFromSource pluginSpec
      else null;

      # Final plugin selection
      finalPlugin =
        if useNixpkgs && nixPlugin != null then
          nixPlugin
        else if sourcePlugin != null then
          sourcePlugin
        else if nixPlugin != null then
          nixPlugin  # Fallback to nixpkgs even if version doesn't match
        else
          null;

      # Enhanced debug trace
      debugTrace =
        if builtins.elem pluginSpec.name ["LazyVim/LazyVim" "folke/lazy.nvim"] then
          builtins.trace "${pluginSpec.name}: Using ${
            if useNixpkgs then "nixpkgs (${if nixpkgsVersion != null then nixpkgsVersion else "unknown"})"
            else if sourcePlugin != null then "source (${if targetVersion != null then targetVersion else "latest"})"
            else "fallback nixpkgs"
          }"
        else
          (x: x);
    in
      debugTrace (
        if finalPlugin == null then
          builtins.trace "Warning: Could not resolve plugin ${pluginSpec.name}" null
        else
          finalPlugin
      );

  # Resolve all plugins using the smart resolver
  resolvedPlugins = map resolvePlugin allPluginSpecs;
  
  # Create the dev path with proper symlinks
  devPath = createDevPath allPluginSpecs resolvedPlugins;
  
  # Extract repository name from plugin spec (needed for config generation)
  getRepoName = specName:
    let parts = lib.splitString "/" specName;
    in if length parts == 2 then elemAt parts 1 else specName;
  
  # Generate dev plugin specs for available plugins
  devPluginSpecs = lib.zipListsWith (spec: plugin:
    if plugin != null &&
       spec.name != "nvim-treesitter/nvim-treesitter" &&
       spec.name != "nvim-treesitter/nvim-treesitter-textobjects" then
      ''{ "${getRepoName spec.name}", dev = true, pin = true },''
    else
      null
  ) allPluginSpecs resolvedPlugins;

  # Filter out null entries
  availableDevSpecs = filter (s: s != null) devPluginSpecs;

  # Generate extras import statements
  extrasImportSpecs = map (extra:
    ''{ import = "${extra.import}" },''
  ) enabledExtras;

  # Generate extras config override files for extras with custom config
  extrasWithConfig = filter (extra: extra.hasConfig) enabledExtras;

  extrasConfigFiles = lib.listToAttrs (map (extra:
    lib.nameValuePair
      "nvim/lua/plugins/extras-${extra.category}-${extra.name}.lua"
      {
        text = ''
          -- Extra configuration override for ${extra.category}/${extra.name} (configured via Nix)
          -- This file overrides the default configuration from the LazyVim extra
          return {
            ${extra.config}
          }
        '';
      }
  ) extrasWithConfig);

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
      checker = { enabled = false },  -- Disable update checker since Nix manages versions
      change_detection = { notify = false },  -- Disable config change notifications
      dev = {
        path = "${devPath}",
        patterns = {},  -- Don't automatically match, use explicit dev = true
        fallback = false,
      },
      spec = {
        { "LazyVim/LazyVim", import = "lazyvim.plugins", dev = true, pin = true },
        -- LazyVim extras
        ${concatStringsSep "\n        " extrasImportSpecs}
        -- Disable Mason.nvim in Nix environment
        { "mason-org/mason.nvim", enabled = false },
        { "mason-org/mason-lspconfig.nvim", enabled = false },
        { "jay-babu/mason-nvim-dap.nvim", enabled = false },
        -- Configure treesitter to work with Nix-managed parsers
        {
          "nvim-treesitter/nvim-treesitter",
          -- Parser compilation is skipped when using Nix
          build = false,
          opts = function(_, opts)
            opts.auto_install = false
            opts.ensure_installed = {}
            return opts
          end,
          config = function(_, opts)

            local TS = require("nvim-treesitter")
            local LazyVimUtil = require("lazyvim.util")

            -- Mock TS.get_installed to bypass the installation checks
            -- See nvim-treesitter/lua/nvim-treesitter/config.lua#L42-L58
            local _ts_install = TS.get_installed
            TS.get_installed = function()
              return {}
            end

            -- Mock LazyVimUtil.treesitter.get_installed() to populate M._installed
            -- from the buildtime parser list. This ensures M._installed is
            -- populated correctly for autocmd functionality
            -- See LazyVim/lua/lazyvim/util/treesitter.lua#L7-L17
            local _lazyvim_install = LazyVimUtil.treesitter.get_installed

            -- Nix-managed parser list (extracted from treesitterParsers option)
            local nix_parsers = { ${treesitterLangList} }

            LazyVimUtil.treesitter.get_installed = function(update)
              if update then
                LazyVimUtil.treesitter._installed = {}
                LazyVimUtil.treesitter._queries = {}
                for _, lang in ipairs(nix_parsers) do
                  LazyVimUtil.treesitter._installed[lang] = true
                end
              end
              return LazyVimUtil.treesitter._installed or {}
            end

            -- Find and call LazyVim's default config
            -- This will:
            -- 1. Pass the version check (TS.get_installed returns empty)
            -- 2. Setup treesitter with our opts
            -- 3. Skip parser installation (ensure_installed is empty)
            -- 4. Populate M._installed with Nix parsers (our LazyVim mock)
            -- 5. Create autocmds for highlighting, indents, folds
            local treesitter_plugins = require("lazyvim.plugins.treesitter")
            local config_fn = nil

            -- Search for first nvim-treesitter plugin spec by identifier
            for _, spec in ipairs(treesitter_plugins) do
              if spec[1] == "nvim-treesitter/nvim-treesitter" and
                 type(spec.config) == "function" then
                config_fn = spec.config
                break
              end
            end

            if not config_fn then
              error("Failed to find nvim-treesitter config in lazyvim.plugins.treesitter")
            else
              config_fn(_, opts)
            end

            -- Restore pre-mock references
            LazyVimUtil.treesitter.get_installed = _lazyvim_install
            if _ts_install then
              TS.get_installed = _ts_install
            else
              TS.get_installed = nil
            end
          end,
          dev = true,
          pin = true,
        },
        -- Mark available plugins as dev = true
        ${concatStringsSep "\n        " availableDevSpecs}
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
    
  '';

  # Extract language names from treesitter parser packages for Lua config
  treesitterLangNames = let
    extractLang = pkg:
      let
        pname = pkg.pname or "";
        # Remove "tree-sitter-" prefix to get language name
        lang = lib.removePrefix "tree-sitter-" pname;
      in
        # Only include if prefix was present (validates it's a treesitter parser)
        if lang != pname then lang else null;

    langs = map extractLang cfg.treesitterParsers;
  in
    lib.filter (l: l != null) langs;

  # Generate Lua array string for parser list
  treesitterLangList = lib.concatStringsSep ", " (map (l: ''"${l}"'') treesitterLangNames);

  # Treesitter configuration - using packages directly
  treesitterGrammars = let
    parsers = pkgs.symlinkJoin {
      name = "treesitter-parsers";
      paths = (pkgs.vimPlugins.nvim-treesitter.withPlugins (_: cfg.treesitterParsers)).dependencies;
    };
  in parsers;

in {
  options.programs.lazyvim = {
    enable = mkEnableOption "LazyVim - A Neovim configuration framework";

    pluginSource = mkOption {
      type = types.enum [ "latest" "nixpkgs" ];
      default = "latest";
      description = ''
        Plugin source strategy:
        - "latest": Use nixpkgs if it has the required version, otherwise build from source
        - "nixpkgs": Prefer nixpkgs versions, fallback to source if unavailable
      '';
    };

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
      type = types.listOf types.package;
      default = [];
      example = literalExpression ''
        with pkgs.tree-sitter-grammars; [
          # Minimal for LazyVim itself
          tree-sitter-lua
          tree-sitter-vim
          tree-sitter-query
          
          # Common languages
          tree-sitter-rust
          tree-sitter-go
          tree-sitter-typescript
          tree-sitter-tsx
          tree-sitter-python
        ]
      '';
      description = ''
        List of Treesitter parser packages to install.
        
        Empty by default - add parsers based on languages you use.
        These should be packages from pkgs.tree-sitter-grammars.
        
        NOTE: Parser compatibility issues may occur if there's a version mismatch
        between nvim-treesitter and the parsers. If you see "Invalid node type" 
        errors, try using a matching nixpkgs channel or pinning versions.
      '';
    };
    
    
    config = mkOption {
      type = types.submodule {
        options = {
          autocmds = mkOption {
            type = types.str;
            default = "";
            example = ''
              -- Auto-save on focus loss
              vim.api.nvim_create_autocmd("FocusLost", {
                command = "silent! wa",
              })
            '';
            description = ''
              Lua code for autocmds that will be written to lua/config/autocmds.lua.
              This file is loaded by LazyVim for user autocmd configurations.
            '';
          };
          
          keymaps = mkOption {
            type = types.str;
            default = "";
            example = ''
              -- Custom keymaps
              vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { desc = "Save file" })
              vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>", { desc = "Go to left window" })
            '';
            description = ''
              Lua code for keymaps that will be written to lua/config/keymaps.lua.
              This file is loaded by LazyVim for user keymap configurations.
            '';
          };
          
          options = mkOption {
            type = types.str;
            default = "";
            example = ''
              -- Custom vim options
              vim.opt.relativenumber = false
              vim.opt.wrap = true
              vim.opt.conceallevel = 0
            '';
            description = ''
              Lua code for vim options that will be written to lua/config/options.lua.
              This file is loaded by LazyVim for user option configurations.
            '';
          };
        };
      };
      default = {};
      description = ''
        LazyVim configuration files. These map to the lua/config/ directory structure
        and are loaded by LazyVim automatically.
      '';
    };
    
    extras = mkOption {
      type = types.attrsOf (types.attrsOf (types.submodule {
        options = {
          enable = mkEnableOption "this LazyVim extra";

          config = mkOption {
            type = types.str;
            default = "";
            description = ''
              Additional Lua configuration to merge into this extra.
              This will be used to override or extend the extra's default configuration.
            '';
          };
        };
      }));
      default = {};
      example = literalExpression ''
        {
          coding.yanky = {
            enable = true;
            config = '''
              opts = {
                highlight = { timer = 300 },
              }
            ''';
          };

          lang.nix = {
            enable = true;
            config = '''
              opts = {
                servers = {
                  nixd = {},
                },
              }
            ''';
          };

          editor.dial.enable = true;
        }
      '';
      description = ''
        LazyVim extras to enable. Extras provide additional plugins and configurations
        for specific languages, features, or tools.

        Each extra can be enabled with `enable = true` and optionally configured with
        custom Lua code in the `config` field.
      '';
    };

    plugins = mkOption {
      type = types.attrsOf types.str;
      default = {};
      example = literalExpression ''
        {
          custom-theme = '''
            return {
              "folke/tokyonight.nvim",
              opts = {
                style = "night",
                transparent = true,
              },
            }
          ''';

          lsp-config = '''
            return {
              "neovim/nvim-lspconfig",
              opts = function(_, opts)
                opts.servers.rust_analyzer = {
                  settings = {
                    ["rust-analyzer"] = {
                      checkOnSave = {
                        command = "clippy",
                      },
                    },
                  },
                }
              end,
            }
          ''';
        }
      '';
      description = ''
        Plugin configuration files. Each key becomes a file lua/plugins/{key}.lua
        with the corresponding Lua code. These files are automatically loaded by LazyVim.
      '';
    };

    standalone = mkOption {
      type = types.submodule {
        options = {
          enable = mkEnableOption "standalone mode";

          outputName = mkOption {
            type = types.str;
            default = "lazyvim-config";
            description = ''
              Name of the output derivation.
              Will be available in home.packages under this name.
            '';
          };
        };
      };
      default = { enable = false; };
      description = ''
        Build LazyVim configuration as a standalone derivation instead of
        installing to ~/.config/nvim via home-manager.

        When enabled:
        - Configuration is built as a derivation in the Nix store
        - Available via programs.lazyvim.finalConfig
        - Does NOT create files in ~/.config/nvim
        - Useful for testing, CI/CD, or project-local configurations

        Example usage:
          programs.lazyvim = {
            enable = true;
            standalone.enable = true;
            # ... rest of config ...
          };

          # Access the standalone config:
          config.programs.lazyvim.finalConfig
      '';
    };

    finalConfig = mkOption {
      type = types.nullOr types.package;
      default = null;
      internal = true;
      description = ''
        The built standalone LazyVim configuration derivation.
        Only available when standalone.enable = true.
        Can be symlinked to any directory for project-local configs.
      '';
    };
  };
  
  config = mkIf cfg.enable (
    if cfg.standalone.enable then {
      # STANDALONE MODE: Build configuration as derivation

      # Build the standalone config
      programs.lazyvim.finalConfig = pkgs.callPackage ./lib/build-standalone.nix {} {
        inherit lazyConfig devPath treesitterGrammars extrasConfigFiles;
        autocmds = cfg.config.autocmds;
        keymaps = cfg.config.keymaps;
        options = cfg.config.options;
        plugins = cfg.plugins;
        name = cfg.standalone.outputName;
      };

      # Still configure neovim with required packages
      programs.neovim = {
        enable = true;
        package = pkgs.neovim-unwrapped;

        withNodeJs = true;
        withPython3 = true;
        withRuby = false;

        extraPackages = cfg.extraPackages ++ (with pkgs; [
          git
          ripgrep
          fd
        ]);

        plugins = [ pkgs.vimPlugins.lazy-nvim ];
      };
    } else {
      # NORMAL MODE: Use home-manager xdg.configFile (existing behavior)

      programs.neovim = {
        enable = true;
        package = pkgs.neovim-unwrapped;

        withNodeJs = true;
        withPython3 = true;
        withRuby = false;

        extraPackages = cfg.extraPackages ++ (with pkgs; [
          git
          ripgrep
          fd
        ]);

        plugins = [ pkgs.vimPlugins.lazy-nvim ];
      };

      xdg.configFile = {
        "nvim/init.lua".text = lazyConfig;

        "nvim/parser" = mkIf (cfg.treesitterParsers != []) {
          source = "${treesitterGrammars}/parser";
        };

        "nvim/lua/config/autocmds.lua" = mkIf (cfg.config.autocmds != "") {
          text = ''
            -- User autocmds configured via Nix
            ${cfg.config.autocmds}
          '';
        };

        "nvim/lua/config/keymaps.lua" = mkIf (cfg.config.keymaps != "") {
          text = ''
            -- User keymaps configured via Nix
            ${cfg.config.keymaps}
          '';
        };

        "nvim/lua/config/options.lua" = mkIf (cfg.config.options != "") {
          text = ''
            -- User options configured via Nix
            ${cfg.config.options}
          '';
        };

      }
      // (lib.mapAttrs' (name: content:
        lib.nameValuePair "nvim/lua/plugins/${name}.lua" {
          text = ''
            -- Plugin configuration for ${name} (configured via Nix)
            ${content}
          '';
        }
      ) cfg.plugins)
      // extrasConfigFiles;
    }
  );
}
