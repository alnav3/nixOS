{pkgs, lib, ...}:
{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  jovian.steam.enable = true;
  jovian.steam.desktopSession = "Hyprland";
  jovian.decky-loader.enable = true;
  jovian.hardware.has.amd.gpu = true;

  environment.systemPackages = with pkgs; [
    mangohud
    protonup
    # General non-steam games
    lutris
    # Epic, GOG, etc.
    heroic
    # just in case neither of the above work
    bottles
  ];
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "steam"
    "steam-original"
    "steam-run"
    "steam-jupiter-original"
    "steamdeck-hw-theme"
  ];
}
