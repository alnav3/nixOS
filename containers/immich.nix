{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.immich;
  clib = import ./_lib { inherit lib; };
  
  immichIP = clib.helpers.mkIP cfg.ipSuffix;
  postgresIP = clib.helpers.mkIP cfg.postgres.ipSuffix;
  redisIP = clib.helpers.mkIP cfg.redis.ipSuffix;
in
{
  options.services.mycontainers.immich = {
    enable = lib.mkEnableOption "Immich photo management";
    
    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 23;
      description = "Last octet of container IP address";
    };
    
    port = lib.mkOption {
      type = lib.types.port;
      default = 2283;
      description = "Internal port for Immich";
    };
    
    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "photos.home";
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
      default = "${clib.defaults.paths.dataDir}/immich";
      description = "Directory for Immich data";
    };
    
    photosDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/photos/immich";
      description = "Directory for photos (upload location)";
    };
    
    secretsFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/immich.env";
      description = "Path to secrets environment file";
    };
    
    smbMount = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SMB mount for photos";
      };
      
      device = lib.mkOption {
        type = lib.types.str;
        default = "//10.71.71.19/photos";
        description = "SMB share path for photos";
      };
      
      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/photos";
        description = "Mount point for photos SMB share";
      };
      
      credentialsFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/smb-photos-secrets";
        description = "Path to SMB credentials file";
      };
      
      uid = lib.mkOption {
        type = lib.types.int;
        default = 1234;
        description = "UID for mounted files";
      };
      
      gid = lib.mkOption {
        type = lib.types.int;
        default = 1235;
        description = "GID for mounted files";
      };
    };
    
    postgres = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 24;
        description = "Last octet of Postgres container IP address";
      };
    };
    
    redis = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 25;
        description = "Last octet of Redis container IP address";
      };
    };
    
    machineLearning = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable machine learning container";
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
      sops.secrets."smb-photos-secrets" = lib.mkIf cfg.smbMount.enable {};
      sops.secrets."immich.env" = {};
      
      # SMB filesystem mount
      fileSystems."${cfg.smbMount.mountPoint}" = lib.mkIf cfg.smbMount.enable {
        device = cfg.smbMount.device;
        fsType = "cifs";
        options = [
          "credentials=${cfg.smbMount.credentialsFile}"
          "uid=${toString cfg.smbMount.uid}"
          "gid=${toString cfg.smbMount.gid}"
          "file_mode=0700"
          "dir_mode=0700"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "_netdev"
          "vers=3.0"
        ];
      };
      
      virtualisation.oci-containers.containers = {
        immich_server = {
          image = "ghcr.io/immich-app/immich-server:release";
          environment = {
            PUID = toString cfg.smbMount.uid;
            PGID = toString cfg.smbMount.gid;
            TZ = clib.defaults.environment.TZ;
          } // cfg.environment;
          environmentFiles = [ cfg.secretsFile ];
          volumes = [
            "${cfg.photosDir}:/data"
            "/etc/localtime:/etc/localtime:ro"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" immichIP
          ];
          ports = [ "${toString cfg.port}:${toString cfg.port}" ];
          dependsOn = [ "redis" "immich_postgres" ];
          serviceName = "immich_server";
        };
        
        immich_postgres = {
          image = "ghcr.io/immich-app/postgres:14-vectorchord0.4.3-pgvectors0.2.0";
          environmentFiles = [ cfg.secretsFile ];
          volumes = [
            "${cfg.dataDir}/postgres:/var/lib/postgresql/data"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" postgresIP
          ];
        };
        
        redis = {
          image = "docker.io/valkey/valkey:8-bookworm@sha256:facc1d2c3462975c34e10fccb167bfa92b0e0dbd992fc282c29a61c3243afb11";
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" redisIP
          ];
          ports = [];
        };
      } // lib.optionalAttrs cfg.machineLearning.enable {
        immich_machine_learning = {
          image = "ghcr.io/immich-app/immich-machine-learning:release";
          volumes = [
            "${cfg.dataDir}/model-cache:/cache"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
          ];
        };
      };
    }
    
    # Internal nginx proxy
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" = 
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = immichIP;
          targetPort = cfg.port;
          clientMaxBodySize = "10G";
        };
    })
    
    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" = 
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = immichIP;
          targetPort = cfg.port;
          clientMaxBodySize = "10G";
        };
    })
  ]);
}
