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
    ./../../modules/llms.nix
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
    allowedTCPPorts = [80 4200 1338 5300];
  };

  # docker setup
  virtualisation.docker = {
    enable = true;

    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };
  users.users.alnav.extraGroups = [ "docker" ];

  # fingerprint reader support
  services.fwupd.package =
    (import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
        sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
      }) {
        inherit (pkgs) system;
      })
    .fwupd;


  virtualisation.spiceUSBRedirection.enable = true;
  # enable the tailscale service
  services.tailscale.enable = true;
  # for complete guide on fingerprint workaround, read https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
  environment.systemPackages = with pkgs; [
    tailscale
    docker-compose
    fw-ectool
    distrobox
    spice-gtk
    universal-android-debloater
    spice-vdagent
  ];
}
