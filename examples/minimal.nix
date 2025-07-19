# Minimal LazyVim configuration example
# This shows the absolute minimum needed to get LazyVim running
{...}: {
  # Import the LazyVim module
  imports = [
    # In a real flake, this would be:
    # inputs.lazyvim.homeManagerModules.default
    ../module.nix
  ];

  # Enable LazyVim with default settings
  programs.lazyvim = {
    enable = true;
  };
}

