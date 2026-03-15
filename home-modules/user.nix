{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: let
  hlib = import ./_lib {inherit lib;};
  cfg = config.myhome.user;
in {
  options.myhome.user = {
    enable = lib.mkEnableOption "user configuration";

    username = lib.mkOption {
      type = lib.types.str;
      default = hlib.defaults.user.username;
      description = "Username for home-manager";
    };

    homeDirectory = lib.mkOption {
      type = lib.types.str;
      default = hlib.defaults.user.homeDirectory;
      description = "Home directory path";
    };

    stateVersion = lib.mkOption {
      type = lib.types.str;
      default = hlib.defaults.user.stateVersion;
      description = "Home Manager state version";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.home-manager.enable = true;
    
    home = {
      username = cfg.username;
      homeDirectory = cfg.homeDirectory;
      stateVersion = cfg.stateVersion;
    };
  };
}