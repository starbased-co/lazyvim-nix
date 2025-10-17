# Standalone LazyVim Configuration Builder
# Builds a standalone LazyVim configuration as a derivation that can be symlinked anywhere
{ pkgs, lib }:

{
  # Core configuration from module.nix internal variables
  lazyConfig,           # Generated lazy.nvim setup (string)
  devPath,              # Path to dev plugins (derivation)
  treesitterGrammars,   # Treesitter parser packages (derivation or null)

  # User configuration from cfg.config and cfg.plugins
  autocmds ? "",
  keymaps ? "",
  options ? "",
  plugins ? {},

  # Extras with custom config from extrasConfigFiles
  extrasConfigFiles ? {},

  # Output name for derivation
  name ? "lazyvim-config",
}:

pkgs.runCommand name {
  # Make lazyConfig available to builder
  passAsFile = [ "lazyConfig" ];
  inherit lazyConfig;
} ''
  # Create directory structure
  mkdir -p $out/lua/config
  mkdir -p $out/lua/plugins

  # Write init.lua (main entry point)
  cp $lazyConfigPath $out/init.lua

  # Link treesitter parsers if provided
  ${lib.optionalString (treesitterGrammars != null) ''
    mkdir -p $out/parser
    # Create symlinks for each parser
    if [ -d "${treesitterGrammars}/parser" ]; then
      for parser in ${treesitterGrammars}/parser/*; do
        if [ -e "$parser" ]; then
          ln -sf "$parser" $out/parser/$(basename "$parser")
        fi
      done
    fi
  ''}

  # Write user config files (lua/config/)
  ${lib.optionalString (autocmds != "") ''
    cat > $out/lua/config/autocmds.lua << 'AUTOCMDS_EOF'
-- User autocmds configured via Nix
${autocmds}
AUTOCMDS_EOF
  ''}

  ${lib.optionalString (keymaps != "") ''
    cat > $out/lua/config/keymaps.lua << 'KEYMAPS_EOF'
-- User keymaps configured via Nix
${keymaps}
KEYMAPS_EOF
  ''}

  ${lib.optionalString (options != "") ''
    cat > $out/lua/config/options.lua << 'OPTIONS_EOF'
-- User options configured via Nix
${options}
OPTIONS_EOF
  ''}

  # Write user plugin files (lua/plugins/)
  ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (name: content: ''
    cat > $out/lua/plugins/${name}.lua << 'PLUGIN_EOF'
-- Plugin configuration for ${name} (configured via Nix)
${content}
PLUGIN_EOF
  '') plugins)}

  # Write extras config override files (lua/plugins/extras-*.lua)
  ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (path: fileConfig: ''
    # Extract filename from path (e.g., "nvim/lua/plugins/extras-lang-python.lua" -> "extras-lang-python.lua")
    filename=$(basename "${path}")
    cat > $out/lua/plugins/$filename << 'EXTRAS_EOF'
${fileConfig.text}
EXTRAS_EOF
  '') extrasConfigFiles)}

  # Create marker file for validation
  echo "LazyVim standalone configuration built at: $(date)" > $out/.lazyvim-standalone

  # Verify structure
  echo "=== LazyVim Standalone Config Structure ==="
  ls -la $out/
  echo "=== Config Files ==="
  ls -la $out/lua/config/ 2>/dev/null || echo "No config files"
  echo "=== Plugin Files ==="
  ls -la $out/lua/plugins/ 2>/dev/null || echo "No plugin files"
  echo "=== Treesitter Parsers ==="
  ls -la $out/parser/ 2>/dev/null || echo "No parsers"
''
