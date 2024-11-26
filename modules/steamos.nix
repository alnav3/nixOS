{
  pkgs,
  lib,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  services.xserver.enable = true;
  jovian.steam = {
    enable = true;
    user = "alnav";
    #desktopSession = "Hyprland";
  };
  jovian.decky-loader.enable = true;
  jovian.hardware.has.amd.gpu = true;

  environment.systemPackages = with pkgs; [
    (
      pkgs.writeShellScriptBin "steamos-session-select" ''
        steam -shutdown
      ''
    )
    mangohud
    protonup
    # General non-steam games
    lutris
    # Epic, GOG, etc.
    heroic
    # just in case neither of the above work
    bottles
    decky-loader
    ryujinx
  ];
}
