{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.kitty;
in {
  options.myhome.kitty = {
    enable = lib.mkEnableOption "Kitty terminal configuration";

    confirmClose = lib.mkOption {
      type = lib.types.bool;
      default = hlib.defaults.kitty.confirmClose;
      description = "Confirm when closing terminal window";
    };

    extraSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Additional kitty settings";
    };

    keyMappings = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        "ctrl+shift+u" = "no_op";
      };
      description = "Custom key mappings for kitty";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.kitty = {
      enable = true;
      settings = lib.mkMerge [
        {
          confirm_os_window_close = if cfg.confirmClose then 1 else 0;
          shell_integration = "no-rc";
        }
        (lib.attrsets.listToAttrs (lib.mapAttrsToList (key: action: {
          name = "map";
          value = "${key} ${action}";
        }) cfg.keyMappings))
        cfg.extraSettings
      ];
    };
  };
}