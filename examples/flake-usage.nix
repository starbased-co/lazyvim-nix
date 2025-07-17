# Example of how to use this flake in your NixOS/home-manager configuration

{
  description = "Example NixOS configuration with LazyVim";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Add the LazyVim flake
    lazyvim = {
      url = "github:your-username/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, lazyvim, ... }:
    let
      system = "x86_64-linux"; # or "aarch64-linux", "x86_64-darwin", "aarch64-darwin"
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      # NixOS configuration
      nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          # Your system configuration
          ./configuration.nix
          
          # Home-manager as a NixOS module
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            
            home-manager.users.myuser = { pkgs, ... }: {
              # Import the LazyVim module
              imports = [ lazyvim.homeManagerModules.default ];
              
              # Enable LazyVim
              programs.lazyvim = {
                enable = true;
                
                # Basic development setup
                extraPackages = with pkgs; [
                  # Your preferred language servers
                  lua-language-server
                  nodePackages.typescript-language-server
                  
                  # Essential tools
                  ripgrep
                  fd
                ];
                
                treesitterParsers = [
                  "lua"
                  "javascript"
                  "typescript"
                  "html"
                  "css"
                ];
                
                settings = {
                  colorscheme = "tokyonight";
                };
              };
              
              # Other home-manager configuration...
              home.stateVersion = "23.11";
            };
          }
        ];
      };
      
      # Standalone home-manager configuration
      homeConfigurations.myuser = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        
        modules = [
          # Import the LazyVim module
          lazyvim.homeManagerModules.default
          
          # Your home configuration
          ({ pkgs, ... }: {
            programs.lazyvim = {
              enable = true;
              
              # Minimal setup - LazyVim's defaults are pretty good!
              extraPackages = with pkgs; [
                # Add language servers as needed
                rust-analyzer
                gopls
              ];
              
              treesitterParsers = [
                "rust"
                "go"
              ];
            };
            
            home.username = "myuser";
            home.homeDirectory = "/home/myuser";
            home.stateVersion = "23.11";
          })
        ];
      };
    };
}