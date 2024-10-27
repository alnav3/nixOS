{
  pkgs,
  modulesPath,
  ...
}: {
  imports = ["${modulesPath}/installer/cd-dvd/installation-cd-graphical-calamares-gnome.nix"];
  nixpkgs.hostPlatform = {system = "x86_64-linux";};
  environment.systemPackages = with pkgs; [
    vesktop
    git
    netbird
  ];
  nix.settings = {
    experimental-features = ["nix-command" "flakes"];
  };
  boot.loader.efi.canTouchEfiVariables = false;
}
