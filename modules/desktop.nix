{pkgs, ...}:
{
    programs.hyprland = {
        enable = true;
        xwayland.enable = true;
    };

    environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
    };

    hardware = {
        opengl.enable = true;
    };

    # change default font
    fonts = {
      packages = with pkgs; [
        (nerdfonts.override {fonts = [
          "FiraCode"
        ];})
        ];
        fontconfig = {
          defaultFonts = {
            serif = ["Liberation Serif" "FiraCode"];
            sansSerif = ["Ubuntu" "FiraCode"];
            monospace = ["FiraCode" "DroidSansMono"];
          };
        };
        enableDefaultPackages = true;
    };

    # enable sound with pipewire
    sound.enable = true;
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
    };

  environment.systemPackages = with pkgs; [
    # terminal needed for hyprland
    kitty
    # temporal browser
    firefox
    # topbar for hyprland
    (waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
    }))
    # notification system for wayland
    mako
    libnotify
    # wallpaper plugin for hyprland
    hyprpaper
    # lock screen
    hyprlock
    # App launcher
    rofi-wayland
    # Network manager
    networkmanagerapplet
    #Screenshot tool
    grim
    slurp
    wl-clipboard
  ];

  # add support for screensharing and other stuff
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

}
