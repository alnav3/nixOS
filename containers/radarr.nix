{ lib, pkgs, ... }:

let
  myContainerIPs = {
    radarr = "172.42.0.33";
  };
in
{
  virtualisation.oci-containers.containers = {
    radarr = {
      image = "lscr.io/linuxserver/radarr:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "994";   # matches your previous radarr uid
        PGID = "104";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.radarr}" ];
      volumes = [
        "/var/containers-data/radarr:/config"
        "/mnt/things:/downloads"
        "/mnt/media:/media"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."radarr.home" = {
    serverName = "radarr.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.radarr}:7878";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}

