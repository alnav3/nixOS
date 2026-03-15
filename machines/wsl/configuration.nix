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

  # Network hostname
  networking.hostName = "wsl";

  # =============================================================================
  # Module Configuration - WSL appropriate modules only
  # =============================================================================

  mymodules = {
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
      };
      infrastructure = {
        kubernetes = true;
        dockerTools = false;
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
      freelance.enable = true;

      # Extra packages from development.nix that don't fit in categories
      extraPackages = with pkgs; [
        android-tools
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
        resolved = false;   # WSL uses Windows DNS
        dnssec = false;
      };
      ipv6.enable = false;
      firewall.enable = false; # WSL uses Windows firewall
      diagnostics = true;  # Basic network tools are useful
    };

    desktop.enable = false;

    gaming.enable = false;

    media.enable = false;

    virtualisation.enable = false;

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
          kanshi.enable = false;  # No monitor management in WSL
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
