{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.trmnl;
  clib = import ./_lib { inherit lib; };
  
  containerIP = clib.helpers.mkIP cfg.ipSuffix;
in
{
  options.services.mycontainers.trmnl = {
    enable = lib.mkEnableOption "TRMNL dashboard service";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 45;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for TRMNL";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "trmnl.home";
        description = "Internal domain name";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "trmnl.alnav.dev";
        description = "External domain name (enables external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/trmnl";
      description = "Directory for TRMNL data";
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      virtualisation.oci-containers.containers.trmnl = {
        image = "ghcr.io/usetrmnl/byos_laravel:latest";
        environment = {
          PHP_OPCACHE_ENABLE = "1";
          TRMNL_PROXY_REFRESH_MINUTES = "15";
          DB_DATABASE = "database/storage/database.sqlite";
        } // cfg.environment;
        extraOptions = [
          "--net" clib.defaults.network.name
          "--ip" containerIP
        ];
        volumes = [
          "${cfg.dataDir}/database:/var/www/html/database/storage"
          "${cfg.dataDir}/storage:/var/www/html/storage/app/public/images/generated"
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
