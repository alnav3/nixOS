{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.jellyseerr;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.jellyseerr = {
    enable = lib.mkEnableOption "Jellyseerr media request management";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 35;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 5055;
      description = "Internal port for Jellyseerr";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "jellyseerr.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External domain name (enables external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/jellyseerr";
      description = "Directory for Jellyseerr configuration";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.jellyseerr = {
        image = "fallenbagel/jellyseerr:latest";
        environment = clib.helpers.mkEnv ({
          PUID = "994";
          PGID = "104";
          LOG_LEVEL = "debug";
          PORT = toString cfg.port;
        } // cfg.environment);
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
          "--health-cmd" "wget --no-verbose --tries=1 --spider http://localhost:${toString cfg.port}/api/v1/status || exit 1"
          "--health-start-period" "20s"
          "--health-timeout" "3s"
          "--health-interval" "15s"
          "--health-retries" "3"
        ];
        volumes = [
          "${cfg.dataDir}:/app/config"
        ];
        ports = [];
      };
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = containerIP;
          targetPort = cfg.port;
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = containerIP;
          targetPort = cfg.port;
        };
    })
  ]);
}
