# Raspberry Pi 3 hardware configuration
{ config, lib, pkgs, modulesPath, ... }:

{
  # Raspberry Pi 3 specific hardware settings
  hardware = {
    # Required for WiFi and Bluetooth firmware
    enableRedistributableFirmware = true;
  };

  # Boot configuration for Raspberry Pi 3
  boot = {
    # Use generic extlinux compatible bootloader (works with RPi)
    loader.grub.enable = false;
    loader.generic-extlinux-compatible.enable = true;
    
    # Kernel parameters for console
    kernelParams = [
      "console=ttyS1,115200n8"  # Serial console for RPi3
    ];
    
    # Early boot HDMI support (optional, useful for debugging)
    initrd.kernelModules = [ "vc4" "bcm2835_dma" "i2c_bcm2835" ];
    
    # Required kernel modules for RPi3
    initrd.availableKernelModules = [
      "usbhid"
      "usb_storage"
      "vc4"
      "pcie_brcmstb"  # Broadcom PCIe
      "reset-raspberrypi"  # RPi firmware reset
    ];
  };

  # SD card root filesystem
  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
    options = [ "noatime" ];  # Reduce SD card writes
  };

  # Boot partition (firmware)
  fileSystems."/boot/firmware" = {
    device = "/dev/disk/by-label/FIRMWARE";
    fsType = "vfat";
    options = [ "nofail" "noauto" ];
  };

  # No swap (extend SD card life)
  swapDevices = [ ];

  # Use latest kernel for better WiFi support on RPi3
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Power management (minimal for server use)
  powerManagement.cpuFreqGovernor = lib.mkDefault "ondemand";
}
