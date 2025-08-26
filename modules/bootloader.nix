{ config, pkgs, ... }:

{
  # Mount options for boot partition
  fileSystems."/boot" = {
    options = [ "umask=0077" ];
  };

  # Bootloader (UEFI -> systemd-boot)
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Initrd + LUKS unlock in initrd
  boot.initrd.systemd.enable = true;            # systemd in initrd
  boot.initrd.verbose = false;                  # less spam in initrd
  boot.kernelParams = [
    "quiet"
    "splash"
    "rd.systemd.show_status=false"
    "rd.udev.log_priority=3"
    "vt.global_cursor_default=0"
  ];

  # LUKS device unlock
  boot.initrd.luks.devices = {
    root = {
      device = "/dev/disk/by-uuid/594ed76c-5aa0-45a9-942d-d37dee65c13c";
      # preLVM = true; # if you use LVM inside LUKS
    };
  };

  # Make sure LUKS waits for Plymouth
  boot.initrd.systemd.services."systemd-cryptsetup@root".after = [ "plymouth-start.service" ];
  boot.initrd.systemd.services."systemd-cryptsetup@root".requires = [ "plymouth-start.service" ];

  # Enable plymouth splash
  boot.plymouth.enable = true;
  #boot.plymouth.theme = "breeze";  # optional theme
  #boot.plymouth.themePackages = with pkgs; [ pkgs.plymouth-theme-breeze ];

  # AMD GPU driver in initrd so Plymouth has graphics early
  boot.initrd.kernelModules = [ "amdgpu" ];

  # Optional: ensure correct firmware for AMDGPU
  hardware.enableAllFirmware = true;
}

