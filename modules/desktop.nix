{ pkgs, pkgs-stable, inputs, ...}:
{
    imports = [
      ./login.nix
    ];

    programs.hyprland = {
        enable = true;
        xwayland.enable = true;
    };

    environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
    };

    hardware = {
        graphics.enable = true;
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
    security.rtkit.enable = true;
    services.pipewire = {
        enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        pulse.enable = true;
        jack.enable = true;
    };

  environment.systemPackages = (with pkgs; [
    # terminal needed for hyprland
    #kitty
    # File manager and icon theme needed for gtk apps
    nautilus
    adwaita-icon-theme
    # mouse fix for hyprland
    hyprcursor
    # topbar for hyprland
    (waybar.overrideAttrs (oldAttrs: {
      mesonFlags = oldAttrs.mesonFlags ++ [ "-Dexperimental=true" ];
    }))
    # notification system for wayland
    swaynotificationcenter
    libnotify
    # wallpaper plugin for hyprland
    hyprpaper
    # App launcher
    rofi-wayland
    transmission_4-gtk
    # Network manager
    networkmanagerapplet
    bc
    #Screenshot tool
    grim
    slurp
    wl-clipboard
    imv
    # lock screen
    hyprlock
  ])
  ++
  (with pkgs-stable; [
  ]);

  # add support for screensharing and other stuff
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [ pkgs.xdg-desktop-portal-gtk ];

}
