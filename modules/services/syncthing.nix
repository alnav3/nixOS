{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.services.syncthing;
  mlib = import ../_lib { inherit lib; };
in
{
  options.mymodules.services.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";

    user = lib.mkOption {
      type = lib.types.str;
      default = mlib.helpers.defaultUser;
      description = "User to run Syncthing as";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = mlib.helpers.defaultHome;
      description = "Default data directory";
    };

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "${mlib.helpers.defaultHome}/.config";
      description = "Configuration directory";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open default Syncthing ports in firewall";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      openDefaultPorts = cfg.openFirewall;
      user = cfg.user;
      dataDir = cfg.dataDir;
      configDir = cfg.configDir;
    };
  };
}
