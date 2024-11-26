{
  lib,
  pkgs,
  ...
}: {
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  # hardware.opengl has beed changed to hardware.graphics

  services.xserver.videoDrivers = ["amdgpu"];

  environment.systemPackages = with pkgs; [
    mangohud
    protonup
    # General non-steam games
    lutris
    # Epic, GOG, etc.
    heroic
    # just in case neither of the above work
    bottles
    ryujinx
    (
      pkgs.writeShellScriptBin "steamos-session-select" ''
        steam -shutdown & exec Hyprland
      ''
    )
  ];

  boot.kernelPackages = pkgs.linuxPackages; # (this is the default) some amdgpu issues on 6.10
  programs = {
    gamescope = {
      enable = true;
      capSysNice = true;
    };
    steam = {
      enable = true;
      gamescopeSession.enable = true;
    };
  };

  environment.sessionVariables = {
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "\${HOME}/.steam/root/compatibilitytools.d";
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "steam"
      "steam-original"
      "steam-run"
    ];
}
