{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.ente;
  clib = import ./_lib { inherit lib; };

  museumIP = clib.helpers.mkIP cfg.ipSuffix;
  postgresIP = clib.helpers.mkIP cfg.postgres.ipSuffix;
  minioIP = clib.helpers.mkIP cfg.minio.ipSuffix;
  webIP = clib.helpers.mkIP cfg.web.ipSuffix;
in
{
  options.services.mycontainers.ente = {
    enable = lib.mkEnableOption "Ente Photos self-hosted server";

    ipSuffix = lib.mkOption {
      type = lib.types.int;
      default = 26;
      description = "Last octet of container IP for Museum server";
    };

    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "ente-api.home";
        description = "Internal domain for Museum API";
      };

      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "External domain for Museum API";
      };
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/photos/ente";
      description = "Base directory for all Ente data (on SMB mount)";
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

    configFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/ente.yaml";
      description = "Path to museum.yaml configuration (from sops)";
    };

    envFile = lib.mkOption {
      type = lib.types.str;
      default = "/run/secrets/ente.env";
      description = "Path to environment file with credentials (from sops)";
    };

    postgres = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 27;
        description = "Last octet of Postgres container IP";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/postgres";
        description = "Directory for PostgreSQL data";
      };
    };

    minio = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 28;
        description = "Last octet of MinIO container IP";
      };

      dataDir = lib.mkOption {
        type = lib.types.str;
        default = "${cfg.dataDir}/minio";
        description = "Directory for MinIO data";
      };
    };

    web = {
      ipSuffix = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Last octet of web container IP";
      };

      domain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "ente.home";
        description = "Internal domain for Ente web (Photos)";
      };

      albumsDomain = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "albums.home";
        description = "Internal domain for public albums";
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables for web container";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      sops.secrets."ente.yaml" = { mode = "0440"; };
      sops.secrets."ente.env" = { mode = "0440"; };
      sops.secrets."smb-photos-secrets" = lib.mkIf cfg.smbMount.enable {};

      # SMB filesystem mount (shared with immich)
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
        # Ente Museum - main API server
        ente_museum = {
          image = "ghcr.io/ente-io/server";
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
            "--health-cmd" "wget --quiet --tries=1 --spider http://localhost:8080/ping"
            "--health-start-period" "120s"
            "--health-interval" "60s"
            "--health-timeout" "5s"
            "--health-retries" "3"
          ];
          ports = [ "8088:8080" ];
          dependsOn = [ "ente_postgres" "ente_minio" ];
        };

        # Socat - resolves localhost:3200 in museum container to minio
        # Uses --net container: to share museum's network namespace.
        # Cannot use --add-host with container network mode, so we use the IP directly.
        ente_socat = {
          image = "alpine/socat";
          cmd = [ "TCP-LISTEN:3200,fork,reuseaddr" "TCP:${minioIP}:3200" ];
          extraOptions = [
            "--net" "container:ente_museum"
          ];
          dependsOn = [ "ente_museum" ];
        };

        # Ente Web - Photos and public albums
        ente_web = {
          image = "ghcr.io/ente-io/web";
          environment = {
            # These origins are used client-side by the browser.
            # Adjust to match how clients reach the services (via ingress domains or host:port).
            ENTE_API_ORIGIN = "http://localhost:8080";
            ENTE_ALBUMS_ORIGIN = "http://localhost:3002";
            ENTE_PHOTOS_ORIGIN = "http://localhost:3000";
          } // cfg.environment;
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" webIP
          ];
          ports = [
            "3001:3000" # Photos web app
            "3002:3002" # Public albums
          ];
          dependsOn = [ "ente_museum" ];
        };

        # PostgreSQL
        ente_postgres = {
          image = "postgres:15";
          environmentFiles = [ cfg.envFile ];
          volumes = [
            "${cfg.postgres.dataDir}:/var/lib/postgresql/data"
          ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" postgresIP
            "--user" "${toString cfg.smbMount.uid}:${toString cfg.smbMount.gid}"
            "--health-cmd" "pg_isready -q -d ente_db -U pguser"
            "--health-start-period" "120s"
            "--health-interval" "1s"
          ];
        };

        # MinIO - S3-compatible storage
        ente_minio = {
          image = "minio/minio";
          cmd = [ "server" "/data" "--address" ":3200" "--console-address" ":3201" ];
          environmentFiles = [ cfg.envFile ];
          volumes = [ "${cfg.minio.dataDir}:/data" ];
          extraOptions = [
            "--net" clib.defaults.network.name
            "--ip" minioIP
            "--user" "${toString cfg.smbMount.uid}:${toString cfg.smbMount.gid}"
          ];
          ports = [ "3200:3200" ];
        };
      };

      # Ensure data directories exist (all on SMB mount)
      systemd.tmpfiles.rules = [
        "d ${cfg.dataDir} 0755 ${toString cfg.smbMount.uid} ${toString cfg.smbMount.gid} -"
        "d ${cfg.dataDir}/data 0755 ${toString cfg.smbMount.uid} ${toString cfg.smbMount.gid} -"
        "d ${cfg.postgres.dataDir} 0750 ${toString cfg.smbMount.uid} ${toString cfg.smbMount.gid} -"
        "d ${cfg.minio.dataDir} 0755 ${toString cfg.smbMount.uid} ${toString cfg.smbMount.gid} -"
      ];

      # MinIO bucket initialization (equivalent to compose post_start)
      systemd.services.ente-minio-init = {
        description = "Initialize MinIO buckets for Ente";
        after = [ "docker-ente_minio.service" ];
        requires = [ "docker-ente_minio.service" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        path = [ pkgs.docker ];
        script = ''
          for i in $(seq 1 30); do
            if docker exec ente_minio sh -c 'mc alias set h0 http://localhost:3200 $MINIO_ROOT_USER $MINIO_ROOT_PASSWORD' 2>/dev/null; then
              break
            fi
            echo "Waiting for MinIO... ($i/30)"
            sleep 2
          done
          docker exec ente_minio mc mb -p h0/b2-eu-cen 2>/dev/null || true
          docker exec ente_minio mc mb -p h0/wasabi-eu-central-2-v3 2>/dev/null || true
          docker exec ente_minio mc mb -p h0/scw-eu-fr-v3 2>/dev/null || true
        '';
      };
    }

    # Museum API internal ingress
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" =
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = museumIP;
          targetPort = 8080;
          clientMaxBodySize = "10G";
        };
    })

    # Web (Photos) internal ingress
    (lib.mkIf (cfg.web.domain != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.domain}" =
        clib.nginx.mkInternalProxy {
          domain = cfg.web.domain;
          targetIP = webIP;
          targetPort = 3000;
          clientMaxBodySize = "10G";
        };
    })

    # Web (Public Albums) internal ingress
    (lib.mkIf (cfg.web.albumsDomain != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.web.albumsDomain}" =
        clib.nginx.mkInternalProxy {
          domain = cfg.web.albumsDomain;
          targetIP = webIP;
          targetPort = 3002;
        };
    })
  ]);
}
