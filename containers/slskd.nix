{ lib, pkgs, ... }:

let
  myContainerIPs = {
    slskd = "172.42.0.50";
  };
in
{
  virtualisation.oci-containers.containers = {
    slskd = {
      image = "slskd/slskd:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "1000";
        PGID = "1000";
        SLSKD_HTTP_PORT = "5030";
        SLSKD_HTTPS_PORT = "5031";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.slskd}" ];
      volumes = [
        "/var/containers-data/slskd:/app"
        "/mnt/things:/downloads"
        "/mnt/media:/music"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."slskd.home" = {
    serverName = "slskd.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.slskd}:5030";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
      '';
    };
  };
}