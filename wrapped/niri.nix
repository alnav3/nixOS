{ pkgs, inputs, lib, noctaliaPackage, ... }:

let
  noctaliaExe = lib.getExe noctaliaPackage;

  # ── Fonts ────────────────────────────────────────────────
  fontPackages = with pkgs; [
    nerd-fonts.fira-code
    dejavu_fonts
  ];

  fontsConf = pkgs.makeFontsConf {
    fontDirectories = fontPackages;
  };

  # ── Kitty (wrapped with config + Catppuccin Mocha) ──────
  kittyConfig = pkgs.writeText "kitty.conf" ''
    # Settings
    confirm_os_window_close 0
    shell_integration       no-rc
    map ctrl+shift+u        no_op

    # Font
    font_family      FiraCode Nerd Font Mono
    font_size        16

    # Catppuccin Mocha
    foreground              #CDD6F4
    background              #1E1E2E
    selection_foreground    #1E1E2E
    selection_background    #F5E0DC
    cursor                  #F5E0DC
    cursor_text_color       #1E1E2E
    url_color               #F5E0DC
    active_border_color     #B4BEFE
    inactive_border_color   #6C7086
    bell_border_color       #F9E2AF
    active_tab_foreground   #11111B
    active_tab_background   #CBA6F7
    inactive_tab_foreground #CDD6F4
    inactive_tab_background #181825
    tab_bar_background      #11111B
    mark1_foreground        #1E1E2E
    mark1_background        #B4BEFE
    mark2_foreground        #1E1E2E
    mark2_background        #CBA6F7
    mark3_foreground        #1E1E2E
    mark3_background        #74C7EC
    color0  #45475A
    color8  #585B70
    color1  #F38BA8
    color9  #F38BA8
    color2  #A6E3A1
    color10 #A6E3A1
    color3  #F9E2AF
    color11 #F9E2AF
    color4  #89B4FA
    color12 #89B4FA
    color5  #F5C2E7
    color13 #F5C2E7
    color6  #94E2D5
    color14 #94E2D5
    color7  #BAC2DE
    color15 #A6ADC8
  '';

  patchedNiri = pkgs.niri.overrideAttrs (old: {
       patches = (old.patches or []) ++ [
         ./patches/no-decorations.patch
       ];
    });
  wrappedKitty = pkgs.symlinkJoin {
    name = "kitty-wrapped";
    paths = [ pkgs.kitty ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kitty \
        --add-flags "--config ${kittyConfig}"
    '';
  };

  # ── Wallpaper ────────────────────────────────────────────
  wallpaper = ../dotfiles/wallpapers/comfy-home.png;

  wallpaperScript = lib.getExe (
    pkgs.writeShellScriptBin "wallpaper"
      "${lib.getExe pkgs.swaybg} -i ${wallpaper} -m fill"
  );

  gtkSettings = pkgs.writeText "gtk-settings.ini" ''
    [Settings]
    gtk-theme-name=catppuccin-mocha-mauve-standard+default
    gtk-icon-theme-name=Adwaita
    gtk-cursor-theme-name=
    gtk-cursor-theme-size=0
    gtk-font-name=DejaVu Sans 12
  '';

  gtk4Settings = pkgs.writeText "gtk4-settings.ini" ''
    [Settings]
    gtk-cursor-theme-name=
    gtk-cursor-theme-size=0
    gtk-font-name=DejaVu Sans 12
  '';

in
inputs.wrapper-modules.wrappers.niri.wrap {
    pkgs = pkgs // {
        niri = patchedNiri;
    };

  # ── Environment variables ────────────────────────────────
  env = {
    XCURSOR_THEME = "";             # Empty theme + zero size = invisible
    XCURSOR_SIZE = "0";             # Zero size for invisible cursor
    FONTCONFIG_FILE = fontsConf;
    NIXOS_OZONE_WL = "1";
    WLR_NO_HARDWARE_CURSORS = "1";  # Disable hardware cursors
  };

  extraPackages = with pkgs; [
    wrappedKitty
    bruno
    tmux
    wireplumber     # wpctl
    brightnessctl
    playerctl
    grim
    slurp
    wl-clipboard
    libnotify
    adwaita-icon-theme
    catppuccin-gtk
  ] ++ fontPackages;

  runShell = [
    ''
      mkdir -p "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
      [ ! -f "$HOME/.config/gtk-3.0/settings.ini" ] && cp ${gtkSettings} "$HOME/.config/gtk-3.0/settings.ini" || true
      [ ! -f "$HOME/.config/gtk-4.0/settings.ini" ] && cp ${gtk4Settings} "$HOME/.config/gtk-4.0/settings.ini" || true
    ''
  ];

  prefixVar = [
    [ "XDG_DATA_DIRS" ":" "${pkgs.catppuccin-gtk}/share" ]
    [ "XDG_DATA_DIRS" ":" "${pkgs.adwaita-icon-theme}/share" ]
  ];

  settings = {
    prefer-no-csd = null;

    input = {
      focus-follows-mouse = null;
      keyboard = {
        xkb.layout = "us";
      };
      touchpad = {
        natural-scroll = null;
        tap = null;
      };
    };

    layout = {
      gaps = 5;
      struts = {
        left = 20;
        right = 20;
        top = 20;
        bottom = 20;
      };
      border = {
        width = 2;
        active-color = "#33ccff";
        inactive-color = "#595959";
      };
      focus-ring = {
        off = null;
      };
      default-column-width = {
        proportion = 1.0;
      };
    };

    binds = {
      "Mod+Q".spawn-sh = "kitty -e tmux new-session -A -s develop";
      "Mod+C".close-window = null;
      "Mod+Shift+M".quit = null;
      "Alt+T".spawn-sh = "${noctaliaExe} ipc call launcher toggle";
      "Mod+F".maximize-column = null;
      "Mod+Ctrl+F".fullscreen-window = null;
      "Mod+Shift+F".toggle-window-floating = null;
      "Mod+H".focus-column-left = null;
      "Mod+L".focus-column-right = null;
      "Mod+K".focus-window-up = null;
      "Mod+J".focus-window-down = null;
      "Mod+Shift+H".move-column-left = null;
      "Mod+Shift+L".move-column-right = null;
      "Mod+Shift+K".move-window-up = null;
      "Mod+Shift+J".move-window-down = null;
      "Mod+Period".consume-or-expel-window-right = null;
      "Mod+Comma".consume-or-expel-window-left = null;
      "Mod+Ctrl+H".set-column-width = "-5%";
      "Mod+Ctrl+L".set-column-width = "+5%";
      "Mod+Ctrl+J".set-window-height = "-5%";
      "Mod+Ctrl+K".set-window-height = "+5%";
      "Mod+1".focus-workspace = "w0";
      "Mod+2".focus-workspace = "w1";
      "Mod+3".focus-workspace = "w2";
      "Mod+4".focus-workspace = "w3";
      "Mod+5".focus-workspace = "w4";
      "Mod+6".focus-workspace = "w5";
      "Mod+7".focus-workspace = "w6";
      "Mod+8".focus-workspace = "w7";
      "Mod+9".focus-workspace = "w8";
      "Mod+0".focus-workspace = "w9";
      "Mod+Shift+1".move-column-to-workspace = "w0";
      "Mod+Shift+2".move-column-to-workspace = "w1";
      "Mod+Shift+3".move-column-to-workspace = "w2";
      "Mod+Shift+4".move-column-to-workspace = "w3";
      "Mod+Shift+5".move-column-to-workspace = "w4";
      "Mod+Shift+6".move-column-to-workspace = "w5";
      "Mod+Shift+7".move-column-to-workspace = "w6";
      "Mod+Shift+8".move-column-to-workspace = "w7";
      "Mod+Shift+9".move-column-to-workspace = "w8";
      "Mod+Shift+0".move-column-to-workspace = "w9";
      "Mod+WheelScrollDown".focus-workspace-down = null;
      "Mod+WheelScrollUp".focus-workspace-up = null;
      "Mod+P".screenshot-screen = null;
      "Mod+Shift+P".screenshot = null;
      "XF86AudioRaiseVolume".spawn-sh = "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
      "XF86AudioLowerVolume".spawn-sh = "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-";
      "XF86AudioMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
      "XF86AudioMicMute".spawn-sh = "wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle";
      "F12".spawn-sh = "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
      "F11".spawn-sh = "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%-";

      # ── Brightness ──
      "XF86MonBrightnessUp".spawn-sh = "brightnessctl -e4 -n2 set 5%+";
      "XF86MonBrightnessDown".spawn-sh = "brightnessctl -e4 -n2 set 5%-";

      # ── Media ──
      "XF86AudioPlay".spawn-sh = "playerctl play-pause";
      "XF86AudioPause".spawn-sh = "playerctl play-pause";
      "XF86AudioNext".spawn-sh = "playerctl next";
      "XF86AudioPrev".spawn-sh = "playerctl previous";
    };

    # ── Named workspaces ───────────────────────────────────
    workspaces = {
      "w0" = null;
      "w1" = null;
      "w2" = null;
      "w3" = null;
      "w4" = null;
      "w5" = null;
      "w6" = null;
      "w7" = null;
      "w8" = null;
      "w9" = null;
    };

    # ── Window rules ───────────────────────────────────────
    window-rules = [
      {
        matches = [{ app-id = ".*"; }];
        geometry-corner-radius = [ 10.0 10.0 10.0 10.0 ];
        clip-to-geometry = true;
      }
    ];

    # ── XWayland ───────────────────────────────────────────
    xwayland-satellite.path = lib.getExe pkgs.xwayland-satellite;

    # ── Startup ────────────────────────────────────────────
    spawn-at-startup = [
      noctaliaExe
      wallpaperScript
    ];
  };
}
