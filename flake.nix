{
  description = "Framework NixOS configuration | WIP to be generic";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";

    # Unstable Packages
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # Disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Zen browser
    zen-browser.url = "github:MarceColl/zen-browser-flake";

    # nixos hardware presets
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Sops-nix for encryption
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, nixpkgs, disko, home-manager, nixos-hardware, sops-nix, ... }@inputs: let

    hosts = [
      {
        name="framework";
        system="x86_64-linux";
        useHomeManager=true;
      }
    ];

  in {
    nixosConfigurations = builtins.listToAttrs (map (host: {
	  name = host.name;
	  value = nixpkgs.lib.nixosSystem {
        specialArgs = {
          inherit inputs;
          meta = { hostname = host.name; };
        };
        system = host.system;
        modules = [
          # NixOS encryption module
          sops-nix.nixosModules.sops
          # disko
	      disko.nixosModules.disko

          # System Specific
          ./machines/${host.name}/hardware-configuration.nix
          ./machines/${host.name}/disko-config.nix

          # General
	      ./configuration.nix

          # home-manager
        ] ++ (if host.useHomeManager then [
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.alnav = import ./home.nix;
            home-manager.extraSpecialArgs = {
              inherit inputs;
              meta = host;
            };
          }
        ] else []) ++ (if host.name == "framework" then [
            nixos-hardware.nixosModules.framework-13-7040-amd
        ] else []);
      };
    }) hosts);
  };
}
