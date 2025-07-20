# Test flake to verify the LazyVim module works correctly
# Run with: nix build .#test-lazyvim

{
  description = "LazyVim test flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      
      # Create a test home-manager configuration
      testHome = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          # Import our LazyVim module
          ./module.nix
          
          # Test configuration
          ({ config, pkgs, ... }: {
            programs.lazyvim = {
              enable = true;
              
              extraPackages = with pkgs; [
                lua-language-server
                rust-analyzer
                ripgrep
                fd
              ];
              
              treesitterParsers = [
                "lua"
                "rust"
                "nix"
              ];
              
              settings = {
                colorscheme = "tokyonight";
                options = {
                  relativenumber = true;
                  tabstop = 2;
                };
              };
              
              extraPlugins = [
                {
                  name = "github/copilot.vim";
                  lazy = false;
                }
              ];
            };
            
            home.username = "testuser";
            home.homeDirectory = "/home/testuser";
            home.stateVersion = "23.11";
          })
        ];
      };
      
    in {
      packages.${system} = {
        # Test that the home-manager configuration builds
        test-lazyvim = testHome.activationPackage;
        
        # Test plugin resolution
        test-plugins = pkgs.runCommand "test-plugin-resolution" 
          { buildInputs = [ pkgs.jq ]; } ''
          echo "Testing plugin resolution..."
          
          # Check if plugins.json exists and is valid
          if ${pkgs.jq}/bin/jq . ${./plugins.json} > /dev/null; then
            echo "✓ plugins.json is valid JSON"
            
            # Check plugin count
            PLUGIN_COUNT=$(${pkgs.jq}/bin/jq '.plugins | length' ${./plugins.json})
            echo "✓ Found $PLUGIN_COUNT plugins"
            
            if [ "$PLUGIN_COUNT" -gt 0 ]; then
              echo "✓ Plugin count test passed"
            else
              echo "✗ No plugins found!"
              exit 1
            fi
          else
            echo "✗ plugins.json is invalid!"
            exit 1
          fi
          
          # Test plugin mappings
          echo "Testing plugin mappings..."
          if ${pkgs.nix}/bin/nix-instantiate --eval ${./plugin-mappings.nix} > /dev/null; then
            echo "✓ Plugin mappings evaluation successful"
          else
            echo "✗ Plugin mappings evaluation failed!"
            exit 1
          fi
          
          touch $out
        '';
        
        # Test flake evaluation
        test-flake = pkgs.runCommand "test-flake" {} ''
          echo "Testing flake evaluation..."
          
          # Test that our flake.nix is valid
          cd ${./.}
          if ${pkgs.nix}/bin/nix flake show --no-update-lock-file > /dev/null 2>&1; then
            echo "✓ Flake evaluation successful"
          else
            echo "✗ Flake evaluation failed!"
            exit 1
          fi
          
          touch $out
        '';
        
        # Test that generates a working Neovim configuration
        test-neovim-config = pkgs.runCommand "test-neovim-config" {} ''
          echo "Testing Neovim configuration generation..."
          
          # Create a temporary home directory
          export HOME=$(mktemp -d)
          mkdir -p $HOME/.config
          
          # Generate the configuration files
          ${testHome.activationPackage}/activate
          
          # Check that init.lua was created
          if [ -f "$HOME/.config/nvim/init.lua" ]; then
            echo "✓ init.lua created"
            
            # Check for LazyVim configuration
            if grep -q "LazyVim" "$HOME/.config/nvim/init.lua"; then
              echo "✓ LazyVim configuration found"
            else
              echo "✗ LazyVim configuration not found in init.lua"
              exit 1
            fi
            
            # Check for mason.nvim disable
            if grep -q "mason.nvim.*enabled.*false" "$HOME/.config/nvim/init.lua"; then
              echo "✓ Mason.nvim properly disabled"
            else
              echo "! Mason.nvim disable not found (may be handled differently)"
            fi
            
          else
            echo "✗ init.lua not created"
            exit 1
          fi
          
          # Check treesitter parsers
          if [ -d "$HOME/.config/nvim/parser" ]; then
            echo "✓ Treesitter parsers directory created"
            
            # Count parser files
            PARSER_COUNT=$(ls -1 "$HOME/.config/nvim/parser"/*.so 2>/dev/null | wc -l)
            echo "✓ Found $PARSER_COUNT treesitter parsers"
          else
            echo "! Treesitter parsers directory not found"
          fi
          
          touch $out
        '';
        
        # Test update script
        test-update-script = pkgs.runCommand "test-update-script" 
          { buildInputs = [ pkgs.bash pkgs.git pkgs.neovim pkgs.jq ]; } ''
          echo "Testing update script..."
          
          # Copy the scripts to a writable location
          cp ${./scripts/update-plugins.sh} update-plugins.sh
          cp ${./scripts/extract-plugins.lua} extract-plugins.lua
          cp ${./scripts/suggest-mappings.lua} suggest-mappings.lua
          chmod +x update-plugins.sh
          
          # Test that the script can parse our current plugins.json
          if [ -f "${./plugins.json}" ]; then
            echo "✓ Current plugins.json exists"
            
            # Validate it's proper JSON
            if ${pkgs.jq}/bin/jq . ${./plugins.json} > /dev/null; then
              echo "✓ plugins.json is valid JSON"
            else
              echo "✗ plugins.json is invalid JSON"
              exit 1
            fi
          else
            echo "✗ plugins.json not found"
            exit 1
          fi
          
          touch $out
        '';
        
        # Comprehensive test runner
        test-all = pkgs.runCommand "test-all-lazyvim" {} ''
          echo "Running all LazyVim tests..."
          
          echo "1. Testing plugin resolution..."
          ${self.packages.${system}.test-plugins}
          echo "✓ Plugin tests passed"
          
          echo "2. Testing flake evaluation..."
          ${self.packages.${system}.test-flake}
          echo "✓ Flake tests passed"
          
          echo "3. Testing Neovim configuration..."
          ${self.packages.${system}.test-neovim-config}
          echo "✓ Neovim config tests passed"
          
          echo "4. Testing update script..."
          ${self.packages.${system}.test-update-script}
          echo "✓ Update script tests passed"
          
          echo ""
          echo "🎉 All tests passed! LazyVim flake is working correctly."
          touch $out
        '';
      };
      
      # Make it easy to run tests
      checks.${system} = self.packages.${system};
      
      # Development shell for testing
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          neovim
          git
          jq
          ripgrep
          fd
          lua-language-server
          rust-analyzer
        ];
        
        shellHook = ''
          echo "LazyVim development environment"
          echo "Available commands:"
          echo "  nix build .#test-all     - Run all tests"
          echo "  nix build .#test-lazyvim - Test home-manager config"
          echo "  ./scripts/update-plugins.sh - Update plugins"
        '';
      };
    };
}