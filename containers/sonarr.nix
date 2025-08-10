{ lib, pkgs, ... }:

let
  myContainerIPs = {
    sonarr = "172.42.0.32";
  };
in
{
  virtualisation.oci-containers.containers = {
    sonarr = {
      image = "lscr.io/linuxserver/sonarr:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "994";   # matches your previous sonarr uid
        PGID = "104";   # set numeric group id (adjust if your media group has a different gid)
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.sonarr}" ];
      volumes = [
        "/var/containers-data/sonarr:/config"   # arr-family config sync location you requested
        "/mnt/things:/downloads"
        "/mnt/media:/media"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."sonarr.home" = {
    serverName = "sonarr.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.sonarr}:8989";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}

