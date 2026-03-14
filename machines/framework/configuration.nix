{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    ./../../modules/android.nix
    ./../../modules/backup.nix
    ./../../modules/battery.nix
    ./../../modules/bluetooth.nix
    ./../../modules/3dprint.nix
    ./../../modules/desktop.nix
    ./../../modules/development.nix
    ./../../modules/freelance.nix
    ./../../modules/login.nix
    ./../../modules/media.nix
    ./../../modules/networking.nix
    ./../../modules/ricing.nix
    ./../../modules/gaming.nix
    ./../../modules/work.nix
    ./../../modules/misc.nix
    #./../../modules/llms.nix
    #./../../modules/virtualisation.nix
    # testing bootloader stuff
    ./../../modules/bootloader.nix
    ./../../modules/ip-monitor.nix

  ];



  # using latest linux kernel for network issues
  boot.kernelPackages = pkgs.linuxPackages_latest;
# required to rebuild duet
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];


  hardware.amdgpu.initrd.enable = true;

  nixpkgs.config.allowUnfree = true;

  # Updating firmware | after first start we need to run fwupdmgr update
  services.fwupd.enable = true;

  # Suspend/wake workaround, keyboard will not wake up the system
  hardware.framework.amd-7040.preventWakeOnAC = true;
  hardware.framework.enableKmod = true;
  # Networking configuration
  networking = {
    networkmanager.enable = true;
    useDHCP = false;
  };


  services.kanata = {
    enable = true;
    keyboards = {
      internalKeyboard = {
        devices = [
          "/dev/input/by-path/platform-i8042-serio-0-event-kbd"
        ];
        extraDefCfg = "process-unmapped-keys yes";
        config = ''
          (defsrc
           caps
           n
          )
          (defalias
           caps (tap-hold 175 175 esc lctl)
           n (tap-hold 200 200 n (unicode ñ))
          )

          (deflayer base
           @caps
           @n
          )
        '';
      };
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [80 4200 1338 2300 46899 46898];
    allowedUDPPorts = [ 46898 ];
  };

  # docker setup - optimized for power saving
  virtualisation.docker = {
    enable = true;

    # Power-optimized Docker settings
    daemon.settings = {
      # Reduce logging overhead
      "log-driver" = "none";
      "log-level" = "warn";

      # Reduce storage driver overhead
      "storage-driver" = "overlay2";
      "storage-opts" = [
        "overlay2.override_kernel_check=true"
        "overlay2.size=50G"
      ];

      # Resource limits to prevent runaway containers
      "default-ulimits" = {
        "memlock" = {
          "Hard" = 67108864;
          "Name" = "memlock";
          "Soft" = 67108864;
        };
      };
    };

    autoPrune = {
      enable = true;
      dates = "daily";
      flags = [ "--all" "--force" "--volumes" ];
    };
  };
  users.users.alnav.extraGroups = [ "docker" ];

  # fingerprint reader support
  services.fwupd.package =
    (import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
        sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
      }) {
        system = pkgs.stdenv.hostPlatform.system;
      })
    .fwupd;

  # syncthing config
  services.syncthing = {
      enable = true;
      openDefaultPorts = true; # TCP/UDP 22000 UDP 21027
      user = "alnav";
      dataDir = "/home/alnav";
      configDir = "/home/alnav/.config";
  };

  virtualisation.spiceUSBRedirection.enable = true;
  # for complete guide on fingerprint workaround, read https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
  environment.systemPackages = with pkgs; [
    docker-compose
    fw-ectool
    distrobox
    spice-gtk
    universal-android-debloater
    spice-vdagent
    # Network troubleshooting tools
    ethtool
    iw
  ];
}
