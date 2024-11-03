{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ./../../modules/media.nix
    ./../../modules/work.nix
    ./../../modules/steamos.nix
    ./../../modules/networking.nix
    ./../../modules/bluetooth.nix
    ./../../modules/battery.nix
    ./../../modules/social.nix
    ./../../modules/android.nix
    ./../../modules/desktop.nix
    ./../../modules/development.nix
    ./../../modules/ricing.nix
  ];

  # using latest linux kernel for network issues
  boot.kernelPackages = pkgs.linuxPackages_latest;

  hardware.amdgpu.initrd.enable = true;

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-original"
      "steam-run"
      "steam-jupiter-original"
      "steam-jupiter-unwrapped"
      "steamdeck-hw-theme"
    ];

  # Updating firmware | after first start we need to run fwupdmgr update
  services.fwupd.enable = true;

  # Suspend/wake workaround, keyboard will not wake up the system
  hardware.framework.amd-7040.preventWakeOnAC = true;
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
          )
          (defalias
           caps (tap-hold 175 175 esc lctl)
          )

          (deflayer base
           @caps
          )
        '';
      };
    };
  };
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [80];
  };

  # fingerprint reader support
  services.fwupd.package =
    (import (builtins.fetchTarball {
        url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
        sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
      }) {
        inherit (pkgs) system;
      })
    .fwupd;
  # for complete guide on fingerprint workaround, read https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
  environment.systemPackages = with pkgs; [
    fw-ectool
  ];
}
