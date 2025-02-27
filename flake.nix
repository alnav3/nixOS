{
  description = "Framework NixOS configuration | WIP to be generic";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Unstable Packages
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.11";

    # Disko
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Home Manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    hyprland.url = "github:hyprwm/Hyprland";

    # Zen browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # nixos hardware presets
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    stylix.url = "github:danth/stylix";
    # Sops-nix for encryption
    sops-nix.url = "github:Mic92/sops-nix/a4c33bfecb93458d90f9eb26f1cf695b47285243";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    posting-flake.url = "github:jorikvanveen/posting-flake";

    # deck experience on NixOS
    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    dotfiles = {
      url = "github:alnav3/dotfiles";
      flake = false;
    };

    tpm = {
      url = "github:tmux-plugins/tpm";
      flake = false;
    };

    rofi-wifi = {
      url = "github:zbaylin/rofi-wifi-menu";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    home-manager,
    dotfiles,
    nixos-hardware,
    sops-nix,
    ...
  } @ inputs: let
    hosts = [
      {
        name = "framework";
        system = "x86_64-linux";
        useHomeManager = true;
      }
      {
        name = "mjolnir";
        system = "x86_64-linux";
        useHomeManager = false;
      }
      {
        name = "node0";
        system = "x86_64-linux";
        useHomeManager = false;
      }

    ];
  in {
    nixosConfigurations = builtins.listToAttrs (map (host: {
        name = host.name;
        value = nixpkgs.lib.nixosSystem {
          specialArgs = {
            overlays = import ./overlays;
            inherit inputs dotfiles;
            meta = {hostname = host.name;};
            pkgs-stable = inputs.nixpkgs-stable.legacyPackages.${host.system};
            postingPkg = inputs.posting-flake.packages.${host.system}.posting;
            pkgs-unstable = inputs.nixpkgs.legacyPackages.${host.system};
          };
          system = host.system;
          modules =
            [
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
            ]
            ++ (
              if host.useHomeManager
              then [
                home-manager.nixosModules.home-manager
                {
                  home-manager.useUserPackages = true;
                  home-manager.users.alnav = import ./home.nix;
                  home-manager.backupFileExtension = "bak";
                  home-manager.extraSpecialArgs = {
                    inherit inputs;
                    meta = host;
                  };
                }
              ]
              else []
            )
            ++ (
              if host.name == "framework"
              then [
                # Deck SteamOS experience
                inputs.jovian-nixos.nixosModules.jovian

                # Ricing the nixOS way
                inputs.stylix.nixosModules.stylix
                nixos-hardware.nixosModules.framework-13-7040-amd
              ]
              else []
            );
        };
      })
      hosts
      ++ [
        {
          name = "isoInstaller";
          value = nixpkgs.lib.nixosSystem {
            modules = [
              ./iso.nix
            ];
            specialArgs = {
              inherit inputs;
            };
          };
        }
      ]);
  };
}
