{ config, lib, pkgs, inputs, ... }: {
  imports = [
    ./../../modules  # Import all modules
  ];

  # =============================================================================
  # Module Configuration - Based on mjolnir, adapted for Steam Deck
  # =============================================================================
  fileSystems."/mnt/MicroSDCard" = {
    device = "/dev/mmcblk0p1";
    # If you have this partition mounted, then you can check its type by using
    # df -T | grep /dev/${device}
    fsType = "ext4";
    options = [
      # System will boot up if you don't have sd card inserted
      "nofail"
      # After booting up systemd will try mounting the sd card
      "x-systemd.automount"
    ];
  };
  mymodules = {
    media = {
        enable = true;
        video = {
            mpv = true;
            obs = true;
        };
        audio = {
            playerctl = true;
            finamp = true;
        };
    };
    # Base system configuration
    base = {
      enable = true;
      ssh = {
        enable = true;
        x11Forwarding = true;
      };
    };

    # Desktop environment (SteamOS-style with Hyprland fallback)
    desktop = {
      enable = true;
      login = {
        enable = true;
        autoLogin = true;
        user = "alnav";
        session = "gamescope";  # Start in SteamOS mode
      };
      hyprland = {
        enable = true;
        xwayland = true;
      };
      stylix = {
        enable = true;
        theme = "catppuccin-mocha";
        polarity = "dark";
      };
      apps = {
        notifications = true;
        fileManager = true;
      };
    };

    # Development
    development = {
      enable = true;
      shell = {
        zsh.enable = true;
        direnv = true;
      };
      editor = {
        neovim = true;
        tmux = true;
      };
      git.enable = true;
    };

    # Gaming (SteamOS mode)
    gaming = {
      enable = true;
      steam = {
        enable = true;
        gamescope = true;
      };
      steamos = {
        enable = true;
        autoStart = true;
        user = "alnav";
        deckyLoader = true;
      };
      launchers = {
        lutris = true;
        heroic = true;
        bottles = true;
      };
      emulation = {
        enable = true;
        retroDeck = true;
      };
      performance = {
        mangohud = true;
        protonTools = true;
      };
      android.enable = true;
    };

    # Networking
    networking = {
      enable = true;
      networkManager = true;
      firewall = {
        enable = true;
        allowedTCPPorts = [ 8384 ];  # syncthing
      };
    };

    # Hardware
    hardware = {
      bluetooth = {
        enable = true;
        audio = {
          mprisProxy = true;
          highQuality = true;
        };
        ui.blueman = true;
      };

      graphics = {
        enable = true;
        gpu = "amd";
        enable32Bit = true;
        amd = {
          initrdEnable = true;
          vulkan = true;
        };
      };
    };

    # Services
    services = {
      syncthing = {
        enable = true;
        user = "alnav";
        openFirewall = true;
      };
    };
  };

  # =============================================================================
  # Jovian/SteamOS + Steam Deck Configuration (Jovian module loaded via flake.nix)
  # =============================================================================

  jovian = {
    # Steam Deck hardware support (enables all sub-options by default:
    # controller udev rules, kernel cmdline, initrd modules, fwupd BIOS updates,
    # kernel patches, OS fan control, perf control udev rules, sound support,
    # vendor drivers, xorg rotation)
    devices.steamdeck = {
        enable = true;
        enableControllerUdevRules = true;      # controller out of "lizard" mode
        enableDefaultCmdlineConfig = true;     # deck-specific kernel cmdline flags
        enableDefaultStage1Modules = true;     # essential kernel modules in initrd
        enableFwupdBiosUpdates = true;         # BIOS updates via fwupd
        enableKernelPatches = true;            # Valve kernel patches
        enableOsFanControl = true;             # OS-controlled fan curve
        enablePerfControlUdevRules = true;     # TDP, GPU clock, brightness control
        enableSoundSupport = true;             # audio support
        enableVendorDrivers = true;            # Valve's Mesa branches
        enableXorgRotation = true;             # correct display rotation in X11
        autoUpdate = false;                    # auto-update BIOS/controller firmware (careful)
        enableGyroDsuService = false;          # gyro DSU for Cemu/Cemuhook (optional)
    };

    # Steam Deck UI
    steam = {
      autoStart = true;
      enable = true;
      user = "alnav";
      desktopSession = "hyprland";
    };

    # SteamOS configuration
    steamos = {
      useSteamOSConfig = true;
    };

    # Decky Loader (same as mjolnir)
    decky-loader = {
      enable = true;
      extraPackages = with pkgs; [ wget p7zip ];
    };

    # AMD GPU support
    hardware.has.amd.gpu = true;
  };

  # =============================================================================
  # Deck-specific Configuration
  # =============================================================================


  # Eden Nintendo Switch emulator
  programs.eden.enable = true;

  # SSH configuration
  programs.ssh.setXAuthLocation = true;

  # Unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-original"
      "steam-run"
      "steam-jupiter-original"
      "steam-jupiter-unwrapped"
      "steamdeck-hw-theme"
    ];
  environment.systemPackages = with pkgs; [ ludusavi moonlight-qt ];

}
