{ config, lib, pkgs, inputs, ... }: {
  imports = [
    ./../../modules  # Import all modules
  ];

  # =============================================================================
  # Module Configuration - All options explicitly enabled
  # =============================================================================

  mymodules = {
    # Base system configuration
    base = {
      enable = true;
      ssh = {
        enable = true;
        x11Forwarding = true;  # Enable X11 forwarding for remote gaming
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
        frameGeneration = true;
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
      tvMedia.kodi = true;
    };

    # Networking
    networking = {
      enable = true;
      networkManager = true;
      firewall = {
        enable = true;
        allowedTCPPorts = [ 9170 8088 8384 ];  # system-bridge, syncthing
      };
    };

    # Virtualisation
    virtualisation = {
      enable = true;
      docker = {
        enable = true;
        autoPrune = {
          enable = true;
          schedule = "weekly";
        };
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

      ollama = {
        enable = true;
        host = "[::]";
        openFirewall = true;
        amdGfxVersion = "11.0.0";
      };

      sunshine = {
        enable = true;
        openFirewall = true;
      };
    };
  };

  # =============================================================================
  # Jovian/SteamOS Configuration (Jovian module is loaded via flake.nix)
  # =============================================================================

  jovian = {
    steam = {
      autoStart = true;
      enable = true;
      user = "alnav";
      desktopSession = "hyprland";
    };
    steamos = {
      useSteamOSConfig = true;
    };
    decky-loader = {
      enable = true;
      extraPackages = with pkgs; [ wget p7zip ];
    };
    hardware.has.amd.gpu = true;
  };

  # Frame generation (LSFG-VK)
  services.lsfg-vk = {
    enable = true;
    ui.enable = true;
  };

  # =============================================================================
  # Mjolnir-specific Configuration
  # =============================================================================

  # Boot configuration (silent boot)
  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    consoleLogLevel = 0;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
      "boot.shell_on_fail"
    ];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot.enable = true;
    };
    kernelModules = [ "kvm-amd" ];
    binfmt.emulatedSystems = [ "aarch64-linux" ];
  };

  # Wake on LAN
  networking.interfaces.enp13s0.wakeOnLan.enable = true;

  # SSH configuration handled by base module
  programs.ssh.setXAuthLocation = true;

  # AMD GPU
  hardware.amdgpu.initrd.enable = true;

  # Unfree packages
  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-original"
      "steam-run"
      "steam-jupiter-original"
      "steam-jupiter-unwrapped"
      "steamdeck-hw-theme"
      "n8n"
    ];

  # Eden Nintendo Switch emulator
  programs.eden.enable = true;

  # Extra mjolnir-specific packages
  environment.systemPackages = [ 
    inputs.system-bridge-nix.packages.x86_64-linux.system-bridge 
    (pkgs.python3.withPackages (ps: [ ps.pyserial ]))  # For ESPHome USB reboot
  ];

  # =============================================================================
  # ESPHome USB Auto-Reboot
  # =============================================================================

  # ESPHome reboot script
  environment.etc."esphome-reboot".source = ./../../scripts/esphome-reboot;

  # udev rules to trigger ESPHome reboot on USB serial device connection
  # Only triggers for known ESP USB-to-serial chip vendor IDs
  services.udev.extraRules = ''
    # CH340/CH341 (common on cheap ESP boards)
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d4", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="55d3", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"

    # Silicon Labs CP210x (common on quality boards like NodeMCU)
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="10c4", ATTRS{idProduct}=="ea60", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"

    # FTDI (used on some ESP boards)
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6015", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"

    # Espressif native USB (ESP32-S2, ESP32-S3, ESP32-C3)
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1001", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="1002", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"
    ACTION=="add", SUBSYSTEM=="tty", ATTRS{idVendor}=="303a", ATTRS{idProduct}=="80d0", TAG+="systemd", ENV{SYSTEMD_WANTS}+="esphome-reboot@%k.service"
  '';

  # Systemd service template for ESPHome reboot
  # %i is replaced with the device name (e.g., ttyUSB0)
  systemd.services."esphome-reboot@" = {
    description = "Reboot ESPHome device on %i";
    after = [ "dev-%i.device" ];
    bindsTo = [ "dev-%i.device" ];

    serviceConfig = {
      Type = "oneshot";
      # Small delay to ensure device is fully initialized
      ExecStartPre = "${pkgs.coreutils}/bin/sleep 2";
      ExecStart = "${pkgs.python3.withPackages (ps: [ ps.pyserial ])}/bin/python3 /etc/esphome-reboot /dev/%i";
      # Run as root to access serial devices
      User = "root";
      # Timeout after 30 seconds
      TimeoutStartSec = "30";
      # Don't restart on failure
      Restart = "no";
    };
  };
}
