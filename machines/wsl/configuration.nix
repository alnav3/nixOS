{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    # Import the modular system
    ../../modules

    # WSL-specific modules
    inputs.nixos-wsl.nixosModules.default
  ];

  # =============================================================================
  # WSL Configuration - Using modular system
  # =============================================================================

  # WSL settings
  wsl.enable = true;
  wsl.defaultUser = "alnav";
  wsl.wslConf.network.generateResolvConf = false;

  # Network hostname
  networking.hostName = "wsl";

  # Configure nameservers since WSL resolv.conf generation is disabled
  networking.nameservers = [
    "192.168.2.250"    # VPN DNS (primary)
    "213.229.189.8"    # VPN DNS (secondary)
    "9.9.9.9"          # Quad9 (fallback)
  ];

  # =============================================================================
  # Module Configuration - WSL appropriate modules only
  # =============================================================================

  mymodules = {
    desktop = {
      apps = {
        browser = true;
      };
    };
    base = {
      enable = true;
      ssh = {
        enable = true;
        ports = [ 2022 ];
        x11Forwarding = true;
      };
      # Disable boot loader for WSL
      boot.systemdBoot = false;
      # Disable SOPS for WSL (not needed)
      sops.enable = false;
      # Set WSL state version
      stateVersion = "25.11";
    };

    # Development environment (matches development.nix functionality)
    development = {
      enable = true;
      shell = {
        zsh = {
          enable = true;
        };
        direnv = true;
      };
      languages = {
        go = true;
        java = true;
        nix = true;
        python = true;
        nodejs = true;
      };
      infrastructure = {
        kubernetes = true;
        dockerTools = true;
        databases = false;
      };
      editor = {
        neovim = true;
        tmux = true;
        opencode = true;
      };
      git = {
        enable = true;
        gitlab = true;
      };
      work.enable = true;
      freelance.enable = false;

      # Extra packages from development.nix that don't fit in categories
      extraPackages = with pkgs; [
        android-tools
        firefox
        openconnect
        cargo
        gcc
        lsof
        qemu
      ];
    };

    # Basic networking for WSL
    networking = {
      enable = true;
      networkManager = false;  # WSL handles networking
      dns = {
        resolved = false;   # Keep simple for VPN compatibility
        dnssec = false;
      };
      ipv6.enable = false;
      firewall.enable = false; # WSL uses Windows firewall
      diagnostics = true;  # Basic network tools are useful
    };

    desktop.enable = false;

    gaming.enable = false;

    media.enable = false;

    # Virtualisation
    virtualisation = {
      enable = true;
      docker = {
        enable = true;
        batteryOptimized = true;
        autoPrune = {
          enable = true;
          schedule = "daily";
          aggressive = true;
        };
      };
    };

    hardware = {
      bluetooth.enable = false;
      battery.enable = false;
      graphics.enable = false;
    };
  };

  # WSL-specific configurations that don't fit in modules
  programs.ssh.setXAuthLocation = true;

  # Additional WSL-specific system packages
  environment.systemPackages = with pkgs; [
    xauth
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.niri
  ];

  # =============================================================================
  # Home Manager Configuration
  # =============================================================================

  home-manager = {
    useUserPackages = true;
    users.alnav = { pkgs, inputs, ... }: {
      imports = [ ../../home-modules ];

      # WSL home configuration - Basic development setup
      myhome = {
        # Basic user configuration
        user.enable = true;

        # Git configuration
        git.enable = true;

        # JDK management for development
        jdk.enable = true;

        # Terminal (useful even in WSL)
        kitty.enable = false; # WSL typically uses Windows terminal

        # No desktop panel in WSL
        hyprpanel.enable = false;

        # Neovim with Java support for development
        neovim = {
          enable = true;
          javaSupport = true;
        };

        # Dotfiles - WSL appropriate subset
        dotfiles = {
          enable = true;
          zsh.enable = true;
          nvim.enable = true;
          hypr.enable = false;  # No Hyprland in WSL
          tmux.enable = true;
          wallpapers.enable = false;  # No wallpapers in WSL
          llmLs.enable = true;  # Useful for development
        };
      };
    };
    backupFileExtension = "bak";
    extraSpecialArgs = {
      inherit inputs;
      meta = { name = "wsl"; system = "x86_64-linux"; useHomeManager = true; isWsl = true; };
    };
  };
}
