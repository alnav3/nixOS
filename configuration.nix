{
  pkgs,
  meta,
  lib,
  overlays,
  config,
  ...
}: {
  imports = [
    # Import the modular system
    ./modules
    
    # Machine-specific configuration
    ./machines/${meta.hostname}/configuration.nix
  ];
  
  # Set hostname from meta
  networking.hostName = meta.hostname;

  # Enable base configuration by default
  mymodules.base.enable = lib.mkDefault true;
}