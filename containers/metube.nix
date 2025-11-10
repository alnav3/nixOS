{ lib, pkgs, ... }:
let
  myContainerIPs = {
    metube = "172.42.0.39";
  };
in
{
  virtualisation.oci-containers.containers = {
    metube = {
      image = "ghcr.io/alexta69/metube:latest";
      environment = {
        TZ = "Etc/UTC";
        UID = "994";
        GID = "104";
        UMASK = "022";
        DOWNLOAD_DIR = "/downloads";
        STATE_DIR = "/.metube";
        TEMP_DIR = "/downloads";
        DEFAULT_THEME = "auto";
        # OUTPUT_TEMPLATE = "%(title)s.%(ext)s";  # Optional: customize filename format
        # DELETE_FILE_ON_TRASHCAN = "true";      # Optional: delete files when removed from UI
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.metube}" ];
      volumes = [
        "/mnt/media/media/Youtube:/downloads"
        "/var/containers-data/metube:/.metube"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."metube.home" = {
    serverName = "youtube.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.metube}:8081";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support for real-time updates
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
      '';
    };
  };
}
