{ config, lib, pkgs, ... }:

let
  cfg = config.services.mycontainers.syncthing;
  clib = import ./_lib { inherit lib; };
in
{
  options.services.mycontainers.syncthing = {
    enable = lib.mkEnableOption "Syncthing file synchronization";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8384;
      description = "Internal web UI port (uses host networking)";
    };

    domain = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "syncthing.home";
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
      default = "${clib.defaults.paths.dataDir}/syncthing";
      description = "Directory for Syncthing configuration";
    };

    syncDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/gamesbackup/syncthing-data";
      description = "Directory for synchronized data";
    };

    smbMount = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable SMB mount for sync directory";
      };

      device = lib.mkOption {
        type = lib.types.str;
        default = "//10.71.71.19/GamesBackup";
        description = "SMB share path";
      };

      mountPoint = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/gamesbackup";
        description = "Mount point for SMB share";
      };

      credentialsFile = lib.mkOption {
        type = lib.types.str;
        default = "/run/secrets/smb-things-secrets";
        description = "Path to SMB credentials file";
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
      # SMB filesystem mount
      fileSystems."${cfg.smbMount.mountPoint}" = lib.mkIf cfg.smbMount.enable {
        device = cfg.smbMount.device;
        fsType = "cifs";
        options = [
          "credentials=${cfg.smbMount.credentialsFile}"
          "uid=1000"
          "gid=100"
          "file_mode=0777"
          "dir_mode=0777"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "_netdev"
          "vers=3.0"
        ];
      };

      virtualisation.oci-containers.containers.syncthing = {
        image = "syncthing/syncthing:latest";
        environment = {
          TZ = clib.defaults.environment.TZ;
          PUID = "1000";
          PGID = "100";
        } // cfg.environment;
        extraOptions = [ "--network" "host" ];
        volumes = [
          "${cfg.dataDir}:/var/syncthing"
          "${cfg.syncDir}:/data"
        ];
      };

      # Ensure service waits for mount
      systemd.services.docker-syncthing = lib.mkIf cfg.smbMount.enable {
        wantedBy = [ "multi-user.target" ];
        after = [ "${builtins.replaceStrings ["/"] ["-"] (lib.removePrefix "/" cfg.smbMount.mountPoint)}.mount" ];
        bindsTo = [ "${builtins.replaceStrings ["/"] ["-"] (lib.removePrefix "/" cfg.smbMount.mountPoint)}.mount" ];
      };
    }

    # Internal nginx proxy (proxy to localhost since using host networking)
    (lib.mkIf (cfg.domain.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.domain.internal}" =
        clib.nginx.mkInternalProxy {
          domain = cfg.domain.internal;
          targetIP = "127.0.0.1";
          targetPort = cfg.port;
        };
    })

    # External nginx proxy
    (lib.mkIf (cfg.domain.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.domain.external}" =
        clib.nginx.mkExternalProxy {
          domain = cfg.domain.external;
          targetIP = "127.0.0.1";
          targetPort = cfg.port;
        };
    })
  ]);
}
