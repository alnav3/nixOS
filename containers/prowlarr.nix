{ lib, pkgs, ... }:

let
  myContainerIPs = {
    prowlarr = "172.42.0.34";
  };
in
{
  virtualisation.oci-containers.containers = {
    prowlarr = {
      image = "lscr.io/linuxserver/prowlarr:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "275";   # matches your previous prowlarr uid
        PGID = "275";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.prowlarr}" ];
      volumes = [
        "/var/containers-data/prowlarr:/config"
        "/mnt/media:/media"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."prowlarr.home" = {
    serverName = "prowlarr.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.prowlarr}:9696";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };

}

