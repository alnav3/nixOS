{
  description = "Multi-machine NixOS configuration with modular architecture";

  inputs = {
    # Core nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";

    # Disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Desktop/Window managers
    hyprland.url = "github:hyprwm/Hyprland";
    hyprdynamicmonitors.url = "github:fiffeek/hyprdynamicmonitors";
    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Browser
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hardware support
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    # Gaming/Graphics
    lsfg-vk-flake = {
      url = "github:pabloaul/lsfg-vk-flake/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    jovian-nixos = {
      url = "github:Jovian-Experiments/Jovian-NixOS";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    eden-nix = {
      url = "github:Daaboulex/eden-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Theming
    stylix.url = "github:danth/stylix";

    # Secrets management
    sops-nix = {
      url = "github:Mic92/sops-nix/a4c33bfecb93458d90f9eb26f1cf695b47285243";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Flatpak integration
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=v0.6.0";

    # Custom packages/services
    system-bridge-nix = {
      url = "github:alnav3/system-bridge-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    posting-flake.url = "github:jorikvanveen/posting-flake";

    # WSL support
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL/main";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Non-flake inputs
    tpm = {
      url = "github:tmux-plugins/tpm";
      flake = false;
    };
    rofi-wifi = {
      url = "github:zbaylin/rofi-wifi-menu";
      flake = false;
    };

    # Nix wrapper modules
    wrapper-modules.url = "github:BirdeeHub/nix-wrapper-modules";
  };

  outputs = { self, nixpkgs, ... } @ inputs:
  let
    # ===========================================================================
    # Host Definitions
    # ===========================================================================
    # Each host defines its properties. The build system uses these to
    # automatically include appropriate modules.
    hosts = {
      # Laptops
      framework = {
        system = "x86_64-linux";
        desktop = true;
        gaming = true;
        hardware = [ inputs.nixos-hardware.nixosModules.framework-13-7040-amd ];
      };
      # work - moved to Fedora Workstation with standalone Home Manager
      # See machines/work/home.nix and homeConfigurations output below

      # Gaming desktop
      mjolnir = {
        system = "x86_64-linux";
        desktop = true;
        gaming = true;
        extraModules = [ inputs.system-bridge-nix.nixosModules.x86_64-linux.default ];
        eden = true;
      };

      # Steam Deck
      deck = {
        system = "x86_64-linux";
        desktop = true;
        gaming = true;
        eden = true;
        # Home-manager defined in flake
        hmInFlake = true;
        hmConfig = "gaming";
      };

      # Home server (LXC container)
      node0 = {
        system = "x86_64-linux";
        server = true;
        hmInFlake = true;
        hmConfig = "server";
      };

      # WSL
      wsl = {
        system = "x86_64-linux";
        isWsl = true;
      };

      # Router
      router = {
        system = "x86_64-linux";
        isRouter = true;
        useHomeManager = false;
      };

      # Raspberry Pi 3
      rpi3 = {
        system = "aarch64-linux";
        isRpi = true;
        hmInFlake = true;
        hmConfig = "server";
      };
    };

    # ===========================================================================
    # Helper Functions
    # ===========================================================================
    
    # Get host attribute with default
    hostAttr = host: attr: default:
      if hosts.${host} ? ${attr} then hosts.${host}.${attr} else default;

    # Check if host should use home-manager
    useHM = host: hostAttr host "useHomeManager" true;

    # Check if host should use disko
    useDisko = host:
      !(hostAttr host "isWsl" false) &&
      !(hostAttr host "isRpi" false);

    # Home-manager configurations for different host types
    hmConfigs = {
      gaming = { pkgs, inputs, ... }: {
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
      };
      server = { pkgs, inputs, ... }: {
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
      };
    };

    # Build modules list for a host
    mkModules = name: let
      host = hosts.${name};
      system = host.system;
      isRouter = hostAttr name "isRouter" false;
      isWsl = hostAttr name "isWsl" false;
      isRpi = hostAttr name "isRpi" false;
      isDesktop = hostAttr name "desktop" false;
      isGaming = hostAttr name "gaming" false;
      hasEden = hostAttr name "eden" false;
      hmInFlake = hostAttr name "hmInFlake" false;
      hmConfig = hostAttr name "hmConfig" null;
      extraMods = hostAttr name "extraModules" [];
      hardwareMods = hostAttr name "hardware" [];
    in
      # Base modules for all hosts
      [
        inputs.sops-nix.nixosModules.sops
        inputs.nix-flatpak.nixosModules.nix-flatpak
      ]
      # Router-specific modules
      ++ (if isRouter then [
        inputs.disko.nixosModules.disko
        ./modules
        ./machines/${name}/hardware-configuration.nix
        ./machines/${name}/disko-config.nix
        ./machines/${name}/configuration.nix
      ]
      # WSL-specific modules
      else if isWsl then [
        ./machines/${name}/configuration.nix
        ./machines/${name}/hardware-configuration.nix
      ]
      # Raspberry Pi modules
      else if isRpi then [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
        ./machines/${name}/configuration.nix
      ]
      # Standard desktop/server modules
      else [
        inputs.disko.nixosModules.disko
        ./machines/${name}/hardware-configuration.nix
        ./machines/${name}/disko-config.nix
        ./configuration.nix
        ./noctalia.nix
      ])
      # Desktop features (Jovian, lsfg, Stylix)
      ++ (if isDesktop || isGaming then [
        inputs.jovian-nixos.nixosModules.jovian
        inputs.lsfg-vk-flake.nixosModules.default
        inputs.stylix.nixosModules.stylix
      ] else [])
      # Hardware-specific modules
      ++ hardwareMods
      # Extra modules
      ++ extraMods
      # Eden (Switch emulator)
      ++ (if hasEden then [ inputs.eden-nix.nixosModules.default ] else [])
      # Home-manager (when defined in flake)
      ++ (if useHM name && hmInFlake && hmConfig != null then [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager = {
            useUserPackages = true;
            users.alnav = hmConfigs.${hmConfig};
            backupFileExtension = "bak";
            extraSpecialArgs = {
              inherit inputs;
              meta = { inherit name system; useHomeManager = true; isWsl = false; };
            };
          };
        }
      ]
      # Home-manager (when defined in machine config)
      else if useHM name && !hmInFlake then [
        inputs.home-manager.nixosModules.home-manager
      ] else []);

    # Build a NixOS system for a host
    mkSystem = name: nixpkgs.lib.nixosSystem {
      system = hosts.${name}.system;
      specialArgs = {
        inherit inputs;
        overlays = import ./overlays;
        meta = { hostname = name; };
        pkgs-stable = inputs.nixpkgs-stable.legacyPackages.${hosts.${name}.system};
        pkgs-unstable = inputs.nixpkgs.legacyPackages.${hosts.${name}.system};
        postingPkg = inputs.posting-flake.packages.${hosts.${name}.system}.posting or null;
      };
      modules = mkModules name;
    };

  in {
    # ===========================================================================
    # Wrapped Packages
    # ===========================================================================
    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      lib = pkgs.lib;
      myNoctalia = import ./wrapped/noctalia.nix { inherit pkgs inputs; };
    in {
      noctalia = myNoctalia;
      niri = import ./wrapped/niri.nix {
        inherit pkgs inputs lib;
        noctaliaPackage = myNoctalia;
      };
      rpi3-sdimage = self.nixosConfigurations.rpi3.config.system.build.sdImage;
    };

    # ===========================================================================
    # NixOS Configurations
    # ===========================================================================
    nixosConfigurations =
      # Generate configurations for all hosts
      builtins.mapAttrs (name: _: mkSystem name) hosts
      # Add ISO installer
      // {
        isoInstaller = nixpkgs.lib.nixosSystem {
          modules = [ ./iso.nix ];
          specialArgs = { inherit inputs; };
        };
      };

    # ===========================================================================
    # Home Manager Configurations (standalone, for non-NixOS hosts)
    # ===========================================================================
    homeConfigurations = {
      "alnav@work" = let
        system = "x86_64-linux";
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfreePredicate = pkg: builtins.elem (nixpkgs.lib.getName pkg) [
            "teams-for-linux"
          ];
        };
      in inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          inputs.stylix.homeModules.stylix
          ./machines/work/home.nix
        ];
        extraSpecialArgs = {
          inherit inputs;
          meta = { name = "work"; inherit system; useHomeManager = true; isWsl = false; };
          pkgs-stable = inputs.nixpkgs-stable.legacyPackages.${system};
        };
      };
    };
  };
}
