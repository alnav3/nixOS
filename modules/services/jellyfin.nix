{ config, lib, pkgs, ... }:

let
  cfg = config.mymodules.services.jellyfin;
in
{
  options.mymodules.services.jellyfin = {
    enable = lib.mkEnableOption "Jellyfin media server";

    user = lib.mkOption {
      type = lib.types.str;
      default = "jellyfin";
      description = "User to run Jellyfin as";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "transcoding";
      description = "Group for Jellyfin";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Open Jellyfin port in firewall";
    };

    # Intel hardware acceleration
    intel = {
      vaapi = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Intel VA-API hardware acceleration";
      };

      qsv = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Intel QuickSync (11th gen+)";
      };

      openclCompute = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable OpenCL for HDR tonemapping";
      };
    };

    # SMB mounts
    mounts = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable SMB mounts for media";
      };

      credentialsSecret = lib.mkOption {
        type = lib.types.str;
        default = "smb-things-secrets";
        description = "SOPS secret name for SMB credentials";
      };

      mediaPath = lib.mkOption {
        type = lib.types.str;
        default = "//10.71.71.19/media";
        description = "SMB path for media";
      };

      thingsPath = lib.mkOption {
        type = lib.types.str;
        default = "//10.71.71.19/things";
        description = "SMB path for things (downloads)";
      };

      containersPath = lib.mkOption {
        type = lib.types.str;
        default = "//10.71.71.19/podvolumes";
        description = "SMB path for container volumes";
      };
    };

    # Backup configuration
    backup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Jellyfin backup to SMB";
      };

      schedule = lib.mkOption {
        type = lib.types.str;
        default = "03:00";
        description = "Backup schedule (OnCalendar format)";
      };
    };

    # Nginx proxy
    proxy = {
      internal = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "tv.home";
        description = "Internal domain (e.g., tv.home)";
      };

      external = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = "tv.alnav.dev";
        description = "External domain (e.g., tv.example.com)";
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    # Base Jellyfin configuration
    {
      services.jellyfin = {
        enable = true;
        openFirewall = cfg.openFirewall;
        user = cfg.user;
        group = cfg.group;
      };

      # Transcoding group
      users.groups.transcoding = {
        gid = 104;
      };

      environment.systemPackages = with pkgs; [
        jellyfin
        jellyfin-web
        jellyfin-ffmpeg
        cifs-utils
      ];

      # Skip intro plugin overlay
      nixpkgs.overlays = [
        (final: prev: {
          jellyfin-web = prev.jellyfin-web.overrideAttrs (finalAttrs: previousAttrs: {
            installPhase = ''
              runHook preInstall
              sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html
              mkdir -p $out/share
              cp -a dist $out/share/jellyfin-web
              runHook postInstall
            '';
          });
        })
      ];
    }

    # Intel VA-API
    (lib.mkIf cfg.intel.vaapi {
      hardware = {
        enableRedistributableFirmware = true;
        intel-gpu-tools.enable = true;
        graphics = {
          enable = true;
          extraPackages = with pkgs; [
            intel-media-driver
            libva-vdpau-driver
          ] ++ (lib.optionals cfg.intel.openclCompute [ intel-compute-runtime ])
            ++ (lib.optionals cfg.intel.qsv [ vpl-gpu-rt ]);
          extraPackages32 = with pkgs.pkgsi686Linux; [
            intel-media-driver
          ];
        };
      };

      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
      systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

      environment.systemPackages = with pkgs; [
        libva-utils
        intel-gpu-tools
      ];
    })

    # SMB mounts
    (lib.mkIf cfg.mounts.enable {
      sops.secrets."${cfg.mounts.credentialsSecret}" = {};

      fileSystems."/mnt/things" = {
        device = cfg.mounts.thingsPath;
        fsType = "cifs";
        options = [
          "credentials=/run/secrets/${cfg.mounts.credentialsSecret}"
          "uid=jellyfin"
          "gid=transcoding"
          "file_mode=0777"
          "dir_mode=0777"
          "noperm"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "_netdev"
          "vers=3.0"
        ];
      };

      fileSystems."/mnt/media" = {
        device = cfg.mounts.mediaPath;
        fsType = "cifs";
        options = [
          "credentials=/run/secrets/${cfg.mounts.credentialsSecret}"
          "uid=jellyfin"
          "gid=transcoding"
          "file_mode=0666"
          "dir_mode=0777"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "_netdev"
          "vers=3.0"
        ];
      };

      fileSystems."/mnt/containers" = {
        device = cfg.mounts.containersPath;
        fsType = "cifs";
        options = [
          "credentials=/run/secrets/${cfg.mounts.credentialsSecret}"
          "uid=jellyfin"
          "gid=transcoding"
          "file_mode=0666"
          "dir_mode=0777"
          "x-systemd.idle-timeout=60"
          "x-systemd.device-timeout=5s"
          "x-systemd.mount-timeout=5s"
          "_netdev"
          "vers=3.0"
        ];
      };
    })

    # Nginx reverse proxy - Internal (via nginx-internal container)
    (lib.mkIf (cfg.proxy.internal != null) {
      containers.nginx-internal.config.services.nginx.virtualHosts."${cfg.proxy.internal}" = {
        serverName = cfg.proxy.internal;
        listen = [{ addr = "10.71.71.75"; port = 80; }];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    })

    # Nginx reverse proxy - External (via nginx-external container)
    (lib.mkIf (cfg.proxy.external != null) {
      containers.nginx-external.config.services.nginx.virtualHosts."${cfg.proxy.external}" = {
        forceSSL = true;
        useACMEHost = "alnav.dev";
        serverName = cfg.proxy.external;
        listen = [
          { addr = "10.71.71.193"; port = 80; }
          { addr = "10.71.71.193"; port = 443; ssl = true; }
        ];
        locations."/" = {
          proxyPass = "http://127.0.0.1:8096";
          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    })

    # Backup
    (lib.mkIf cfg.backup.enable {
      environment.systemPackages = [ pkgs.rsync ];

      systemd.services.jellyfin-backup = {
        description = "Backup Jellyfin data to SMB";
        wantedBy = [ "timers.target" ];
        serviceConfig = {
          Type = "oneshot";
          StandardOutput = "journal";
          StandardError = "journal";
          ExecStart = ''
            ${pkgs.rsync}/bin/rsync -aHAX --delete --partial --progress \
            --exclude='cache/*' --exclude='log/*' \
            /var/lib/jellyfin/ /mnt/containers/jellyfin/
          '';
        };
        unitConfig = {
          RequiresMountsFor = [ "/mnt/containers" ];
          After = "network-online.target mnt-containers.mount";
          Wants = [ "network-online.target" ];
        };
      };

      systemd.timers.jellyfin-backup = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.backup.schedule;
          Persistent = true;
          RandomizedDelaySec = "1h";
        };
      };
    })
  ]);
}
