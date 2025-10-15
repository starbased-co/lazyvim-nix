{ pkgs, lib }:

{
  # Lua module loader for build-time resolution of Lua files
  #
  # This provides utilities to load Lua modules from a directory at build time,
  # using the same search path logic as runtime Lua. This is useful for:
  # - Loading user plugin configurations from ~/.config/nvim/lua/plugins/
  # - Loading custom config files from ~/.config/nvim/lua/config/
  # - Ensuring consistent module resolution between Nix build and runtime
  moduleLoader =
    luaPath:
    let
      searchPath = "${luaPath}/?.lua;${luaPath}/?/init.lua";
    in
    {
      # Resolve Lua module path using package.searchpath at build time
      # This guarantees we use the exact same resolution logic as runtime
      #
      # Args:
      #   module: Lua module name (e.g., "config.options")
      #
      # Returns:
      #   Absolute path to the resolved Lua module file
      search =
        module:
        let
          modulePath = builtins.readFile (
            pkgs.runCommand "package-searchpath-${module}" { } ''
              ${pkgs.luajit}/bin/luajit - > $out <<'EOF'
              local path = package.searchpath("${module}", "${searchPath}")
              if path then
                io.write(path)
              else
                error("Module '${module}' not found in search path: ${searchPath}")
              end
              EOF
            ''
          );
        in
        lib.strings.removeSuffix "\n" modulePath;

      # Load Lua module content by resolving path and reading file
      #
      # Args:
      #   module: Lua module name (e.g., "config.options")
      #
      # Returns:
      #   String content of the Lua module file
      require =
        module:
        let
          luaLib = (pkgs.callPackage ./lua.nix { inherit pkgs lib; }).moduleLoader luaPath;
        in
        builtins.readFile (luaLib.search module);

      # Load multiple modules with a prefix
      #
      # Args:
      #   prefix: Module prefix (e.g., "plugins")
      #   modules: List of module names (e.g., ["colorscheme" "mason"])
      #
      # Returns:
      #   Attribute set of module names to their contents
      #   { colorscheme = <contents>; mason = <contents>; }
      importSpecs =
        prefix: modules:
        let
          luaLib = (pkgs.callPackage ./lua.nix { inherit pkgs lib; }).moduleLoader luaPath;
        in
        lib.listToAttrs (
          map (name: {
            inherit name;
            value = luaLib.require "${prefix}.${name}";
          }) modules
        );
    };
}
