{ ... }:

{
  imports = [
    # Base system configuration
    ./base.nix
    
    # Core modules
    ./desktop.nix
    ./development.nix
    ./gaming.nix
    ./media.nix
    ./networking.nix
    ./virtualisation.nix

    # Hardware modules
    ./hardware

    # Service modules
    ./services
  ];
}
