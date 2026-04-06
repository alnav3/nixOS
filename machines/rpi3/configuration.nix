# Raspberry Pi 3 - Mini Server Configuration
{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./../../modules
  ];

  # =============================================================================
  # Module Configuration
  # =============================================================================

  mymodules = {
    # Base configuration (SSH, user, etc.)
    base = {
      enable = true;

      # Disable systemd-boot (RPi uses extlinux)
      boot.systemdBoot = false;

      # User configuration (uses defaults from base.nix)
      user = {
        username = "alnav";
        extraGroups = [
          "wheel"
          "audio"
          "video"
          "networkmanager"
          "input"
          "disk"
          "dialout"
          "gpio"  # For GPIO access on RPi
        ];
      };

      # SSH enabled by default
      ssh = {
        enable = true;
        passwordAuthentication = false;
        permitRootLogin = "no";
      };
      
      # SSH public keys (from base.nix defaults, but explicitly set here)
      user.sshKeys = [
        "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCiP2WKxf0TUiFAlb/rg/dpimYTpzMntD7UmUYQxxiVUt6OCg34iKgDHHiC+nK2nRMuy1viT84dR0qUiG9J+vLTVJ1nuBgg1HI5w/RJ3f7oKSmV2rSnK0jetGU8yeJ8H/9MmwYGQ6Oc2896q0IukojFc7ULRKr1/fMOFTNL9v++IwpuTL05D1OkVbpcB1rKM5vSjYEWen+1SBuQWW91BepyLwiX4CrLttaJyZIHUVYgtcUbAIcduduA4lkCrFHud4N93R1QqIXqf4WYew5OoxNjhXhLq6yJ9w+MvbmeCzqEgSkwSj9jFb97Se4FCHeeiV20Y6mM7/yeTC73i77w3DpnDPO0iYtNtcbZ1EmKOF2N7LXwW5jqZT8e/w4TbRFYJ+zfe0zWRO/27H3DSNPcb8LcEpYFNFQ+plgRRO9fBwLRhgHSVolU6JudOoe6g+TCUaR4CMV+xF/Ir6A6P5vwPR6Y1cTjufXrx/SdsfPNk5q1YK6qRxPxPt3tCNVGdO68psfDwpXxYxwUiPtytEvgenr1aXbauA4QqM1qMTOLa14Q/je5D5regg497RFXVjgLeQf3bDrhsSlaaHuARme9OkcKr8vyzIyPGIvmxvl6zlQBrBGHHKey1gMtB4QH/xeA8dLofD83p/Yl174omx+2L5XiP0QqfHu4T/cC0j1baGL2BQ== alnav@nixos"
      ];
    };

    # Desktop disabled (headless server)
    desktop.enable = false;

    # Development tools (console focused)
    development = {
      enable = true;

      shell = {
        zsh = {
          enable = true;
          aliases = {
            # RPi-specific aliases
            temp = "vcgencmd measure_temp";
            freq = "vcgencmd measure_clock arm";
            volts = "vcgencmd measure_volts";
            throttled = "vcgencmd get_throttled";
          };
        };
        direnv = true;
      };

      editor = {
        neovim = true;
        tmux = true;
      };

      git.enable = true;

      # Nix tools for managing the system
      languages.nix = true;
    };

    # No gaming
    gaming.enable = lib.mkForce false;

    # No media (server mode)
    media.enable = false;
  };

  # =============================================================================
  # Networking Configuration
  # =============================================================================

  networking = {
    hostName = "rpi3";

    # Enable NetworkManager for easy WiFi management
    networkmanager.enable = true;

    # Enable wireless support (wpa_supplicant)
    wireless = {
      enable = lib.mkForce false;  # Use NetworkManager instead
    };

    # Firewall (basic security)
    firewall = {
      enable = true;
      allowedTCPPorts = [ 22 ];  # SSH
      # Add more ports as needed for services
    };
  };

  # =============================================================================
  # WiFi Configuration
  # =============================================================================

  # Note: Configure WiFi after first boot using:
  # nmcli device wifi connect "SSID" password "password"
  # Or pre-configure using sops secrets

  # =============================================================================
  # Console Configuration
  # =============================================================================

  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  # =============================================================================
  # System Packages
  # =============================================================================

  environment.systemPackages = with pkgs; [
    # Raspberry Pi tools
    libraspberrypi  # vcgencmd, etc.

    # Network utilities
    iw              # WiFi configuration
    wirelesstools   # iwconfig, etc.
    networkmanagerapplet  # nmcli comes with networkmanager

    # System monitoring
    htop
    btop
    iotop
    iftop

    # File management
    ncdu            # Disk usage analyzer
    ranger          # File manager

    # Text processing
    vim             # Backup editor
    nano            # Simple editor

    # Networking tools
    wget
    curl
    nmap
    tcpdump
    mtr

    # System utilities
    usbutils
    pciutils
    lm_sensors

    # Compression
    zip
    unzip
    gzip

    # Process management
    screen          # Alternative to tmux

    # Misc utilities
    fastfetch
    tree
    file
    which

    # ESPHome USB reboot support
    (python3.withPackages (ps: [ ps.pyserial ]))
  ];

  # =============================================================================
  # Services
  # =============================================================================

  services = {
    # Enable mDNS for easy discovery (rpi3.local)
    avahi = {
      enable = true;
      nssmdns4 = true;
      publish = {
        enable = true;
        addresses = true;
        domain = true;
        hinfo = true;
        userServices = true;
      };
    };

    # Automatic time sync
    timesyncd.enable = true;

    # Journal size limit (important for SD card longevity)
    journald.extraConfig = ''
      SystemMaxUse=100M
      SystemMaxFileSize=10M
    '';
  };

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

  # =============================================================================
  # Performance Optimizations for SD Card
  # =============================================================================

  # Reduce writes to extend SD card life
  boot.tmp.useTmpfs = true;

  # Disable swap (can cause SD card wear)
  swapDevices = lib.mkForce [];

  # Set swappiness very low
  boot.kernel.sysctl = {
    "vm.swappiness" = 1;
  };

  # =============================================================================
  # Nix Configuration
  # =============================================================================

  nix.settings = {
    # Use less cores for builds (RPi3 has limited resources)
    max-jobs = 2;
    cores = 2;

    # Trust the main user
    trusted-users = [ "root" "@wheel" "alnav" ];
  };

  # State version
  system.stateVersion = "24.11";
}
