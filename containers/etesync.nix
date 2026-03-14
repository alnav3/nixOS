{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.etesync;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.etesync = {
    enable = lib.mkEnableOption "EteSync synchronization service";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 44;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 3735;
      description = "Internal port for EteSync";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "etesync.home";
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
      default = "${clib.defaults.paths.dataDir}/etesync";
      description = "Directory for EteSync data";
    };
    
    allowedHosts = lib.mkOption {
      type = lib.types.str;
      default = "etesync.home,${containerIP},localhost,127.0.0.1";
      description = "Allowed hosts for EteSync";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      # Ensure data directory exists with correct permissions (UID 373)
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 373 373 -"
      ];
      
      virtualisation.oci-containers.containers.etesync = {
        image = "victorrds/etesync:latest";
        environment = {
          TZ = clib.defaults.environment.TZ;
          ALLOWED_HOSTS = cfg.allowedHosts;
        } // cfg.environment;
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.dataDir}:/data"
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
