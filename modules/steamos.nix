{
  config,
  pkgs,
  ...
}: {
  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
  };
  services.xserver.enable = true;
  services.xserver.videoDrivers = ["amdgpu"];
  jovian = {
      steam = {
          autoStart = config.networking.hostName == "mjolnir";
          enable = true;
          user = "alnav";
          desktopSession = "hyprland";
      };
      steamos = {
          useSteamOSConfig = true;
      };
      decky-loader = {
          enable = true;
          extraPackages = [pkgs.wget pkgs.p7zip ];
      };
      hardware.has.amd.gpu = true;
  };

  environment.systemPackages = with pkgs; [
    (
      pkgs.writeShellScriptBin "steamos-session-select" ''
        steam -shutdown
      ''
    )
    # required for junkStore
    python3
    wget

    # required for decky framegen
    p7zip

    mangohud
    protonup-ng
    # General non-steam games
    lutris
    # Epic, GOG, etc.
    heroic
    # just in case neither of the above work
    bottles
  ];

  services.lsfg-vk = {
    enable = true;
    ui.enable = true; # installs gui for configuring lsfg-vk
  };

  # flatpak configuration for retrodeck
  services.flatpak = {
    enable = true;
    remotes = [{
      name = "flathub";
      location = "https://flathub.org/repo/flathub.flatpakrepo";
    }];
    packages = [
      { appId = "net.retrodeck.retrodeck"; origin = "flathub"; }
    ];
  };
}
