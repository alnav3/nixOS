{ config, lib, pkgs, ... }:

{
  imports = [
      "../../modules/gaming.nix"
      "../../modules/network.nix"
      "../../modules/desktop.nix"
      "../../modules/development.nix"
  ];

  # Updating firmware | after first start we need to run fwupdmgr update
  services.fwupd.enable = true;

  # Suspend/wake workaround, keyboard will not wake up the system
  hardware.framework.amd-7040.preventWakeOnAC = true;

  # fingerprint reader support
  services.fwupd.package = (import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/bb2009ca185d97813e75736c2b8d1d8bb81bde05.tar.gz";
    sha256 = "sha256:003qcrsq5g5lggfrpq31gcvj82lb065xvr7bpfa8ddsw8x4dnysk";
  }) {
    inherit (pkgs) system;
  }).fwupd;
  # for complete guide on fingerprint workaround, read https://github.com/NixOS/nixos-hardware/tree/master/framework/13-inch/7040-amd#suspendwake-workaround
}
