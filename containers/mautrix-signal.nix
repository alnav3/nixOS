{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.mautrix-signal;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.mautrix-signal = {
    enable = lib.mkEnableOption "Mautrix-Signal bridge for Matrix";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 52;
      description = "Last octet of container IP address";
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/mautrix-signal";
      description = "Directory for Mautrix-Signal data";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.mautrix-signal = {
      image = "dock.mau.dev/mautrix/signal:latest";
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
