{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.ente;
  clib = import ./_lib { inherit lib; };
  
  museumIP = clib.helpers.mkIP cfg.ipSuffix;
  postgresIP = clib.helpers.mkIP cfg.postgres.ipSuffix;
  minioIP = clib.helpers.mkIP cfg.minio.ipSuffix;
  socatIP = clib.helpers.mkIP cfg.socat.ipSuffix;
  webIP = clib.helpers.mkIP cfg.web.ipSuffix;
in
{
  options.services.mycontainers.ente = {
    enable = lib.mkEnableOption "Ente Photos self-hosted server";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 26;
      description = "Last octet of container IP address for Museum server";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Internal port for Ente Museum server";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "ente-api.home";
        description = "Internal domain name for Museum API";
      };
      
      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External domain name (null = no external access)";
      };
    };
    
    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "${clib.defaults.paths.dataDir}/ente";
      description = "Base directory for Ente data";
    };
    
    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/ente.yaml";
      description = "Path to museum.yaml configuration file (from sops secrets)";
    };
    
    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/ente.env";
      description = "Path to environment variables file (from sops secrets)";
    };
    
    postgres = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 27;
        description = "Last octet of Postgres container IP address";
      };
      
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/postgres";
        description = "Directory for PostgreSQL data";
      };
      
      database = lib.mkOption {
        type = lib.types.str;
        default = "ente_db";
        description = "PostgreSQL database name";
      };
      
      user = lib.mkOption {
        type = lib.types.str;
        default = "pguser";
        description = "PostgreSQL user";
      };
    };
    
    minio = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable MinIO for S3-compatible storage";
      };
      
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 28;
        description = "Last octet of MinIO container IP address";
      };
      
      port = lib.mkOption {
        type = lib.types.port;
        default = 3200;
        description = "MinIO API port";
      };
      
      consolePort = lib.mkOption {
        type = lib.types.port;
        default = 3201;
        description = "MinIO Console port";
      };
      
      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/minio";
        description = "Directory for MinIO data";
      };
      
      domain = {
        internal = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "minio.home";
          description = "Internal domain name for MinIO console";
        };
      };
    };
    
    socat = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable socat to redirect localhost:3200 to minio";
      };
      
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 29;
        description = "Last octet of socat container IP address";
      };
    };
    
    web = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Ente web interface";
      };
      
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Last octet of web container IP address";
      };
      
      domains = {
        photos = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "ente.home";
          description = "Internal domain for Photos app";
        };
        
        accounts = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "accounts.home";
          description = "Internal domain for Accounts app";
        };
        
        albums = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "albums.home";
          description = "Internal domain for Albums app";
        };
        
        cast = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "cast.home";
          description = "Internal domain for Cast app";
        };
        
        locker = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "locker.home";
          description = "Internal domain for Locker/Share app";
        };
        
        embedAlbums = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "embed.home";
          description = "Internal domain for Embed Albums app";
        };
        
        paste = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = "paste.home";
          description = "Internal domain for Paste app";
        };
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
      # Setup sops secrets for ente configuration
      sops.secrets."ente.yaml" = {
        mode = "0440";
      };
      sops.secrets."ente.env" = {
        mode = "0440";
      };
      
      virtualisation.oci-containers.containers = {
        # Ente Museum (main API server)
        ente_museum = {
          image = "ghcr.io/ente-io/server:latest";
          environment = clib.helpers.mkEnv (cfg.environment);
          environmentFiles = [ cfg.envFile ];
          volumes = [
            "${cfg.configFile}:/museum.yaml:ro"
            "${cfg.dataDir}/data:/data:ro"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" museumIP
            "--add-host" "postgres:${postgresIP}"
            "--add-host" "minio:${minioIP}"
          ];
          ports = [];
          dependsOn = [ "ente_postgres" ] ++ lib.optional cfg.minio.enable "ente_minio";
        };
        
        # PostgreSQL database (postgres:15-trixie as in docker-compose)
        ente_postgres = {
          image = "postgres:15-trixie";
          environmentFiles = [ cfg.envFile ];
          volumes = [
            "${cfg.postgres.dataDir}:/var/lib/postgresql/data"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" postgresIP
            "--health-cmd" "pg_isready -q -d ${cfg.postgres.database} -U ${cfg.postgres.user}"
            "--health-start-period" "30s"
            "--health-interval" "1s"
          ];
          ports = [];
        };
      } // lib.optionalAttrs cfg.minio.enable {
        # MinIO for S3-compatible storage
        ente_minio = {
          image = "minio/minio:latest";
          cmd = [ "server" "/data" "--address" ":${toString cfg.minio.port}" "--console-address" ":${toString cfg.minio.consolePort}" ];
          environmentFiles = [ cfg.envFile ];
          volumes = [
            "${cfg.minio.dataDir}:/data"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" minioIP
          ];
          ports = [];
        };
      } // lib.optionalAttrs cfg.socat.enable {
        # Socat to redirect localhost:3200 -> minio:3200 for museum container
        # This solves the localhost endpoint issue in museum.yaml
        ente_socat = {
          image = "alpine/socat:latest";
          cmd = [ "TCP-LISTEN:3200,fork,reuseaddr" "TCP:minio:${toString cfg.minio.port}" ];
          extraOptions = [
            "--net" "container:ente_museum"
          ];
          dependsOn = [ "ente_museum" ];
          ports = [];
        };
      } // lib.optionalAttrs cfg.web.enable {
        # Ente Web Interface (photos, albums, accounts, etc.)
        ente_web = {
          image = "ghcr.io/ente-io/web:latest";
          environment = clib.helpers.mkEnv ({
            NODE_ENV = "production";
            ENTE_API_ORIGIN = "http://${cfg.domain.internal}:${toString cfg.port}";
            ENTE_PHOTOS_ORIGIN = lib.mkIf (cfg.web.domains.photos != null) "http://${cfg.web.domains.photos}";
            ENTE_ALBUMS_ORIGIN = lib.mkIf (cfg.web.domains.albums != null) "http://${cfg.web.domains.albums}";
            ENTE_ACCOUNTS_ORIGIN = lib.mkIf (cfg.web.domains.accounts != null) "http://${cfg.web.domains.accounts}";
            ENTE_CAST_ORIGIN = lib.mkIf (cfg.web.domains.cast != null) "http://${cfg.web.domains.cast}";
            ENTE_LOCKER_ORIGIN = lib.mkIf (cfg.web.domains.locker != null) "http://${cfg.web.domains.locker}";
            ENTE_EMBED_ALBUMS_ORIGIN = lib.mkIf (cfg.web.domains.embedAlbums != null) "http://${cfg.web.domains.embedAlbums}";
            ENTE_PASTE_ORIGIN = lib.mkIf (cfg.web.domains.paste != null) "http://${cfg.web.domains.paste}";
          });
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" webIP
          ];
          ports = [];
          dependsOn = [ "ente_museum" ];
        };
      };
      
      # Ensure data directories exist with correct permissions
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 root root -"
        "d ${cfg.dataDir}/data 0755 root root -"
        "d ${cfg.postgres.dataDir} 0750 root root -"
      ] ++ lib.optional cfg.minio.enable "d ${cfg.minio.dataDir} 0755 root root -";
    }
    
    # Internal nginx proxy for Museum API
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = museumIP;
          targetPort = cfg.port;
          clientMaxBodySize = "5G";
        };
    })
    
    # Internal nginx proxy for MinIO Console (optional, for admin access)
    (lib.mkIf (cfg.minio.enable && cfg.minio.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.minio.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.minio.domain.internal;
          targetIP = minioIP;
          targetPort = cfg.minio.consolePort;
        };
    })
    
    # Internal nginx proxies for Ente Web Apps
    (lib.mkIf (cfg.web.enable && cfg.web.domains.photos != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.photos}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.photos;
          targetIP = webIP;
          targetPort = 3000;
        };
    })
    
    (lib.mkIf (cfg.web.enable && cfg.web.domains.accounts != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.accounts}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.accounts;
          targetIP = webIP;
          targetPort = 3001;
        };
    })
    
    (lib.mkIf (cfg.web.enable && cfg.web.domains.albums != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.albums}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.albums;
          targetIP = webIP;
          targetPort = 3002;
        };
    })
    
    (lib.mkIf (cfg.web.enable && cfg.web.domains.cast != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.cast}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.cast;
          targetIP = webIP;
          targetPort = 3004;
        };
    })
    
    (lib.mkIf (cfg.web.enable && cfg.web.domains.locker != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.locker}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.locker;
          targetIP = webIP;
          targetPort = 3005;
        };
    })
    
    (lib.mkIf (cfg.web.enable && cfg.web.domains.embedAlbums != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.embedAlbums}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.embedAlbums;
          targetIP = webIP;
          targetPort = 3006;
        };
    })
    
    (lib.mkIf (cfg.web.enable && cfg.web.domains.paste != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domains.paste}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domains.paste;
          targetIP = webIP;
          targetPort = 3008;
        };
    })
  ]);
}
