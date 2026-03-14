{
  pkgs,
  pkgs-stable,
  inputs,
  ...
}: {

  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    # set the flake package
    package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
    # make sure to also set the portal package, so that they are in sync
    portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
  };

  hardware = {
    graphics.enable = true;
  };


  ## enable sound with pipewire
  #security.rtkit.enable = true;
  #services.pipewire = {
  #  enable = true;
  #  alsa.enable = true;
  #  alsa.support32Bit = true;
  #  pulse.enable = true;
  #  jack.enable = true;
  #};

  programs.localsend.enable = true;

  services.upower.enable = true;
  environment.systemPackages =
    (with pkgs; [
      hyprpanel
      hyprsunset
      gnome-multi-writer
      inputs.hyprdynamicmonitors.packages.${system}.default
      # terminal needed for hyprland
      kitty
      # File manager and icon theme needed for gtk apps
      nautilus
      # possible replacement
      yazi
      adwaita-icon-theme
      # mouse fix for hyprland
      hyprcursor
      # topbar for hyprland
      (waybar.overrideAttrs (oldAttrs: {
        mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
      }))
      # notification system for wayland
      swaynotificationcenter
      libnotify
      # wallpaper plugin for hyprland
      hyprpaper
      # App launcher
      rofi
      transmission_4-gtk
      # Network manager
      networkmanagerapplet
      bc
      #Screenshot tool
      hyprshot
      imv
      # screen management
      kanshi
      shikane
      proton-pass
      pkgs-stable.vesktop

      # recording tool
      wf-recorder
      # lock screen
      hyprlock
      #ungoogled-chromium
      (pkgs.writeShellScriptBin "hyprexit" ''
        ${hyprland}/bin/hyprctl dispatch exit
        ${systemd}/bin/loginctl terminate-user "alnav"
      '')
      inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default
      ungoogled-chromium
    ])
    ++ (with pkgs-stable; [
    ]);

  # add support for screensharing and other stuff
  xdg.portal.enable = true;
  xdg.portal.extraPortals = [pkgs.xdg-desktop-portal-gtk];
}
