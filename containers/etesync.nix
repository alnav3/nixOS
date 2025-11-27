{ lib, pkgs, ... }:

let
  myContainerIPs = {
    etesync = "172.42.0.44";
  };
in
{
  virtualisation.oci-containers.containers = {
    etesync = {
      image = "victorrds/etesync:latest";
      environment = {
        TZ = "Etc/UTC";
        PUID = "1000";
        PGID = "1000";
      };
      extraOptions = [ "--net" "custom-net" "--ip" "${myContainerIPs.etesync}" ];
      volumes = [
        "/var/containers-data/etesync:/data"
      ];
      ports = [ ];
    };
  };

  containers.nginx-internal.config.services.nginx.virtualHosts."etesync.home" = {
    serverName = "etesync.home";
    listen = [{ addr = "10.71.71.75"; port = 80; }];
    locations."/" = {
      proxyPass = "http://${myContainerIPs.etesync}:3735";
      extraConfig = ''
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
      '';
    };
  };
}