{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.hyprpanel;
in {
  options.myhome.hyprpanel = {
    enable = lib.mkEnableOption "Hyprpanel configuration";

    font = {
      name = lib.mkOption {
        type = lib.types.str;
        default = hlib.defaults.theme.font.name;
        description = "Font family for hyprpanel";
      };

      size = lib.mkOption {
        type = lib.types.str;
        default = hlib.defaults.theme.font.size;
        description = "Font size for hyprpanel";
      };
    };

    layout = lib.mkOption {
      type = lib.types.attrs;
      default = {
        bar.layouts = {
          "0" = {
            left = [ "dashboard" "workspaces" ];
            middle = [ "media" ];
            right = [ "volume" "systray" "notifications" ];
          };
        };
      };
      description = "Layout configuration for hyprpanel";
    };

    bar = {
      transparent = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable transparent bar";
      };

      launcher.autoDetectIcon = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Auto-detect application icons";
      };

      workspaces.showIcons = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Show icons in workspaces";
      };
    };

    menus = {
      clock = {
        military = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Use 24-hour time format";
        };

        hideSeconds = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Hide seconds in clock";
        };

        weatherUnit = lib.mkOption {
          type = lib.types.str;
          default = "metric";
          description = "Weather unit system";
        };
      };

      dashboard = {
        directoriesEnabled = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable directories in dashboard";
        };

        enableGpuStats = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Enable GPU statistics";
        };
      };
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional hyprpanel settings";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.hyprpanel.settings = lib.mkMerge [
      {
        inherit (cfg) layout;

        bar = {
          launcher.autoDetectIcon = cfg.bar.launcher.autoDetectIcon;
          workspaces.show_icons = cfg.bar.workspaces.showIcons;
        };

        menus = {
          clock = {
            time = {
              military = cfg.menus.clock.military;
              hideSeconds = cfg.menus.clock.hideSeconds;
            };
            weather.unit = cfg.menus.clock.weatherUnit;
          };

          dashboard = {
            directories.enabled = cfg.menus.dashboard.directoriesEnabled;
            stats.enable_gpu = cfg.menus.dashboard.enableGpuStats;
          };
        };

        theme = {
          bar.transparent = cfg.bar.transparent;
          font = {
            name = cfg.font.name;
            size = cfg.font.size;
          };
        };
      }
      cfg.extraSettings
    ];
  };
}