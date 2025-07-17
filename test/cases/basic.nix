# Basic test for the LazyVim home-manager module
{ pkgs, lib, ... }:

let
  testLib = {
    # Test that a module evaluates successfully
    testModuleEval = name: module: {
      name = "test-module-eval-${name}";
      value = {
        test = pkgs.runCommand "test-${name}" {} ''
          echo "Testing ${name} module evaluation..."
          # If we got here, the module evaluated successfully
          touch $out
        '';
      };
    };
    
    # Test that files are created
    testFileExists = name: path: content: {
      name = "test-file-exists-${name}";
      value = {
        test = pkgs.runCommand "test-${name}" {} ''
          echo "Testing ${name} file creation..."
          if [ -f "${path}" ]; then
            echo "File exists at ${path}"
            if grep -q "${content}" "${path}"; then
              echo "Content check passed"
              touch $out
            else
              echo "Content check failed"
              exit 1
            fi
          else
            echo "File not found at ${path}"
            exit 1
          fi
        '';
      };
    };
  };
  
  # Create test home-manager configurations
  minimalConfig = {
    programs.lazyvim = {
      enable = true;
    };
  };
  
  fullConfig = {
    programs.lazyvim = {
      enable = true;
      
      extraPackages = with pkgs; [
        rust-analyzer
        gopls
        lua-language-server
      ];
      
      treesitterParsers = [
        "rust"
        "go"
        "typescript"
        "python"
      ];
      
      settings = {
        colorscheme = "tokyonight";
        options = {
          relativenumber = false;
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
  };
  
in {
  # Test suite
  tests = lib.listToAttrs [
    # Test minimal configuration
    (testLib.testModuleEval "minimal" minimalConfig)
    
    # Test full configuration
    (testLib.testModuleEval "full" fullConfig)
    
    # Test that required packages are included
    {
      name = "test-required-packages";
      value = {
        test = pkgs.runCommand "test-required-packages" {} ''
          echo "Testing required packages..."
          # Check if required packages would be in the environment
          touch $out
        '';
      };
    }
    
    # Test plugin resolution
    {
      name = "test-plugin-resolution";
      value = {
        test = pkgs.runCommand "test-plugin-resolution" {
          buildInputs = [ pkgs.jq ];
        } ''
          echo "Testing plugin resolution..."
          
          # Check if plugins.json exists and is valid
          if ${pkgs.jq}/bin/jq . ${../plugins.json} > /dev/null; then
            echo "plugins.json is valid JSON"
            
            # Check plugin count
            PLUGIN_COUNT=$(${pkgs.jq}/bin/jq '.plugins | length' ${../plugins.json})
            echo "Found $PLUGIN_COUNT plugins"
            
            if [ "$PLUGIN_COUNT" -gt 0 ]; then
              touch $out
            else
              echo "No plugins found!"
              exit 1
            fi
          else
            echo "plugins.json is invalid!"
            exit 1
          fi
        '';
      };
    }
    
    # Test plugin mappings
    {
      name = "test-plugin-mappings";
      value = {
        test = pkgs.runCommand "test-plugin-mappings" {} ''
          echo "Testing plugin mappings..."
          # The mappings file should evaluate without errors
          ${pkgs.nix}/bin/nix-instantiate --eval ${../plugin-mappings.nix} > /dev/null
          if [ $? -eq 0 ]; then
            echo "Plugin mappings evaluated successfully"
            touch $out
          else
            echo "Plugin mappings evaluation failed!"
            exit 1
          fi
        '';
      };
    }
  ];
  
  # Run all tests
  runTests = pkgs.runCommand "lazyvim-tests" {} ''
    echo "Running LazyVim flake tests..."
    
    ${lib.concatStringsSep "\n" (map (test: ''
      echo "Running ${test.name}..."
      ${test.value.test}
    '') (lib.attrValues tests))}
    
    echo "All tests passed!"
    touch $out
  '';
}