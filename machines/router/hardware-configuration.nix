# Generated stub — replace with output of `nixos-generate-config --show-hardware-config`
# on the actual machine if needed.
{ config, lib, pkgs, modulesPath, ... }:
{
  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "virtio_pci"
    "virtio_blk"    # virtio block device (most Proxmox/QEMU VMs)
    "virtio_scsi"   # virtio SCSI (alternative Proxmox disk controller)
    "sd_mod"
    "sr_mod"
    "ata_piix"      # SATA/IDE emulation fallback
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # fileSystems and swapDevices are defined by disko-config.nix — do not add them here.

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
