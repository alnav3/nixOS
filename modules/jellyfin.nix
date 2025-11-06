{ pkgs, lib, ... }: {

    ## rsync backup solution for data
    systemd.services.jellyfin-backup = {
        description = "Backup Jellyfin data to SMB (/mnt/containers/jellyfin)";
        wantedBy = [ "timers.target" ];
        serviceConfig = {
            Type = "oneshot";
            StandardOutput = "journal";
            StandardError  = "journal";

            # Ensure mount is available before starting.
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
            # Run daily at 03:00
            OnCalendar = "03:00";
            Persistent = true;
            RandomizedDelaySec = "1h";
        };
    };

    # Modern graphics stack with Intel iHD VA-API driver (Broadwell+)
    hardware = {
      enableRedistributableFirmware = true;
      intel-gpu-tools.enable = true;
      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          intel-media-driver
          vaapiVdpau
          intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
          vpl-gpu-rt # QSV on 11th gen or newer
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          intel-media-driver
        ];
      };
    };
    nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
        "intel-ocl"
    ];
    # mount configuration for shows/movies/jellyfin configuration
    sops.secrets."smb-things-secrets" = { };

    # jellyfin's skip intro plugin
    nixpkgs.overlays = with pkgs; [
      (
        final: prev:
          {
            jellyfin-web = prev.jellyfin-web.overrideAttrs (finalAttrs: previousAttrs: {
              installPhase = ''
                runHook preInstall

                # this is the important line
                sed -i "s#</head>#<script src=\"configurationpage?name=skip-intro-button.js\"></script></head>#" dist/index.html

                mkdir -p $out/share
                cp -a dist $out/share/jellyfin-web

                runHook postInstall
              '';
            });
          }
      )
    ];

    fileSystems."/mnt/things" = {
        device = "//10.71.71.19/things";
        fsType = "cifs";  # Corrected from fstype to fsType (standard NixOS option name)
        options = [
            "credentials=/run/secrets/smb-things-secrets"
            "uid=jellyfin"
            "gid=transcoding"
            "file_mode=0777"  # Changed to allow execute bit on files for full permissiveness
            "dir_mode=0777"
            "noperm"  # Added: Disables client-side permission checks, deferring fully to server
            "x-systemd.idle-timeout=60"
            "x-systemd.device-timeout=5s"
            "x-systemd.mount-timeout=5s"
            "_netdev"
            "vers=3.0"
        ];
    };


    fileSystems."/mnt/media" = {
        device = "//10.71.71.19/media";
        fsType = "cifs";
        options = [
            "credentials=/run/secrets/smb-things-secrets"
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
        device = "//10.71.71.19/podvolumes";
        fsType = "cifs";
        options = [
            "credentials=/run/secrets/smb-things-secrets"
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

    # Set VA-API driver globally; Jellyfin inherits this
    environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "iHD";
    };
    systemd.services.jellyfin.environment.LIBVA_DRIVER_NAME = "iHD";

    # Jellyfin service
    services.jellyfin = {
        enable = true;
        openFirewall = true;

        user  = "jellyfin";
        group = "transcoding";
    };
    # Jellyfin FFmpeg package
    environment.systemPackages = with pkgs; [
            rsync
            jellyfin
            jellyfin-web
            jellyfin-ffmpeg            # Uses ffmpeg configured for Jellyfin HA
            libva-utils
            intel-gpu-tools
            cifs-utils
    ];

# i915.enable_guc no longer relevant for new xe driver paths on newer GPUs,
# but ADL-N typically still uses i915; you can omit unless troubleshooting.[2][6]
# boot.kernelParams = [ "i915.enable_guc=2" ];

    containers = {
      nginx-internal.config.services.nginx.virtualHosts."tv.home" = {
        serverName = "tv.home";
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
      nginx-external.config.services.nginx.virtualHosts."tv.alnav.dev" = {
          forceSSL = true;
          useACMEHost = "alnav.dev";
          serverName = "tv.alnav.dev";
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
    };
}

