{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.infisical;
  clib = import ./_lib { inherit lib; };
  
  infisicalIP = clib.helpers.mkIP cfg.ipSuffix;
  redisIP = clib.helpers.mkIP cfg.redis.ipSuffix;
  postgresIP = clib.helpers.mkIP cfg.postgres.ipSuffix;
in
{
  options.services.mycontainers.infisical = {
    enable = lib.mkEnableOption "Infisical secrets management";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 80;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for Infisical";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "infisical.home";
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
      default = "${clib.defaults.paths.dataDir}/infisical";
      description = "Directory for Infisical data";
    };
    
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/infisical.env";
      description = "Path to secrets environment file";
    };
    
    siteUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://infisical.home";
      description = "Site URL for Infisical";
    };
    
    redis = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 81;
        description = "Last octet of Redis container IP address";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 6379;
        description = "Redis port";
      };
    };
    
    postgres = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 82;
        description = "Last octet of Postgres container IP address";
      };
    };
    
    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables";
    };
  };
  
  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      sops.secrets."infisical.env" = {};
      
      virtualisation.oci-containers.containers = {
        infisical = {
          image = "infisical/infisical:latest";
          environment = {
            NODE_ENV = "production";
            PORT = toString cfg.port;
            REDIS_URL = "redis://${redisIP}:${toString cfg.redis.port}";
            SITE_URL = cfg.siteUrl;
            TELEMETRY_ENABLED = "false";
          } // cfg.environment;
          environmentFiles = [ cfg.secretsFile ];
          volumes = [
            "${cfg.dataDir}:/app/data"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" infisicalIP
          ];
          ports = [ "${toString cfg.port}:${toString cfg.port}" ];
          dependsOn = [ "infisical_redis" "infisical_postgres" ];
        };
        
        infisical_redis = {
          image = "redis:7.2-alpine";
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" redisIP
          ];
          volumes = [
            "${cfg.dataDir}/redis:/data"
          ];
          cmd = [ "redis-server" "--appendonly" "yes" ];
        };
        
        infisical_postgres = {
          image = "postgres:15-alpine";
          environmentFiles = [ cfg.secretsFile ];
          environment = {
            POSTGRES_INITDB_ARGS = "--encoding=UTF8 --lc-collate=C --lc-ctype=C";
          };
          volumes = [
            "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" postgresIP
          ];
        };
      };
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = infisicalIP;
          targetPort = cfg.port;
          extraConfig = "proxy_buffering off;";
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = infisicalIP;
          targetPort = cfg.port;
          extraConfig = "proxy_buffering off;";
        };
    })
  ]);
}
