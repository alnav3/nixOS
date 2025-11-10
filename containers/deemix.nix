{ lib, pkgs, ... }:
let
  myContainerIPs = {
    deemix = "172.42.0.36";  # Changed from 0.33 to 0.36
  };
in
{
  virtualisation.oci-containers.containers = {
    deemix = {
      image = "registry.gitlab.com/bockiii/deemix-docker:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "994";
        PGID = "104";
        UMASK_SET = "022";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.deemix}" ];
      volumes = [
        "/var/containers-data/deemix:/config"
        "/mnt/things:/downloads"
        "/mnt/media/media/Music:/music"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."deemix.home" = {
    serverName = "deemix.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.deemix}:6595";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        # WebSocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 86400;
      '';
    };
  };
}
