{
  description = "Framework NixOS configuration | WIP to be generic";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Unstable Packages
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

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

    # losless-frame generation
    lsfg-vk-flake.url = "github:pabloaul/lsfg-vk-flake/main";
    lsfg-vk-flake.inputs.nixpkgs.follows = "nixpkgs";

    # stylix
    stylix.url = "github:danth/stylix";

    # Sops-nix for encryption
    sops-nix.url = "github:Mic92/sops-nix/a4c33bfecb93458d90f9eb26f1cf695b47285243";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    posting-flake.url = "github:jorikvanveen/posting-flake";

    # system-bridge
    system-bridge-nix = {
        url = "github:alnav3/system-bridge-nix";
        inputs.nixpkgs.follows = "nixpkgs";
    };

    # deck experience on NixOS
    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # flatpak packages installed declaratively
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0";

    dotfiles = {
      url = "git+file:./dotfiles";
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

    hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";

    # NixOS-WSL
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    nixos-wsl.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    home-manager,
    dotfiles,
    nixos-hardware,
    sops-nix,
    nix-flatpak,
    hyprdynamicmonitors,
    ...
  } @ inputs: let
    hosts = [
      {
        name = "framework";
        system = "x86_64-linux";
        useHomeManager = true;
        isWsl = false;
      }
      {
        name = "mjolnir";
        system = "x86_64-linux";
        useHomeManager = true;
        isWsl = false;
      }
      {
        name = "node0";
        system = "x86_64-linux";
        useHomeManager = true;
        isWsl = false;
      }
      {
        name = "wsl";
        system = "x86_64-linux";
        useHomeManager = true;
        isWsl = true;
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
          modules = [
              # NixOS encryption module
              sops-nix.nixosModules.sops
              nix-flatpak.nixosModules.nix-flatpak
            ]
            ++ (
              if host.isWsl
              then [
                # WSL: self-contained machine config (includes nixos-wsl module)
                ./machines/${host.name}/configuration.nix
                ./machines/${host.name}/hardware-configuration.nix
              ]
              else [
                # disko
                disko.nixosModules.disko

                # System Specific
                ./machines/${host.name}/hardware-configuration.nix
                ./machines/${host.name}/disko-config.nix

                # General
                ./configuration.nix
              ]
            )
            ++ (
              if host.useHomeManager && (host.name == "mjolnir" || host.name == "node0")
              then [
                home-manager.nixosModules.home-manager
                {
                  home-manager.useUserPackages = true;
                  home-manager.users.alnav =
                    if host.name == "mjolnir" then
                      # Mjolnir - Gaming HTPC with desktop interface
                      { pkgs, inputs, ... }: {
                        imports = [ ./home-modules ];
                        myhome = {
                          user.enable = true;
                          git.enable = true;
                          jdk.enable = true;
                          kitty.enable = true;
                          hyprpanel.enable = true;
                          neovim = { enable = true; javaSupport = false; };
                          dotfiles = {
                            enable = true;
                            zsh.enable = true;
                            nvim.enable = true;
                            hypr.enable = true;
                            hyprdynamicmonitors.enable = false;
                            hyprpanel.enable = true;
                            rofi.enable = true;
                            tmux.enable = true;
                            wallpapers.enable = true;
                            llmLs.enable = false;
                          };
                        };
                      }
                    else if host.name == "node0" then
                      # Node0 - Home server (minimal, no GUI)
                      { pkgs, inputs, ... }: {
                        imports = [ ./home-modules ];
                        myhome = {
                          user.enable = true;
                          git.enable = true;
                          jdk.enable = false;
                          kitty.enable = false;
                          hyprpanel.enable = false;
                          neovim = { enable = true; javaSupport = false; };
                          dotfiles = {
                            enable = true;
                            zsh.enable = true;
                            nvim.enable = true;
                            tmux.enable = true;
                            hypr.enable = false;
                            wallpapers.enable = false;
                            hyprdynamicmonitors.enable = false;
                            llmLs.enable = false;
                          };
                        };
                      }
                    else
                      import ./home.nix;
                  home-manager.backupFileExtension = "bak";
                  home-manager.extraSpecialArgs = {
                    inherit inputs;
                    meta = host;
                  };
                }
              ]
              else if host.useHomeManager
              then [
                home-manager.nixosModules.home-manager
                # Framework and WSL now define their home-manager config in their configuration.nix
              ]
              else []
            )
            ++ (
              if host.name == "framework" || host.name == "mjolnir"
              then [
                # Deck SteamOS experience
                inputs.jovian-nixos.nixosModules.jovian
                inputs.lsfg-vk-flake.nixosModules.default

                # Ricing the nixOS way
                inputs.stylix.nixosModules.stylix
                nixos-hardware.nixosModules.framework-13-7040-amd
                #inputs.system-bridge-nix.nixosModules.x86_64-linux
                inputs.system-bridge-nix.nixosModules.${host.system}.default
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
