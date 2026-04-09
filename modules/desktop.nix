{ config, lib, pkgs, pkgs-stable, inputs, options, ... }:

let
  cfg = config.mymodules.desktop;
  mlib = import ./_lib { inherit lib; };
  hyprdynamicmonitors = inputs.hyprdynamicmonitors.packages.${pkgs.system}.default;
in
{
  options.mymodules.desktop = {
    enable = lib.mkEnableOption "Desktop environment (Hyprland + apps)";

    # Login manager options
    login = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable login manager (greetd)";
      };

      autoLogin = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable automatic login on first boot";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = mlib.helpers.defaultUser;
        description = "User for automatic login";
      };

      session = lib.mkOption {
        type = lib.types.enum [ "hyprland" "gamescope" ];
        default = "hyprland";
        description = "Default session to start";
      };
    };

    # Hyprland options
    hyprland = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Hyprland window manager";
      };

      xwayland = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable XWayland for X11 app compatibility";
      };
    };

    # Stylix theming
    stylix = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Stylix theming";
      };

      theme = lib.mkOption {
        type = lib.types.str;
        default = "catppuccin-mocha";
        description = "Base16 theme name";
      };

      polarity = lib.mkOption {
        type = lib.types.enum [ "dark" "light" ];
        default = "dark";
        description = "Theme polarity";
      };
    };

    # Apps grouped by category
    apps = {
      browser = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable web browsers (Zen, Chromium)";
      };

      fileManager = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable file managers (Nautilus, Yazi)";
      };

      notifications = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable notification system (swaync)";
      };

      screenshots = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable screenshot tools (hyprshot)";
      };

      screenRecording = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable screen recording (wf-recorder)";
      };

      localsend = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable LocalSend for file sharing";
      };
    };

    # Extra packages
    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [];
      description = "Additional desktop packages";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base desktop configuration
    {
      hardware.graphics.enable = true;
      services.upower.enable = true;
      security.polkit.enable = true;

      environment.sessionVariables = {
        NIXOS_OZONE_WL = "1";
      };

      # XDG portal for screen sharing etc
      xdg.portal = {
        enable = true;
        extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      };

      # Base desktop packages
      environment.systemPackages = with pkgs; [
        # Terminal
        kitty
        # Cursor
        hyprcursor
        # Wallpaper
        hyprpaper
        # App launcher
        rofi
        # Lock screen
        hyprlock
        # Network manager applet
        networkmanagerapplet
        # Icons
        adwaita-icon-theme
        # Utilities
        bc
        imv
        # Screen management
        hyprdynamicmonitors
        shikane
        # Password manager
        proton-pass
        # Topbar
        hyprsunset
        # Exit helper
        (pkgs.writeShellScriptBin "hyprexit" ''
          ${hyprland}/bin/hyprctl dispatch exit
          ${systemd}/bin/loginctl terminate-user "${cfg.login.user}"
        '')
        # Waybar with experimental features
        (waybar.overrideAttrs (oldAttrs: {
          mesonFlags = oldAttrs.mesonFlags ++ ["-Dexperimental=true"];
        }))
      ] ++ cfg.extraPackages;
    }

    # Hyprland configuration
    (lib.mkIf cfg.hyprland.enable {
      programs.hyprland = {
        enable = true;
        xwayland.enable = cfg.hyprland.xwayland;
        package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
        portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      };

      environment.systemPackages = [
        inputs.hyprdynamicmonitors.packages.${pkgs.system}.default
      ];
      systemd.user.services.hyprdynamicmonitors-prepare = {
          enable = true;
          before= [ "graphical-session-pre.target" ];
          wantedBy = [ "default.target" "graphical-session-pre.target" ];
          description = "hyprdynamicmonitors prepare";
          serviceConfig = {
              Type = "oneshot";
              ExecStart = ''${hyprdynamicmonitors}/bin/hyprdynamicmonitors prepare'';
              TimeoutStartSec = 3;
              RemainAfterExit = "yes";
          };
      };
    })

    # Login manager configuration
    (lib.mkIf cfg.login.enable (
      let
        tuigreet = "${pkgs.tuigreet}/bin/tuigreet";
        sessionCmd = if cfg.login.session == "gamescope"
          then "start-gamescope-session"
          else "dbus-run-session ${pkgs.hyprland}/bin/start-hyprland";
      in {
        services.greetd = {
          enable = true;
          settings = {
            initial_session = lib.mkIf cfg.login.autoLogin {
              command = sessionCmd;
              user = cfg.login.user;
            };
            default_session = {
              command = "${tuigreet} --greeting 'Welcome to NixOS!' --asterisks --remember --remember-user-session --time";
              user = cfg.login.user;
            };
          };
        };
      }
    ))

    # Stylix theming - only if stylix module is available
    (lib.mkIf (cfg.enable && cfg.stylix.enable) (lib.optionalAttrs (options ? stylix) {
      stylix = {
        enable = true;
        base16Scheme = "${pkgs-stable.base16-schemes}/share/themes/${cfg.stylix.theme}.yaml";
        image = ../dotfiles/wallpapers/comfy-home.png;
        polarity = cfg.stylix.polarity;
        cursor = {
          package = pkgs.rose-pine-cursor;
          name = "BreezeX-RosePine-Linux";
          size = 24;
        };
        fonts = {
          sizes = {
            terminal = 16;
            applications = 12;
            desktop = 10;
            popups = 10;
          };

          monospace = {
            package = pkgs.nerd-fonts.fira-code;
            name = "FiraCode Nerd Font Mono";
          };

          sansSerif = {
            package = pkgs.dejavu_fonts;
            name = "DejaVu Sans";
          };

          serif = {
            package = pkgs.dejavu_fonts;
            name = "DejaVu Serif";
          };
        };
        targets = {
          gtk.enable = true;
        };
      };
    }))

    # Browser apps
    (lib.mkIf cfg.apps.browser {
      environment.systemPackages = [
        inputs.zen-browser.packages."${pkgs.stdenv.hostPlatform.system}".default
        (pkgs.ungoogled-chromium.override {
          commandLineArgs = [
            "--enable-features=VaapiVideoDecoder"
            "--enable-remote-extensions"
          ];
        })
        pkgs.floorp-bin
      ];

      # Allow extensions via policy
      environment.etc."chromium/policies/managed/extensions.json".text = builtins.toJSON {
        ExtensionSettings = {
          "*" = {
            allowed_types = ["extension" "theme" "user_script"];
            blocked_install_message = "Extensions are allowed.";
            install_sources = ["*"];
            installation_mode = "allowed";
          };
        };
        ExtensionInstallBlocklist = [];
        ExtensionInstallAllowlist = ["*"];
      };
    })

    # File manager apps
    (lib.mkIf cfg.apps.fileManager {
      environment.systemPackages = with pkgs; [
        nautilus
        yazi
        gnome-multi-writer
      ];
    })

    # Notification system
    (lib.mkIf cfg.apps.notifications {
      environment.systemPackages = with pkgs; [
        swaynotificationcenter
        libnotify
      ];
    })

    # Screenshot tools
    (lib.mkIf cfg.apps.screenshots {
      environment.systemPackages = with pkgs; [
        hyprshot
      ];
    })

    # Screen recording
    (lib.mkIf cfg.apps.screenRecording {
      environment.systemPackages = with pkgs; [
        wf-recorder
      ];
    })

    # LocalSend
    (lib.mkIf cfg.apps.localsend {
      programs.localsend.enable = true;
    })
  ]);
}
