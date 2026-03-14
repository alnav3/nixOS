{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.mautrix-telegram;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.mautrix-telegram = {
    enable = lib.mkEnableOption "Mautrix-Telegram bridge for Matrix";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 51;
      description = "Last octet of container IP address";
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/mautrix-telegram";
      description = "Directory for Mautrix-Telegram data";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.mautrix-telegram = {
      image = "dock.mau.dev/mautrix/telegram:latest";
      volumes = [
        "${cfg.dataDir}:/data"
      ];
      environment = cfg.environment;
      extraOptions = [
        "--net" clib.defaults.network.name
        "--ip" containerIP
      ];
      dependsOn = [ "synapse" ];
    };
  };
}
