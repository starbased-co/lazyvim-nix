# Simple test configuration
{ pkgs ? import <nixpkgs> {} }:

let
  home-manager = builtins.fetchTarball {
    url = "https://github.com/nix-community/home-manager/archive/master.tar.gz";
  };
  
  hmLib = import "${home-manager}/modules" {
    inherit pkgs;
    configuration = { config, lib, ... }: {
      imports = [ ./module.nix ];
      
      programs.lazyvim = {
        enable = true;
        
        extraPackages = with pkgs; [
          lua-language-server
          ripgrep
          fd
        ];
        
        treesitterParsers = [
          "lua"
          "nix"
        ];
        
        settings = {
          colorscheme = "tokyonight";
        };
      };
      
      home.username = "testuser";
      home.homeDirectory = "/home/testuser";
      home.stateVersion = "23.11";
    };
  };
  
in hmLib.config