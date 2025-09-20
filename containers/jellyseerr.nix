{ lib, pkgs, ... }:

let
  myContainerIPs = {
    jellyseerr = "172.42.0.35";
  };
in
{
  virtualisation.oci-containers.containers = {
    jellyseerr = {
      image = "fallenbagel/jellyseerr:latest";
      environment = {
        TZ = "Asia/Tashkent";
        LOG_LEVEL = "debug";
        PORT = "5055";
        PUID = "994";
        PGID = "104";
      };
      extraOptions = [ 
        "--net" "custom-net" 
        "--ip" "${myContainerIPs.jellyseerr}"
        "--health-cmd" "wget --no-verbose --tries=1 --spider http://localhost:5055/api/v1/status || exit 1"
        "--health-start-period" "20s"
        "--health-timeout" "3s"
        "--health-interval" "15s"
        "--health-retries" "3"
      ];
      volumes = [
        "/var/containers-data/jellyseerr:/app/config"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."jellyseerr.home" = {
    serverName = "jellyseerr.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.jellyseerr}:5055";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}